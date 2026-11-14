import Foundation
import simd

struct Checkpoint: Identifiable {
    let id: Int
    let name: String
    let position: SIMD3<Float>
    var radius: Float = 115
    var normal = SIMD3<Float>(0, 0, -1)
}

struct CheckpointSystem {
    let checkpoints: [Checkpoint]
    private(set) var nextIndex = 0
    var aircraft: AircraftType = .kestrel
    var laps = 1
    var currentLap: Int { min(laps, nextIndex / max(1, checkpoints.count) + 1) }
    var next: Checkpoint? { nextIndex < checkpoints.count * laps ? checkpoints[nextIndex % checkpoints.count] : nil }
    var complete: Bool { !checkpoints.isEmpty && next == nil }

    init(terrain: TerrainGenerator, aircraft: AircraftType = .kestrel) {
        self.aircraft = aircraft
        let level = terrain.level
        laps = level.isPodRaceTrack ? 3 : 1
        checkpoints = zip(level.gateNames, level.gateDepths).enumerated().map { index, entry in
            let (name, depth) = entry
            if level.isPodRaceTrack {
                let circuit = RaceCircuit(level: level)
                let d = Float(index + 1) / Float(level.gateCount) * circuit.length
                return Checkpoint(id: index, name: name, position: circuit.point(at: d), radius: level.valleyWidth * 0.48, normal: circuit.tangent(at: d))
            }
            let z = -depth
            let x = terrain.valleyCenter(at: z)
            return Checkpoint(id: index, name: name, position: [x, terrain.surfaceHeight(x: x, z: z) + level.gateClearance, z], radius: level.gateRadius)
        }
    }

    mutating func reset() { nextIndex = 0 }

    mutating func advance(from start: SIMD3<Float>, to end: SIMD3<Float>) -> Bool {
        guard let gate = next else { return false }
        let before = simd_dot(start - gate.position, gate.normal)
        let after = simd_dot(end - gate.position, gate.normal)
        guard before <= 0, after > 0 else { return false }
        let t = -before / (after - before)
        let crossing = start + (end - start) * t
        guard simd_length(crossing - gate.position) < gate.radius - aircraft.wingspan / 2 else { return false }
        nextIndex += 1
        return true
    }
}
