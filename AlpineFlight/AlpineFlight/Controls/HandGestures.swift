import Foundation
import simd

enum ShipHandGesture: Equatable {
    case neutral, pinch, peace, throttleUp, throttleDown
    var feedback: String {
        switch self {
        case .neutral: return "Hand tracking · tap to recenter"
        case .pinch: return "Pinch · firing"
        case .peace: return "Peace sign · camera switched"
        case .throttleUp: return "Thumbs up · raising throttle"
        case .throttleDown: return "Thumbs down · lowering throttle"
        }
    }
}

struct HandGestureInput {
    var firing = false
    var switchCamera = false
    var throttleDirection: Float = 0
}

/// Pure joint geometry, separate from camera capture and gameplay actions.
struct ShipHandPose {
    enum Joint: CaseIterable {
        case wrist, indexBase, middleBase, littleBase, thumbTip, thumbIP
        case indexTip, indexPIP, middleTip, middlePIP, ringTip, ringPIP, littleTip, littlePIP
    }
    let points: [Joint: SIMD2<Float>]
    func classify() -> ShipHandGesture? {
        guard let wrist = points[.wrist], let indexBase = points[.indexBase],
              let littleBase = points[.littleBase], let thumb = points[.thumbTip],
              let index = points[.indexTip] else { return nil }
        guard points.values.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        let palm = simd_distance(indexBase, littleBase)
        guard palm > 0.015 else { return nil }
        // Compare relative joint distances, so hand size and camera range do not set sensitivity.
        let fingers: [(Joint,Joint)] = [(.indexTip,.indexPIP),(.middleTip,.middlePIP),(.ringTip,.ringPIP),(.littleTip,.littlePIP)]
        var extended: [Bool] = []
        for (tipJoint,pipJoint) in fingers {
            guard let tip = points[tipJoint], let pip = points[pipJoint] else { return nil }
            extended.append(simd_distance(tip,wrist) > simd_distance(pip,wrist) + palm * 0.2)
        }
        // A closed fist is not a trigger: keep at least one other finger extended for pinch.
        if simd_distance(thumb,index) < palm * 0.30 && extended.dropFirst().contains(true) { return .pinch }
        if extended == [true,true,false,false] { return .peace }
        if extended.allSatisfy({ !$0 }), let thumbIP = points[.thumbIP] {
            let direction = thumb - thumbIP
            if abs(direction.y) > palm * 0.35 && abs(direction.x) < abs(direction.y) * 0.8 {
                return direction.y > 0 ? .throttleUp : .throttleDown
            }
        }
        return .neutral
    }
}

/// Debounces deliberate holds. A camera switch requires neutral release before another switch.
struct HandGestureFilter {
    private var candidate: ShipHandGesture?
    private var since: Double = 0
    private var lastSeen: Double = -.infinity
    private var cameraArmed = false
    private var cameraDidSwitch = false
    private(set) var feedback: ShipHandGesture = .neutral
    mutating func reset() { self = HandGestureFilter() }
    mutating func observe(_ gesture: ShipHandGesture?, at time: Double) {
        guard let gesture else {
            candidate = nil; feedback = .neutral; lastSeen = -.infinity
            cameraArmed = false
            return
        }
        if time - lastSeen > 0.25 { candidate = nil; cameraArmed = false }
        if candidate != gesture { candidate = gesture; since = time; feedback = .neutral; cameraDidSwitch = false }
        lastSeen = time
        if gesture == .neutral && time - since >= 0.25 { cameraArmed = true }
    }
    mutating func input(at time: Double) -> HandGestureInput {
        guard time - lastSeen <= 0.25, let candidate else { feedback = .neutral; return HandGestureInput() }
        let held = time - since
        var result = HandGestureInput()
        switch candidate {
        case .neutral: break
        case .pinch:
            result.firing = held >= 0.18
        case .peace:
            if held >= 0.65 && cameraArmed { result.switchCamera = true; cameraArmed = false; cameraDidSwitch = true }
        case .throttleUp, .throttleDown:
            if held >= 0.5 { result.throttleDirection = candidate == .throttleUp ? 1 : -1 }
        }
        feedback = (result.firing || (candidate == .peace && cameraDidSwitch) || result.throttleDirection != 0) ? candidate : .neutral
        return result
    }
}
