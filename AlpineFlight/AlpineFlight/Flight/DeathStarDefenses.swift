import Foundation
import simd

struct TurretBolt {
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var age: Float = 0
    var fromPursuer = false
}

struct Pursuer {
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var fireCooldown: Float
    let side: Float
}

struct DefenseUpdate {
    var fired = false
    var hit = false
    var incoming = false
    var pursuerHit = false
    var directPursuerHit = false
    var damage: Float = 0
}

/// Fixed-step, deterministic trench hazards. Rendering only reads the resulting bolt positions.
struct DeathStarDefenses {
    private let terrain: TerrainGenerator
    let turrets: [SIMD3<Float>]
    private(set) var bolts: [TurretBolt] = []
    private(set) var pursuers: [Pursuer] = []
    private var cooldown: Float = 0.9
    private var nextTurret = 0
    private var nextPursuerGate = 3

    init(terrain: TerrainGenerator) {
        self.terrain = terrain
        guard terrain.level == .deathStar else { turrets = []; return }
        turrets = (0..<17).map { index in
            let z = -850 - Float(index) * 760
            let side: Float = index.isMultiple(of: 2) ? -1 : 1
            let x = terrain.valleyCenter(at: z) + side * (205 - terrain.difficulty(at: z) * 25)
            return [x, terrain.surfaceHeight(x: x, z: z) + 18, z]
        }
    }

    mutating func reset() {
        bolts.removeAll()
        pursuers.removeAll()
        cooldown = 0.9
        nextTurret = 0
        nextPursuerGate = 3
    }

    mutating func resolvePlayerFire(_ bolts: [PlayerBolt]) -> Int {
        guard !pursuers.isEmpty else { return 0 }
        let before = pursuers.count
        pursuers.removeAll { pursuer in
            bolts.contains { simd_distance($0.position, pursuer.position) < 18 }
        }
        return before - pursuers.count
    }

    mutating func update(from old: FlightState, to ship: FlightState, passedGates: Int, dt: Float) -> DefenseUpdate {
        guard !turrets.isEmpty else { return DefenseUpdate() }
        var result = DefenseUpdate()
        if passedGates >= nextPursuerGate && pursuers.count < 3 {
            let side: Float = pursuers.count.isMultiple(of: 2) ? -1 : 1
            pursuers.append(Pursuer(position: ship.position + [side * 35, 10, 155],
                                    velocity: [0, 0, -ship.airspeed], fireCooldown: 3.0, side: side))
            nextPursuerGate += 3
        }
        cooldown -= dt
        if cooldown <= 0, bolts.count < 30 {
            let candidates = turrets.indices.filter {
                let ahead = ship.position.z - turrets[$0].z
                return ahead > 130 && ahead < 850
            }
            if !candidates.isEmpty {
                let index = candidates[nextTurret % candidates.count]
                nextTurret += 1
                let target = ship.position + ship.velocity * 0.65
                let direction = simd_normalize(target - turrets[index])
                bolts.append(TurretBolt(position: turrets[index] + direction * 20,
                                        velocity: direction * 230))
                cooldown = max(0.8, 1.2 - Float(index) * 0.015)
                result.fired = true
            } else {
                cooldown = 0.15
            }
        }
        for index in pursuers.indices {
            let previousPosition = pursuers[index].position
            let target = ship.position + [pursuers[index].side * 24, 7, 48]
            let change = target - previousPosition
            let chaseVelocity = ship.velocity + change * 1.5
            let desiredVelocity = simd_length(chaseVelocity) > 235 ?
                simd_normalize(chaseVelocity) * 235 : chaseVelocity
            let blend = 1 - exp(-dt * 2.5)
            pursuers[index].velocity += (desiredVelocity - pursuers[index].velocity) * blend
            pursuers[index].position += pursuers[index].velocity * dt
            let p = pursuers[index].position
            let center = terrain.valleyCenter(at: p.z)
            pursuers[index].position.x = clamp(p.x, center - 125, center + 125)
            pursuers[index].position.y = max(p.y, terrain.surfaceHeight(x: pursuers[index].position.x, z: p.z) + 45)
            pursuers[index].fireCooldown -= dt
            let range = simd_distance(pursuers[index].position, ship.position)
            if pursuers[index].fireCooldown <= 0 && range > 35 && range < 240 && bolts.count < 30 {
                let direction = simd_normalize(ship.position + ship.velocity * 0.32 - pursuers[index].position)
                bolts.append(TurretBolt(position: pursuers[index].position + direction * 9,
                                        velocity: direction * 155, fromPursuer: true))
                pursuers[index].fireCooldown = 5.0 - Float(index) * 0.35
                result.fired = true
            }
            if range < 10 { result.hit = true; result.pursuerHit = true; result.directPursuerHit = true }
        }
        for index in bolts.indices {
            let start = bolts[index].position
            bolts[index].position += bolts[index].velocity * dt
            bolts[index].age += dt
            // A moving segment against the moving aircraft catches hits between 120 Hz steps.
            let relativeStart = start - old.position
            let relativeEnd = bolts[index].position - ship.position
            let travel = relativeEnd - relativeStart
            let fraction = clamp(-simd_dot(relativeStart, travel) / max(simd_length_squared(travel), 0.0001), 0, 1)
            let separation = simd_length(relativeStart + travel * fraction)
            if separation < 11 {
                // A bolt that has already passed behind the ship cannot damage it.
                // This keeps trailing TIEs threatening without making tail shots unfair.
                let forwardDistance = simd_dot(relativeStart, ship.forward)
                if !bolts[index].fromPursuer || forwardDistance > -5 {
                    result.hit = true
                    result.pursuerHit = result.pursuerHit || bolts[index].fromPursuer
                    result.damage += bolts[index].fromPursuer ? 12 : 9
                }
            }
            if separation < 90 { result.incoming = true }
        }
        bolts.removeAll { $0.age > 4.5 || simd_distance($0.position, ship.position) > 1100 }
        return result
    }

}
