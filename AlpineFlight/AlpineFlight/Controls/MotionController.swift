import CoreMotion
#if canImport(UIKit)
import UIKit
#endif
import simd

@MainActor
final class MotionController {
#if os(macOS)
    var available: Bool { false }
    var active: Bool { false }

    func start() {}
    func stop() {}
    func calibrate() {}
    func input() -> SIMD2<Float> { .zero }
#else
    private let manager = CMMotionManager()
    private var neutral: SIMD2<Float>?
    var available: Bool { manager.isDeviceMotionAvailable }
    var active: Bool { manager.isDeviceMotionActive }

    func start() {
        guard available, !active else { return }
        neutral = nil
        manager.deviceMotionUpdateInterval = 1 / 60
        manager.startDeviceMotionUpdates()
    }
    func stop() {
        manager.stopDeviceMotionUpdates()
        neutral = nil
    }
    func calibrate() { neutral = nil }

    func input(orientation: UIInterfaceOrientation) -> SIMD2<Float> {
        guard let motion = manager.deviceMotion else { return .zero }
        let g = motion.gravity
        let axes: SIMD2<Float>
        switch orientation {
        case .landscapeLeft: axes = [Float(g.y), Float(g.z)]
        case .landscapeRight: axes = [-Float(g.y), Float(g.z)]
        default: axes = [Float(g.x), Float(g.z)]
        }
        if neutral == nil { neutral = axes }
        let delta = (axes - (neutral ?? axes)) * 2.6
        return [clamp(delta.x, -1, 1), clamp(delta.y, -1, 1)]
    }
#endif
}
