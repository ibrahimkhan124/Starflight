import RealityKit
#if canImport(UIKit)
import UIKit
#endif
import simd

enum FlightCamera: String { case chase, cockpit }

@MainActor
final class CameraController {
    let entity = PerspectiveCamera()
    var mode: FlightCamera = .chase
    var inspectionTarget:SIMD3<Float>?
    var aircraft: AircraftType = .kestrel
    private var initialized = false
    private var crashVantage: SIMD3<Float>?
    private var previousShipPosition = SIMD3<Float>.zero

    init() {
        entity.camera.fieldOfViewInDegrees = 64
        entity.camera.near = 0.1
        entity.camera.far = 12000
    }
    func reset() { initialized = false; crashVantage = nil;inspectionTarget=nil }

    func update(state: FlightState, terrain: TerrainGenerator, dt: Float, inSpace: Bool = false) {
        entity.camera.far = inSpace ? 100000:12000
        if state.airspeed>3 || abs(state.pitch)>0.05 || abs(state.roll)>0.05 || abs(state.heading)>0.05 { inspectionTarget=nil }
        #if canImport(UIKit)
        let speedLens = !UIAccessibility.isReduceMotionEnabled
        #else
        let speedLens = true
        #endif
        let racingPod = terrain.level.isPodRace && aircraft.isPodracer
        let racePace = speedLens && racingPod
            ? clamp((state.airspeed / max(aircraft.cruiseSpeed, 1) - 1.2) * 7, 0, 22) : 0
        let targetFOV: Float = 64 + racePace
        entity.camera.fieldOfViewInDegrees += (targetFOV - entity.camera.fieldOfViewInDegrees) * (1 - exp(-dt * 5))
        let desired: SIMD3<Float>
        let target: SIMD3<Float>
        let up: SIMD3<Float>
        if mode == .cockpit {
            desired = state.position + state.orientation.act(aircraft.cockpitOffset)
            target = inspectionTarget ?? (desired + state.forward * 100)
            up = state.orientation.act([0, 1, 0])
        } else {
            let heading = simd_quatf(angle: -state.heading, axis: [0, 1, 0])
            var offset = aircraft.chaseOffset
            if terrain.level == .deathStar { offset.z = max(offset.z, 90) }
            let orbit = racingPod ? heading : heading * simd_quatf(angle: state.pitch, axis: [1,0,0])
            var chase = state.position + orbit.act(offset)
            if !inSpace { chase.y = max(chase.y, terrain.surfaceHeight(x: chase.x, z: chase.z) + 7) }
            desired = chase
            target = inspectionTarget ?? (state.position + state.forward * max(36, aircraft.length * 2) + SIMD3<Float>(0, 2, 0))
            up = orbit.act([0,1,0])
        }
        // A tighter race follow keeps the pod and the next bend visible at extreme speed.
        let followRate: Float = racingPod ? 9 : 5
        let blend: Float = !initialized || mode == .cockpit ? 1 : 1 - exp(-dt * followRate)
        // Carry the camera with the aircraft before easing its relative offset. Easing absolute
        // world position made fast ships pull hundreds of metres away from the chase view.
        let shipDelta = state.position - previousShipPosition
        let carriedPosition = initialized ? entity.position + shipDelta : desired
        var position = carriedPosition + (desired - carriedPosition) * blend
        if mode == .chase && !inSpace {
            position.y = max(position.y, terrain.surfaceHeight(x: position.x, z: position.z) + 7)
        }
        let oldOrientation = entity.orientation
        entity.look(at: target, from: position, upVector: up, relativeTo: nil)
        if initialized && mode == .chase {
            // Smooth both parts of the view transform; raw look-at rotation caused small jolts.
            let rotationBlend = 1 - exp(-dt * (racingPod ? 16 : 12))
            entity.orientation = simd_slerp(oldOrientation, entity.orientation, rotationBlend)
        }
        previousShipPosition = state.position
        initialized = true
    }
    /// Resolve a clear viewpoint once, then pull back without crossing a solid.
    /// The caller supplies the active planet/region geometry, rather than the orbit height field.
    func updateCrash(state: FlightState, elapsed: Float,
                     groundHeight: (Float, Float) -> Float,
                     isObstructed: (SIMD3<Float>) -> Bool) {
        func clear(_ point: SIMD3<Float>) -> Bool {
            point.y >= groundHeight(point.x, point.z) + 18 && !isObstructed(point)
        }
        let origin = state.position
        if crashVantage == nil {
            let heading = simd_quatf(angle: -state.heading, axis: [0, 1, 0])
            let directions: [SIMD3<Float>] = [[0,0,1], [1,0,0], [-1,0,0], [0,0,-1], [0.707,0,0.707], [-0.707,0,0.707]]
            let distance = max(180, aircraft.length * 5)
            search: for height: Float in [90, 180, 360, 720, 1440] {
                for direction in directions {
                    var point = origin + heading.act(direction) * distance + SIMD3<Float>(0,height,0)
                    point.y = max(point.y, groundHeight(point.x, point.z) + 40)
                    guard clear(point) else { continue }
                    // The impact itself can lie inside a wall; inspect the approach to it.
                    let sightlineClear = (1...10).allSatisfy { step in
                        clear(point + (origin - point) * (Float(step) * 0.075))
                    }
                    if sightlineClear { crashVantage = point; break search }
                }
            }
            if crashVantage == nil {
                var overhead = origin + SIMD3<Float>(60, 180, 80)
                overhead.y = max(overhead.y, groundHeight(overhead.x, overhead.z) + 80)
                for _ in 0..<32 {
                    if clear(overhead) { break }
                    overhead.y += 160
                }
                crashVantage = overhead
            }
        }
        guard let start = crashVantage else { return }
        let outward = simd_normalize(start - origin)
        let destination = start + outward * 65 + SIMD3<Float>(0, 25, 0)
#if canImport(UIKit)
        let progress: Float = UIAccessibility.isReduceMotionEnabled ? 1 : 1 - exp(-max(0, elapsed) * 2.4)
#else
        let progress: Float = 1 - exp(-max(0, elapsed) * 2.4)
#endif
        let proposed = start + (destination - start) * progress
        let safePullback = (0...8).allSatisfy { clear(start + (proposed - start) * (Float($0) / 8)) }
        entity.camera.fieldOfViewInDegrees = 64
        entity.look(at: origin + SIMD3<Float>(0, 4, 0), from: safePullback ? proposed : start, upVector: [0,1,0], relativeTo: nil)
    }

}
