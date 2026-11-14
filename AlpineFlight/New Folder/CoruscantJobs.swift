import Foundation
import simd

enum CityStation: String, CaseIterable, Identifiable, Sendable {
    case spaceport, market, senate, industrial, medical

    var id: String { rawValue }
    var name: String {
        switch self {
        case .spaceport: return "Galactic Spaceport"
        case .market: return "Neon Market"
        case .senate: return "Senate District"
        case .industrial: return "Industrial Quarter"
        case .medical: return "Medical Centre"
        }
    }
    var position: SIMD3<Float> {
        switch self {
        case .spaceport: return [0, 180, 7200]
        case .market: return [1920, 180, 4800]
        case .senate: return [0, 180, -480]
        case .industrial: return [-3840, 180, -1920]
        case .medical: return [-1920, 180, 4800]
        }
    }
}

enum CityJobKind: String, CaseIterable, Identifiable, Sendable {
    case shuttle, courier, rescue, patrol

    var id: String { rawValue }
    var title: String {
        switch self {
        case .shuttle: return "Passenger Shuttle"
        case .courier: return "Express Courier"
        case .rescue: return "Medical Rescue"
        case .patrol: return "City Patrol"
        }
    }
    var summary: String {
        switch self {
        case .shuttle: return "Collect and deliver three passengers across the city."
        case .courier: return "Deliver three packages before the five-minute deadline."
        case .rescue: return "Collect a patient in the Industrial Quarter and reach the Medical Centre."
        case .patrol: return "Visit four districts and stop to scan for trouble."
        }
    }
    var rewardCredits: Int {
        switch self {
        case .shuttle: return 120
        case .courier: return 100
        case .rescue: return 150
        case .patrol: return 80
        }
    }
    var timeLimit: Float? {
        switch self {
        case .shuttle, .patrol: return nil
        case .courier, .rescue: return 300
        }
    }
    /// Passenger legs are pickup/drop-off pairs, with no consecutive stop at the same station.
    var stops: [CityStation] {
        switch self {
        case .shuttle: return [.spaceport, .market, .senate, .industrial, .market, .medical]
        case .courier: return [.market, .industrial, .senate]
        case .rescue: return [.industrial, .medical]
        case .patrol: return [.spaceport, .market, .senate, .industrial]
        }
    }
}

enum CityJobEvent: Equatable, Sendable {
    case none
    case stopCompleted
    case completed(id: UUID, credits: Int)
    case expired
}

/// Arrival estimates use closing speed, so flying away never promises an arrival time.
struct CityApproach {
    let distance: Float
    let heightChange: Float
    let estimatedSeconds: Float?

    init(position: SIMD3<Float>, velocity: SIMD3<Float>, target: SIMD3<Float>) {
        let delta = target - position
        distance = simd_length(delta)
        heightChange = delta.y
        let closingSpeed = distance > 0 ? simd_dot(velocity, delta / distance) : 0
        estimatedSeconds = distance.isFinite && closingSpeed.isFinite && closingSpeed > 5
            ? distance / closingSpeed : nil
    }

    var guidance: String {
        guard distance.isFinite, heightChange.isFinite else { return "Navigation unavailable" }
        let height = abs(heightChange) < 20 ? "Height aligned" : "\(heightChange > 0 ? "Climb" : "Descend") \(Int(abs(heightChange).rounded())) m"
        if distance < CityDocking.captureRadius { return "Dock ready · aim below 120 kt" }
        let arrival = estimatedSeconds.map { " · ETA \(Int(ceil(min($0, 5999)))) s" } ?? " · steer towards skyport"
        return height + arrival + (distance < CityDocking.approachRadius ? " · approach assist" : "")
    }
}

/// Flight owns docking movement; this value type owns route order, service time and reward eligibility.
struct CoruscantJobs: Sendable {
    private(set) var active: CityJobKind?
    private(set) var contract: CityContract?
    private(set) var quality = CityRideQuality()
    private(set) var lastCompletion: CityJobReport?
    private(set) var flightMetres: Float = 0
    private(set) var flightSeconds: Float = 0
    private(set) var stage = 0
    private(set) var elapsed: Float = 0
    private(set) var serviceRemaining: Float = 0
    private(set) var completedJobs = 0
    private var jobID: UUID?

    var route: [CityStation] { active == nil ? [] : contract?.stops ?? active?.stops ?? [] }
    var serviceDuration: Float { contract?.serviceSeconds ?? 3 }
    var carryingPayload: Bool {
        guard let active else { return false }
        switch active { case .shuttle,.rescue: return !stage.isMultiple(of:2); case .courier: return true; case .patrol: return false }
    }
    var conditionFeedback: String {
        guard let active else { return "" }
        if active == .patrol { return "\(stage)/\(route.count) scans · \(Int(serviceDuration)) s per scan" }
        guard carryingPayload else { return active == .rescue ? "Awaiting patient pickup" : "Awaiting passenger pickup" }
        let label = contract?.conditionLabel ?? "Condition"
        let advice = quality.condition >= 90 ? "steady flight" : quality.condition >= 70 ? "ease the turns" : "fly gently to protect your load"
        return "\(label) \(Int(quality.condition))% · \(advice)"
    }
    mutating func observeFlight(_ state: FlightState, flying: Bool, firing: Bool, dt: Float) {
        if active != nil, flying, !docking, dt.isFinite, dt > 0, dt <= 0.25, state.airspeed.isFinite {
            flightMetres += max(0,state.airspeed)*dt
            flightSeconds += dt
        }
        quality.observe(state:state,kind:active ?? .shuttle,carrying:carryingPayload,flying:flying && !docking,firing:firing,dt:dt)
    }

    var target: CityStation? {
        guard active != nil, route.indices.contains(stage) else { return nil }
        return route[stage]
    }
    var docking: Bool { active != nil && serviceRemaining > 0 }
    var progress: Float {
        guard let active else { return 0 }
        let serviced = docking ? 1 - serviceRemaining / serviceDuration : 0
        return min(1, max(0, (Float(stage) + serviced) / Float(route.count)))
    }
    var timeRemaining: Float? {
        guard active != nil, let limit = contract?.timeLimit else { return nil }
        return max(0, limit - elapsed)
    }
    var status: String {
        guard let active, let target else { return "Choose a city job" }
        let action: String
        switch active {
        case .shuttle:
            action = stage.isMultiple(of: 2) ? "Collect passenger \(stage / 2 + 1)" : "Drop off passenger \(stage / 2 + 1)"
        case .courier: action = "Deliver package \(stage + 1) of \(route.count)"
        case .rescue: action = stage.isMultiple(of:2) ? "Collect patient \(stage / 2 + 1)" : "Deliver patient \(stage / 2 + 1)"
        case .patrol: action = "Scan district \(stage + 1) of \(route.count)"
        }
        if docking { return "\(action) · servicing at \(target.name)" }
        return "\(action) · \(target.name)"
    }

    mutating func accept(_ kind: CityJobKind) {
        accept(CityContract.standard(for:kind))
    }

    mutating func accept(_ contract: CityContract) {
        active = contract.kind
        self.contract = contract
        quality = CityRideQuality()
        flightMetres = 0; flightSeconds = 0
        lastCompletion = nil
        stage = 0
        elapsed = 0
        serviceRemaining = 0
        jobID = UUID()
    }

    mutating func cancel() {
        active = nil
        contract = nil
        quality = CityRideQuality()
        flightMetres = 0; flightSeconds = 0
        lastCompletion = nil
        stage = 0
        elapsed = 0
        serviceRemaining = 0
        jobID = nil
    }

    @discardableResult
    mutating func beginService(at position: SIMD3<Float>) -> Bool {
        guard !docking, let target, simd_distance(position, target.position) < 200,
              timeRemaining.map({ $0 > 0 }) ?? true else { return false }
        serviceRemaining = serviceDuration
        return true
    }

    /// Call only for active game time. A final service must finish strictly before its deadline.
    mutating func advance(dt: Float) -> CityJobEvent {
        guard let active, dt.isFinite, dt > 0 else { return .none }
        let limit = contract?.timeLimit

        if docking && dt >= serviceRemaining {
            let finishTime = elapsed + serviceRemaining
            if let limit, finishTime >= limit { return expire(at: limit) }
            stage += 1
            serviceRemaining = 0
            if stage >= route.count {
                elapsed = finishTime
                guard let id = jobID else { return .none }
                let completedContract = contract ?? CityContract.standard(for:active)
                let eligibleForBonus = quality.condition >= 95 && quality.flightSeconds >= 20 && quality.metres >= 1000
                let surveyBonus = flightMetres >= max(1000,completedContract.routeDistance*0.5) && flightSeconds >= 20
                let bonus = (active == .patrol ? surveyBonus : eligibleForBonus) ? completedContract.maximumBonus : 0
                let report = CityJobReport(id:id,contract:completedContract,completedAt:Date(),seconds:finishTime,
                                          kilometres:flightMetres/1000,condition:Int(quality.condition),stars:quality.stars,bonusCredits:bonus)
                lastCompletion = report
                self.active = nil
                jobID = nil
                completedJobs += 1
                return .completed(id: id, credits: report.credits)
            }
            // A large frame can include both a completed intermediate stop and the later deadline.
            elapsed += dt
            if let limit, elapsed >= limit { return expire(at: limit) }
            return .stopCompleted
        }

        elapsed += dt
        if let limit, elapsed >= limit { return expire(at: limit) }
        if docking { serviceRemaining = max(0, serviceRemaining - dt) }
        return .none
    }

    private mutating func expire(at limit: Float) -> CityJobEvent {
        active = nil
        elapsed = limit
        serviceRemaining = 0
        jobID = nil
        return .expired
    }
}
