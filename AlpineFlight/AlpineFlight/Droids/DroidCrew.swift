import SwiftUI
import RealityKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

enum DroidType: String, CaseIterable, Identifiable, Sendable {
    case r2d2, chopper, sm33, bb8, k2so, bd1

    var id: String { rawValue }
    var name: String {
        switch self {
        case .r2d2: return "R2-D2"
        case .chopper: return "Chopper"
        case .sm33: return "SM-33"
        case .bb8: return "BB-8"
        case .k2so: return "K-2SO"
        case .bd1: return "BD-1"
        }
    }
    var role: String {
        switch self {
        case .r2d2: return "ASTROMECH · REPAIRS"
        case .chopper: return "ASTROMECH · CHAOS"
        case .sm33: return "FIRST MATE · NAVIGATION"
        case .bb8: return "ASTROMECH · SCOUTING"
        case .k2so: return "SECURITY · TACTICS"
        case .bd1: return "EXPLORATION · SCANNING"
        }
    }
    var summary: String {
        switch self {
        case .r2d2: return "Reliable navigation, damage control, and a cheerful vocabulary of whistles."
        case .chopper: return "Fast repairs, blunt opinions, and surprisingly creative shortcuts."
        case .sm33: return "An old pirate navigator with a sharp eye for routes and hidden hazards."
        case .bb8: return "A quick rolling scout that excels at route finding and threat detection."
        case .k2so: return "A reprogrammed security droid with precise tactical callouts."
        case .bd1: return "A compact companion with excellent optics and terrain scanners."
        }
    }
    var tint: Color {
        switch self {
        case .r2d2: return .blue
        case .chopper: return .orange
        case .sm33: return Color(red: 0.45, green: 0.68, blue: 0.68)
        case .bb8: return Color(red: 1, green: 0.55, blue: 0.12)
        case .k2so: return Color(red: 0.72, green: 0.76, blue: 0.78)
        case .bd1: return Color(red: 0.75, green: 0.9, blue: 0.86)
        }
    }
}

@MainActor
enum DroidFactory {
    static func make(_ type: DroidType) -> Entity {
        let root = Entity()
        root.name = "droid-\(type.rawValue)"
        let dark = SimpleMaterial(color: .init(white: 0.08, alpha: 1), roughness: 0.65, isMetallic: true)
        let white = SimpleMaterial(color: .init(white: 0.78, alpha: 1), roughness: 0.5, isMetallic: true)
        let accent = SimpleMaterial(color: UIColor(type.tint), roughness: 0.45, isMetallic: true)
        let eye = SimpleMaterial(color: .cyan, roughness: 0.2, isMetallic: true)
        func part(_ name: String, _ mesh: MeshResource, _ material: SimpleMaterial, _ position: SIMD3<Float>, _ scale: SIMD3<Float> = .one) {
            let model = ModelEntity(mesh: mesh, materials: [material])
            model.name = name; model.position = position; model.scale = scale; root.addChild(model)
        }
        switch type {
        case .r2d2, .chopper:
            part("body", .generateCylinder(height: 1.15, radius: 0.42), type == .r2d2 ? white : accent, [0, 0.72, 0])
            part("dome", .generateSphere(radius: 0.43), accent, [0, 1.31, 0], [1, 0.55, 1])
            part("optic", .generateSphere(radius: 0.10), eye, [0, 1.38, -0.38])
            part("left leg", .generateBox(size: [0.18, 0.85, 0.22]), white, [-0.48, 0.42, 0])
            part("right leg", .generateBox(size: [0.18, 0.85, 0.22]), white, [0.48, 0.42, 0])
        case .bb8:
            part("rolling body", .generateSphere(radius: 0.62), white, [0, 0.63, 0])
            part("head", .generateSphere(radius: 0.35), accent, [0, 1.24, 0], [1, 0.62, 1])
            part("optic", .generateSphere(radius: 0.09), eye, [0, 1.3, -0.31])
        case .k2so, .sm33:
            part("torso", .generateBox(size: [0.75, 1.0, 0.42]), type == .k2so ? dark : accent, [0, 1.65, 0])
            part("head", .generateBox(size: [0.48, 0.38, 0.4]), dark, [0, 2.38, 0])
            part("optic", .generateBox(size: [0.22, 0.07, 0.03]), eye, [0, 2.42, -0.22])
            for side: Float in [-1, 1] {
                part("arm", .generateBox(size: [0.16, 1.2, 0.16]), dark, [side * 0.56, 1.55, 0])
                part("leg", .generateBox(size: [0.2, 1.25, 0.22]), dark, [side * 0.24, 0.63, 0])
            }
        case .bd1:
            part("body", .generateBox(size: [0.65, 0.48, 0.45]), white, [0, 1.02, 0])
            part("binocular head", .generateBox(size: [0.86, 0.34, 0.36]), accent, [0, 1.48, -0.04])
            part("left optic", .generateSphere(radius: 0.11), eye, [-0.23, 1.5, -0.2])
            part("right optic", .generateSphere(radius: 0.11), eye, [0.23, 1.5, -0.2])
            part("left leg", .generateBox(size: [0.15, 0.75, 0.16]), dark, [-0.2, 0.48, 0])
            part("right leg", .generateBox(size: [0.15, 0.75, 0.16]), dark, [0.2, 0.48, 0])
        }
        root.scale = SIMD3<Float>(repeating: 0.7)
        return root
    }
}


enum DroidAssistMode: String, CaseIterable, Identifiable {
    case off, level, altitude, route
    var id: String { rawValue }
    var title: String { switch self { case .off: return "Manual"; case .level: return "Level ship"; case .altitude: return "Hold altitude"; case .route: return "Follow route" } }
}

/// Bounded control inputs through normal physics. Never teleports or bypasses collisions.
struct DroidFlightAssist {
    private(set) var mode: DroidAssistMode = .off
    private var altitude: Float = 0
    mutating func engage(_ mode: DroidAssistMode, state: FlightState) { self.mode = mode; altitude = state.position.y }
    mutating func pilotOverride(axes: SIMD2<Float>, yaw: Float) -> Bool {
        guard mode != .off, simd_length(axes) > 0.08 || abs(yaw) > 0.08 else { return false }
        mode = .off; return true
    }
    func controls(state: FlightState, target: SIMD3<Float>?) -> SIMD2<Float> {
        guard mode != .off else { return .zero }
        var desiredPitch: Float = 0
        var desiredRoll: Float = 0
        if mode == .altitude { desiredPitch = clamp((altitude - state.position.y) * 0.003 - state.velocity.y * 0.012, -0.25, 0.25) }
        if mode == .route, let target {
            let delta = target - state.position
            let desiredHeading = atan2(delta.x, -delta.z)
            let headingError = atan2(sin(desiredHeading-state.heading), cos(desiredHeading-state.heading))
            desiredRoll = clamp(headingError * 1.2, -0.45, 0.45)
            desiredPitch = clamp(atan2(delta.y, max(100, simd_length(SIMD2<Float>(delta.x,delta.z)))), -0.25, 0.25)
        }
        let pitchError = atan2(sin(desiredPitch-state.pitch),cos(desiredPitch-state.pitch))
        let rollError = atan2(sin(desiredRoll-state.roll),cos(desiredRoll-state.roll))
        return [clamp(rollError * 1.8, -0.7, 0.7), clamp(pitchError * 2.5 - state.pitchRate * 0.7, -0.7, 0.7)]
    }
}
