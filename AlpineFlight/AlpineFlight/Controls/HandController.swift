import Foundation
import Combine
import simd
#if os(iOS)
import UIKit
import AVFoundation
import Vision
import QuartzCore
import Darwin
#endif

enum HandControlSupport {
    // iPhone 16 models use iPhone17,* hardware identifiers. iPhone 15 Pro
    // uses iPhone16,*: comparing the marketing number to this prefix is wrong.
    static func supports(model: String) -> Bool {
        if model.hasPrefix("iPad"), model.contains(",") { return true }
        guard model.hasPrefix("iPhone"), let comma = model.firstIndex(of: ","),
              let family = Int(model[model.index(model.startIndex, offsetBy: 6)..<comma]) else { return false }
        return family >= 17
    }
    static var available: Bool {
#if targetEnvironment(macCatalyst)
        return AVCaptureDevice.default(for: .video) != nil
#elseif os(iOS) && !targetEnvironment(simulator)
        guard UIDevice.current.userInterfaceIdiom == .phone || UIDevice.current.userInterfaceIdiom == .pad else { return false }
        var info = utsname()
        uname(&info)
        let model = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
        }
        return supports(model: model)
#else
        return false
#endif
    }
}

/// Camera-independent mapping, tested with deterministic hand samples.
struct HandSteeringFilter {
    private var neutral: SIMD2<Float>?
    private var neutralSpan: Float = 0
    private var candidate: SIMD2<Float>?
    private var stableSince: Double = 0
    private var lastSeen: Double = -.infinity
    private var target = SIMD2<Float>.zero
    private(set) var calibrated = false
    private(set) var tracking = false
    private(set) var outOfRange = false
    private(set) var checkProgress: Float = 0
    private(set) var axes = SIMD2<Float>.zero

    mutating func reset() { self = HandSteeringFilter() }
    mutating func suspend() { tracking = false; axes = .zero; target = .zero }
    mutating func observe(_ point: SIMD2<Float>?, at time: Double, span: Float = 0.15) {
        guard let point, point.x.isFinite, point.y.isFinite, span.isFinite else {
            suspend()
            if !calibrated { candidate = nil; checkProgress = 0 }
            return
        }
        // Apparent palm size is a range/visibility estimate, not a distance in metres.
        let minimumSpan: Float = calibrated ? max(0.025, neutralSpan * (outOfRange ? 0.40 : 0.30)) : 0.045
        guard span >= minimumSpan else {
            outOfRange = true; suspend(); candidate = nil; checkProgress = 0; return
        }
        if !calibrated && time - lastSeen > 0.25 { candidate = nil; checkProgress = 0 }
        outOfRange = false; tracking = true; lastSeen = time
        if neutral == nil {
            if let candidate, simd_distance(candidate, point) < 0.035 {
                checkProgress = min(1, Float((time - stableSince) / 0.8))
                if checkProgress >= 1 { neutral = point; neutralSpan = span; calibrated = true }
            } else { candidate = point; stableSince = time; checkProgress = 0 }
        }
        guard let neutral else { target = .zero; return }
        // A broad travel area with a gentle early response. Account for the
        // space on each side of the paired center so left turns don't require
        // moving out of frame when the hand was centered slightly to the left.
        // A smaller distant hand also moves fewer image pixels for the same motion.
        let distanceScale = min(1.5, max(0.55, span / max(neutralSpan, 0.045)))
        func response(_ value: Float, center: Float, travel: Float) -> Float {
            let room = value < 0 ? center : 1 - center
            let fullTravel = max(0.025, min(travel * distanceScale, room * 0.85))
            let deadZone = min(0.012 * distanceScale, fullTravel * 0.15)
            let magnitude = min(1, max(0, (abs(value) - deadZone) / (fullTravel - deadZone)))
            // Soft curve engages small intentional movements without an abrupt bank.
            let curved = pow(magnitude, 0.78)
            return value < 0 ? -curved : curved
        }
        let delta = point - neutral
        target = [response(delta.x, center: neutral.x, travel: 0.34),
                  response(delta.y, center: neutral.y, travel: 0.30)]
    }
    mutating func input(at time: Double, dt: Float) -> SIMD2<Float> {
        guard tracking, time - lastSeen <= 0.25 else {
            suspend()
            if !calibrated { candidate = nil; checkProgress = 0 }
            return .zero // Keep the paired center, but never hold stale steering.
        }
        // Respond quickly to a deliberate move, smooth more gently near the center.
        let responseRate: Float = simd_length(target - axes) > 0.3 ? 17 : 11
        axes += (target - axes) * (1 - exp(-responseRate * min(max(dt, 0), 0.1)))
        return axes
    }
}

@MainActor
final class HandController: ObservableObject {
    @Published private(set) var status = "Hand control off"
    @Published private(set) var checking = false
    @Published private(set) var requestingPermission = false
    @Published private(set) var paired = false
    @Published private(set) var checkProgress: Float = 0
    @Published private(set) var permissionDenied = false
    var available: Bool { HandControlSupport.available }
    private var filter = HandSteeringFilter()
    private var gestures = HandGestureFilter()
    private var generation = 0
    private(set) var active = false
#if os(iOS)
    private let camera = HandCameraCapture()
    private var screenOrientation: UIInterfaceOrientation = .unknown
    func requestPermission() {
        guard available else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: permissionDenied = false; setStatus("Ready for hand control")
        case .notDetermined:
            setStatus("Requesting camera permission")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.permissionDenied = !granted
                    self?.setStatus(granted ? "Ready for hand control" : "Camera permission denied · use touch controls")
                }
            }
        default: permissionDenied = true; setStatus("Camera permission denied · use touch controls")
        }
    }
    func beginCheck() {
        guard available else { return }
        stop(); checking = true
        let orientation = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.interfaceOrientation ?? .landscapeRight
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            requestingPermission = true
            setStatus("Allow camera access to check your hand")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self, self.checking else { return }
                    self.requestingPermission = false
                    self.permissionDenied = !granted
                    if granted { self.start(orientation: orientation) }
                    else { self.checking = false; self.setStatus("Camera permission denied · use touch controls") }
                }
            }
        } else { start(orientation: orientation) }
    }
    func finishCheck() { stop(preserveCalibration: true) }
    func start(orientation: UIInterfaceOrientation) {
        guard available, !active else { return }
#if targetEnvironment(macCatalyst)
        let orientation: UIInterfaceOrientation = .landscapeRight
#endif
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            permissionDenied = true; checking = false
            setStatus("Allow camera access in Settings · use touch controls"); return
        }
        active = true; generation += 1
        if !filter.calibrated { filter.reset() }
        setStatus("Hold one hand still to center")
        screenOrientation = orientation
        let token = generation
        camera.start(orientation: orientation) { [weak self] point, span, time, gesture, failure in
            Task { @MainActor in
                guard let self, self.active, self.generation == token else { return }
                if let failure { self.stop(); self.setStatus(failure); return }
                self.filter.observe(point, at: time, span: span)
                self.gestures.observe(self.filter.calibrated && self.filter.tracking ? gesture : nil, at: time)
                if self.paired != self.filter.calibrated { self.paired = self.filter.calibrated }
                if self.checking && abs(self.checkProgress - self.filter.checkProgress) > 0.04 { self.checkProgress = self.filter.checkProgress }
                self.refreshStatus()
            }
        }
    }
    func updateOrientation(_ orientation: UIInterfaceOrientation) {
#if targetEnvironment(macCatalyst)
        return // Mac cameras keep a fixed landscape orientation.
#endif
        guard orientation != screenOrientation else { return }
        screenOrientation = orientation; recenter(); camera.updateOrientation(orientation)
    }
#else
    func requestPermission() {}
    func beginCheck() {}
    func finishCheck() {}
#endif
    private func setStatus(_ value: String) { if status != value { status = value } }
    private func refreshStatus() {
        if filter.outOfRange { setStatus("Hand too far away · move closer") }
        else if !filter.tracking { setStatus("Show your hand · steering paused") }
        else if filter.calibrated { setStatus(checking ? "Hand paired ✓ · tracking ready" : gestures.feedback.feedback) }
        else { setStatus("Checking hand · hold still") }
    }
    func stop(preserveCalibration: Bool = false) {
        gestures.reset()
        active = false; generation += 1; checking = false; requestingPermission = false
        if preserveCalibration { filter.suspend() } else { filter.reset() }
        paired = filter.calibrated; checkProgress = filter.checkProgress
#if os(iOS)
        camera.stop()
#endif
        setStatus(paired ? "Hand paired ✓ · ready for flight" : "Hand control off")
    }
    func recenter() { gestures.reset(); filter.reset(); paired = false; checkProgress = 0; setStatus("Checking hand · hold still") }
    func gestureInput(at time: Double) -> HandGestureInput {
        guard active, !checking, filter.calibrated, filter.tracking else { gestures.reset(); return HandGestureInput() }
        let value = gestures.input(at:time)
        refreshStatus()
        return value
    }
    func input(at time: Double, dt: Float) -> SIMD2<Float> {
        guard active else { return .zero }
        let axes = filter.input(at: time, dt: dt)
        refreshStatus()
        return axes
    }
}

#if os(iOS)
/// All session mutations and Vision requests stay on this serial queue, never
/// on the renderer's main thread. No frames are recorded, stored, or uploaded.
private final class HandCameraCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private static func steeringCamera() -> AVCaptureDevice? {
#if targetEnvironment(macCatalyst)
        return AVCaptureDevice.default(for: .video) // Built-in or system-selected webcam.
#else
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
#endif
    }
    private let queue = DispatchQueue(label: "Starflight.handCamera", qos: .userInitiated)
    private let session = AVCaptureSession()
    private let request = VNDetectHumanHandPoseRequest()
    private var connection: AVCaptureConnection?
    private var orientation: UIInterfaceOrientation = .unknown
    private var running = false
    private var lastFrame: Double = 0
    private var callback: ((SIMD2<Float>?, Float, Double, ShipHandGesture?, String?) -> Void)?

    func start(orientation: UIInterfaceOrientation, callback: @escaping (SIMD2<Float>?, Float, Double, ShipHandGesture?, String?) -> Void) {
        queue.async { [self] in
            self.callback = callback
            if session.inputs.isEmpty {
                session.beginConfiguration()
                session.sessionPreset = .vga640x480
                guard let device = Self.steeringCamera(),
                      let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
                    session.commitConfiguration(); callback(nil, 0, CACurrentMediaTime(), nil, "Front camera unavailable · use touch"); return
                }
                session.addInput(input)
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                output.setSampleBufferDelegate(self, queue: queue)
                guard session.canAddOutput(output) else {
                    session.removeInput(input); session.commitConfiguration()
                    callback(nil, 0, CACurrentMediaTime(), nil, "Camera could not start · use touch"); return
                }
                session.addOutput(output)
                connection = output.connection(with: .video)
                if connection?.isVideoMirroringSupported == true {
                    connection?.automaticallyAdjustsVideoMirroring = false
                    connection?.isVideoMirrored = false
                }
                // Low-resolution, 20-Hz camera. Vision samples at most 15 Hz.
                if let format = device.activeFormat.videoSupportedFrameRateRanges.first,
                   format.minFrameRate <= 20, format.maxFrameRate >= 20,
                   (try? device.lockForConfiguration()) != nil {
                    device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 20)
                    device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 20)
                    device.unlockForConfiguration()
                }
                session.commitConfiguration()
                request.maximumHandCount = 1
            }
            setOrientation(orientation)
            running = true; lastFrame = 0
            session.startRunning()
            if !session.isRunning { callback(nil, 0, CACurrentMediaTime(), nil, "Camera busy · use touch controls") }
        }
    }
    func stop() {
        queue.async { [self] in running = false; callback = nil; session.stopRunning() }
    }
    func updateOrientation(_ value: UIInterfaceOrientation) {
        queue.async { [self] in
            guard value != orientation else { return }
            setOrientation(value)
        }
    }
    private func setOrientation(_ value: UIInterfaceOrientation) {
        orientation = value
        guard connection?.isVideoOrientationSupported == true else { return }
        switch value {
    
        case .landscapeLeft: connection?.videoOrientation = .landscapeLeft
        case .landscapeRight: connection?.videoOrientation = .landscapeRight
        case .portraitUpsideDown: connection?.videoOrientation = .portraitUpsideDown
        default: connection?.videoOrientation = .portrait
        }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let time = CACurrentMediaTime()
        guard running, time - lastFrame >= 1 / 15, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrame = time
        do {
            // Capture has rotated the pixels into screen orientation; mirror only x
            // afterwards so moving a hand screen-right banks right in both landscapes.
            try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up).perform([request])
            guard let hand = request.results?.first else { callback?(nil, 0, time, nil, nil); return }
            let joints: [VNHumanHandPoseObservation.JointName] = [.wrist, .indexMCP, .middleMCP, .ringMCP, .littleMCP]
            let points = joints.compactMap { try? hand.recognizedPoint($0) }.filter { $0.confidence >= 0.4 }
            guard points.count >= 3 else { callback?(nil, 0, time, nil, nil); return }
            let center = points.reduce(SIMD2<Float>.zero) { $0 + SIMD2(Float($1.location.x), Float($1.location.y)) } / Float(points.count)
            let span = points.map { simd_distance(SIMD2(Float($0.location.x), Float($0.location.y)), center) }.max()! * 2
            let jointMap: [(ShipHandPose.Joint,VNHumanHandPoseObservation.JointName)] = [
                (.wrist,.wrist),(.indexBase,.indexMCP),(.middleBase,.middleMCP),(.littleBase,.littleMCP),
                (.thumbTip,.thumbTip),(.thumbIP,.thumbIP),(.indexTip,.indexTip),(.indexPIP,.indexPIP),
                (.middleTip,.middleTip),(.middlePIP,.middlePIP),(.ringTip,.ringTip),(.ringPIP,.ringPIP),(.littleTip,.littleTip),(.littlePIP,.littlePIP)]
            let aspect = Float(CVPixelBufferGetWidth(pixelBuffer)) / Float(CVPixelBufferGetHeight(pixelBuffer))
            var pose: [ShipHandPose.Joint:SIMD2<Float>] = [:]
            for (joint,visionJoint) in jointMap {
                if let point = try? hand.recognizedPoint(visionJoint), point.confidence >= 0.5 {
                    pose[joint] = [Float(point.location.x)*aspect,Float(point.location.y)]
                }
            }
            callback?([1 - center.x, center.y], span, time, ShipHandPose(points:pose).classify(), nil)
        } catch { callback?(nil, 0, time, nil, nil) }
    }
}
#endif
