import Foundation
import simd

/// Tracks held keys so keyboard input has the same continuous feel as the touch controls.
struct KeyboardControls {
    private(set) var held: Set<String> = []

    static let supported: Set<String> = ["w", "s", "a", "d", "q", "e", "f", "b", "i", "k", "j", "l",
                                         "up", "down", "left", "right", "=", "+", "-", "_",
                                         "c", "p", "r", "space", "escape", "return", "shift"]

    mutating func press(_ key: String) -> Bool {
        guard Self.supported.contains(key) else { return false }
        return held.insert(key).inserted
    }

    mutating func release(_ key: String) { held.remove(key) }
    mutating func clear() { held.removeAll() }
    func isHeld(_ key: String) -> Bool { held.contains(key) }

    var stick: SIMD2<Float> {
        let roll: Float = (isHeld("d") || isHeld("l") || isHeld("right") ? 1 : 0) -
                          (isHeld("a") || isHeld("j") || isHeld("left") ? 1 : 0)
        let pitch: Float = (isHeld("w") || isHeld("i") || isHeld("up") ? 1 : 0) -
                           (isHeld("s") || isHeld("k") || isHeld("down") ? 1 : 0)
        return [roll, pitch]
    }

    var rudder: Float { (isHeld("e") ? 1 : 0) - (isHeld("q") ? 1 : 0) }
    var throttleDirection: Float { (isHeld("=") || isHeld("+") ? 1 : 0) - (isHeld("-") || isHeld("_") ? 1 : 0) }
    var firing: Bool { isHeld("f") }
    var boosting: Bool { isHeld("b") }
    var skidding: Bool { isHeld("shift") }
}
