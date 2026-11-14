import Foundation
import QuartzCore
import Darwin

/// Local, explicitly requested release diagnostics. No network, account or player data.
/// The normal game pays only a nil check; reports are written between samples.
enum AetherReleaseValidation {
    struct Configuration {
        let candidate: Bool
        let performanceMode: Bool
        let seconds: Double
        let passes: Int
        var comparison = false
        var name: String { (candidate ? "candidate" : "baseline") + (performanceMode ? "-30" : "-60") }
        static func read(environment: [String: String], arguments: [String]) -> Self? {
            guard arguments.contains("--aether-release-check"),
                  let variant = environment["STARFLIGHT_AETHER_VALIDATION"],
                  ["baseline", "candidate", "comparison"].contains(variant) else { return nil }
            let seconds = Double(environment["STARFLIGHT_AETHER_SECONDS"] ?? "45") ?? 45
            return .init(candidate: variant == "candidate",
                         performanceMode: environment["STARFLIGHT_AETHER_QUALITY"] != "full",
                         seconds: seconds.isFinite ? max(5, min(180, seconds)) : 45,
                         passes: max(1, min(5, Int(environment["STARFLIGHT_AETHER_PASSES"] ?? "2") ?? 2)),
                         comparison:variant == "comparison")
        }
    }
    static let configuration = Configuration.read(environment: ProcessInfo.processInfo.environment,
                                                   arguments: ProcessInfo.processInfo.arguments)

    static func defaults() -> UserDefaults {
        guard let configuration else { return .standard }
        // Only this named throwaway suite is reset, never the player's standard domain.
        let suite = "starflight.aether.release-validation"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set("freeRoam", forKey: "level")
        defaults.set(true, forKey: "spaceFreeRoam")
        defaults.set(configuration.performanceMode, forKey: "performanceMode")
        defaults.set(false, forKey: "tilt")
        defaults.set(false, forKey: "handControl")
        defaults.set("clear", forKey: "flightWeather")
        return defaults
    }

    /// Fixed-size histogram: frame samples cannot grow memory during a long flight.
    struct Histogram: Codable {
        private(set) var bins = [Int](repeating: 0, count: 2001)
        private(set) var count = 0
        private(set) var total = 0.0
        private(set) var maximum = 0.0
        mutating func add(milliseconds: Double) {
            guard milliseconds.isFinite, milliseconds >= 0 else { return }
            bins[min(2000, Int(min(2000, milliseconds).rounded(.up)))] += 1
            count += 1; total += milliseconds; maximum = max(maximum, milliseconds)
        }
        func percentile(_ fraction: Double) -> Double {
            guard count > 0 else { return 0 }
            let target = max(1, Int((Double(count) * max(0, min(1, fraction))).rounded(.up)))
            var sum = 0
            for (index, value) in bins.enumerated() { sum += value; if sum >= target { return Double(index) } }
            return 2000
        }
    }
    struct Segment: Codable {
        let name: String
        let seconds: Double
        let callbackCount: Int
        let meanCallbackMS: Double
        let p95CallbackMS: Double
        let p99CallbackMS: Double
        let longestCallbackMS: Double
        let p95UpdateWorkMS: Double
        let longestUpdateWorkMS: Double
        let overBudgetCallbacks: Int
        let peakFootprintMB: Double?
        let endFootprintMB: Double?
        let worstThermalState: Int
        let memoryWarnings: Int
        let outcome: String
    }
    struct Report: Codable {
        var schema = 1
        var runID = ProcessInfo.processInfo.environment["STARFLIGHT_AETHER_RUN_ID"] ?? UUID().uuidString
        var physicalMemoryMB = Double(ProcessInfo.processInfo.physicalMemory) / 1_048_576
        var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        let variant: String
        let model: String
        let os: String
        let version: String
        let targetFPS: Int
        var build: String
        var status = "running"
        var segments: [Segment] = []
        var events: [String: Double] = [:]
        var notes = ["Display-link intervals and CPU update work are not GPU presentation measurements.",
                     "Scripted high-clearance flights use normal flight simulation and altitude assist."]
    }
    static func footprintMB() -> Double? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : nil
    }
    static var model: String {
        var system = utsname(); uname(&system)
        return withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
        }
    }
}

@MainActor
final class AetherReleaseProbe {
    static var shared: AetherReleaseProbe? = AetherReleaseValidation.configuration.map { .init(configuration: $0) }
    let configuration: AetherReleaseValidation.Configuration
    private(set) var report: AetherReleaseValidation.Report
    private var intervals = AetherReleaseValidation.Histogram()
    private var work = AetherReleaseValidation.Histogram()
    private var segment: String?
    private var started = 0.0
    private var lastCallback: Double?
    private var lastResourceSample = 0.0
    private var peak: Double?
    private var endMemory: Double?
    private var thermal = 0
    private var overBudget = 0
    private var warnings = 0

    init(configuration: AetherReleaseValidation.Configuration) {
        self.configuration = configuration
        let bundle = Bundle.main
        report = .init(variant: configuration.name, model: AetherReleaseValidation.model,
                       os: ProcessInfo.processInfo.operatingSystemVersionString,
                       version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                       targetFPS: configuration.performanceMode ? 30 : 60,
                       build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown")
    }
    func begin(_ name: String) {
        segment = name; started = CACurrentMediaTime(); lastCallback = nil
        intervals = .init(); work = .init(); peak = nil; endMemory = nil
        thermal = 0; overBudget = 0; warnings = 0; lastResourceSample = 0
        sampleResources()
    }
    func frame(at now: Double, workMS: Double) {
        guard segment != nil else { return }
        if let lastCallback {
            let ms = (now - lastCallback) * 1000
            intervals.add(milliseconds: ms)
            if ms > 1000 / Double(report.targetFPS) * 1.5 { overBudget += 1 }
        }
        lastCallback = now; work.add(milliseconds: workMS)
        if now - lastResourceSample >= 1 { sampleResources(); lastResourceSample = now }
    }
    func memoryWarning() { if segment != nil { warnings += 1 } }
    private func sampleResources() {
        endMemory = AetherReleaseValidation.footprintMB()
        if let endMemory { peak = max(peak ?? 0, endMemory) }
        thermal = max(thermal, ProcessInfo.processInfo.thermalState.rawValue)
    }
    func end(outcome: String) {
        guard let segment else { return }
        sampleResources()
        report.segments.append(.init(name: segment, seconds: CACurrentMediaTime() - started,
            callbackCount: intervals.count, meanCallbackMS: intervals.count > 0 ? intervals.total / Double(intervals.count) : 0,
            p95CallbackMS: intervals.percentile(0.95), p99CallbackMS: intervals.percentile(0.99),
            longestCallbackMS: intervals.maximum, p95UpdateWorkMS: work.percentile(0.95),
            longestUpdateWorkMS: work.maximum, overBudgetCallbacks: overBudget,
            peakFootprintMB: peak, endFootprintMB: endMemory, worstThermalState: thermal,
            memoryWarnings: warnings, outcome: outcome))
        self.segment = nil
        save()
    }
    func event(_ name: String, seconds: Double) { report.events[name] = seconds }
    func interruption(_ detail: String) { report.notes.append(detail) }
    func finish(_ status: String) { report.status = status; save() }
    private func save() {
        do {
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("AetherValidation", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            try data.write(to: folder.appendingPathComponent(configuration.name + ".json"), options: .atomic)
            print("AETHER_CHECK \(configuration.name) \(report.status) \(report.segments.last?.name ?? "preparation")")
        } catch { print("AETHER_CHECK report write failed: \(error.localizedDescription)") }
    }
}
