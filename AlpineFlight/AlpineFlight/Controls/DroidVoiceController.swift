import Foundation
import AVFoundation
import Speech

enum DroidCommand: Equatable {
    case throttle(Int), camera, status, unknown
    case turnLeft, turnRight, climb, descend, cancelAssist
    case fire, ceaseFire, boost, repair, navigate, scan, scanOre, levelShip, holdAltitude, followRoute, pause, help
}

enum DroidCommandParser {
    static func latestUtterance(_ raw: String) -> String? {
        let normalized = raw.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
        guard let wake = normalized.range(of: "hey droid", options: .backwards) else { return nil }
        return String(normalized[wake.lowerBound...])
    }

    static func parse(_ raw: String) -> DroidCommand {
        guard let normalized = latestUtterance(raw) else { return .unknown }
        guard let wake = normalized.range(of: "hey droid", options: .backwards) else { return .unknown }
        let command = String(normalized[wake.upperBound...])
        // Match reports and stop commands before action words such as “fire”.
        if command.contains("stop firing") || command.contains("cease fire") || command.contains("hold fire") { return .ceaseFire }
        if command.contains("cancel") || command.contains("manual control") { return .cancelAssist }
        if command.contains("help") || command.contains("commands") { return .help }
        if command.contains("pause") { return .pause }
        if command.contains("hold altitude") || command.contains("maintain altitude") { return .holdAltitude }
        if command.contains("level ship") || command.contains("level my ship") || command.contains("wings level") { return .levelShip }
        if command.contains("follow route") || command.contains("follow my route") { return .followRoute }
        if command.contains("scan ore") || command.contains("scan minerals") || command.contains("scan asteroids") { return .scanOre }
        if command.contains("repair") || command.contains("recharge shields") { return .repair }
        if command.contains("shield") || command.contains("status") { return .status }
        if command.contains("scan") || command.contains("enemies") { return .scan }
        if command.contains("checkpoint") || command.contains("navigate") || command.contains("where next") { return .navigate }
        if command.contains("turn left") || command.contains("bank left") { return .turnLeft }
        if command.contains("turn right") || command.contains("bank right") { return .turnRight }
        if command.contains("climb") || command.contains("pull up") { return .climb }
        if command.contains("descend") || command.contains("nose down") { return .descend }
        if command.contains("fire") || command.contains("shoot") { return .fire }
        if command.contains("boost") { return .boost }
        if command.contains("throttle") || command.contains("speed") {
            if let range = command.range(of: #"\b\d{1,3}\b"#, options: .regularExpression), let number = Int(command[range]) {
                return .throttle(clamp(command.contains("minus") || command.contains("negative") || command.contains("reverse") ? -abs(number):number, -100, 100))
            }
            let sign = command.contains("minus") || command.contains("negative") || command.contains("reverse") ? -1:1
            if command.contains("full") { return .throttle(sign*100) }
            if command.contains("half") { return .throttle(sign*50) }
            if command.contains("cut") { return .throttle(0) }
            let units = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
            let teens = ["ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
            let tens = ["twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
            let tokens = command.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
            for (index, token) in tokens.enumerated() {
                if token == "hundred" { return .throttle(sign*100) }
                if let value = tens.firstIndex(of: token) {
                    let next = index + 1 < tokens.count ? units.firstIndex(of: tokens[index + 1]) ?? 0 : 0
                    return .throttle(sign*((value + 2) * 10 + next))
                }
                if let value = teens.firstIndex(of: token) { return .throttle(sign*(value + 10)) }
                if let value = units.firstIndex(of: token) {
                    if token == "one", index + 1 < tokens.count, tokens[index + 1] == "hundred" { return .throttle(sign*100) }
                    return .throttle(sign*value)
                }
            }
        }
        if command.contains("camera") { return .camera }
        if command.contains("status") { return .status }
        return .unknown
    }
}

@MainActor
final class DroidVoiceController: ObservableObject {
    enum State: Equatable { case off, requestingPermission, listening, unavailable(String) }
    @Published private(set) var state: State = .off
    @Published private(set) var transcript = ""
    @Published private(set) var permissionStatus = "Tap Enable droid voice access to set up microphone and speech permissions."
    @Published private(set) var needsSettings = false
    @Published private(set) var inputLevel: Float = 0

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var lastHandled = ""
    private var sessionID = UUID()
    private var tapInstalled = false
    private var pendingCommand: Task<Void, Never>?
    private var usingOnDeviceRecognition = true
    var onCommand: ((String) -> Void)?

    var listening: Bool { state == .listening }
    var status: String {
        switch state {
        case .off: return "VOICE OFF"
        case .requestingPermission: return "REQUESTING ACCESS"
        case .listening: return transcript.isEmpty ? "LISTENING · SAY HEY DROID" : transcript.uppercased()
        case .unavailable(let reason): return reason.uppercased()
        }
    }

    func toggle() {
        if listening || state == .requestingPermission { stop() }
        else { Task { await authorizeAndStart() } }
    }

    func requestPermissions() {
        guard state != .requestingPermission else { return }
        Task { await authorizeAndStart(startRecording: false) }
    }

    func stop() {
        sessionID = UUID()
        cleanUpRecognition()
        transcript = ""; lastHandled = ""; state = .off
#if os(iOS)
        GameAudioSession.restoreAfterRecording()
#endif
    }

    private func cleanUpRecognition() {
        pendingCommand?.cancel(); pendingCommand = nil
        audioEngine.stop()
        if tapInstalled { audioEngine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio(); task?.cancel(); request = nil; task = nil
        inputLevel = 0
    }

    private func authorizeAndStart(startRecording: Bool = true) async {
        guard state != .requestingPermission else { return }
        let authorizationID = sessionID
        state = .requestingPermission
        needsSettings = false
        permissionStatus = "Requesting microphone access…"
#if os(iOS) && !targetEnvironment(macCatalyst)
        let microphone = await AVAudioApplication.requestRecordPermission()
#else
        let microphone = await AVCaptureDevice.requestAccess(for: .audio)
#endif
        guard sessionID == authorizationID else { return }
        guard microphone else {
            permissionStatus = "Microphone access is denied. Enable it in system settings."
            needsSettings = true
            state = .unavailable("Enable Microphone in Settings")
            return
        }
        permissionStatus = "Microphone allowed. Requesting speech recognition…"
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard sessionID == authorizationID else { return }
        guard speech == .authorized else {
            needsSettings = speech == .denied
            permissionStatus = speech == .restricted
                ? "Speech recognition is restricted on this device."
                : "Microphone allowed. Enable Speech Recognition in system settings."
            state = .unavailable("Speech Recognition access unavailable")
            return
        }
        permissionStatus = "Microphone and speech access are enabled. In cockpit view, tap the droid microphone to listen."
        if startRecording { startListening() } else { state = .off }
    }

    private func startListening(preferOnDevice: Bool = true) {
        guard recognizer?.isAvailable == true else { state = .unavailable("Speech recognition unavailable"); return }
        cleanUpRecognition()
        sessionID = UUID()
        let recognitionID = sessionID
#if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { fail("Audio input: \(error.localizedDescription)"); return }
#endif
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        usingOnDeviceRecognition = preferOnDevice && recognizer?.supportsOnDeviceRecognition == true
        request.requiresOnDeviceRecognition = usingOnDeviceRecognition
        request.contextualStrings = ["Hey droid", "throttle", "seventy five percent", "status report", "switch camera",
                                     "turn left", "turn right", "climb", "descend", "fire weapons", "cease fire",
                                     "boost", "repair shields", "next checkpoint", "scan for enemies", "cancel assist"]
        self.request = request
        let format = audioEngine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            fail("No microphone available"); return
        }
        var meterBuffers = 0
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            request.append(buffer)
            meterBuffers += 1
            if meterBuffers % 5 == 0, let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 {
                var sum: Float = 0
                for index in 0..<Int(buffer.frameLength) { sum += samples[index] * samples[index] }
                let level = min(1, sqrt(sum / Float(buffer.frameLength)) * 12)
                Task { @MainActor in
                    guard let self, self.sessionID == recognitionID, self.listening else { return }
                    self.inputLevel = level
                }
            }
        }
        tapInstalled = true
        audioEngine.prepare()
        do { try audioEngine.start() } catch { fail("Microphone: \(error.localizedDescription)"); return }
        state = .listening
        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.sessionID == recognitionID, self.listening else { return }
                if let text = result?.bestTranscription.formattedString.lowercased() {
                    self.transcript = text
                    self.queueCommand(text, final: result?.isFinal == true, session: recognitionID)
                }
                if let error {
                    if self.usingOnDeviceRecognition {
                        // A supported recognizer may still have missing local language assets.
                        self.startListening(preferOnDevice: false)
                    } else {
                        self.fail("Speech stopped: \(error.localizedDescription)")
                    }
                } else if result?.isFinal == true {
                    self.restartAfterRecognition()
                }
            }
        }
    }

    private func restartAfterRecognition() {
        guard listening else { return }
        sessionID = UUID()
        cleanUpRecognition()
        transcript = ""; lastHandled = ""
        startListening(preferOnDevice: usingOnDeviceRecognition)
    }

    private func fail(_ message: String) {
        stop()
        state = .unavailable(message)
    }

    private func queueCommand(_ text: String, final: Bool, session: UUID) {
        pendingCommand?.cancel()
        guard DroidCommandParser.parse(text) != .unknown else { return }
        if final { deliverCommand(text); return }
        // Wait for a stable phrase so “seventy” is not executed before “seventy five”.
        pendingCommand = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled, let self, self.sessionID == session, self.listening else { return }
            self.deliverCommand(text)
        }
    }

    private func deliverCommand(_ text: String) {
        guard let utterance = DroidCommandParser.latestUtterance(text) else { return }
        guard utterance != lastHandled else { return }
        lastHandled = utterance
        onCommand?(utterance)
    }
}
