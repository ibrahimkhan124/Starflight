import Foundation
import simd

struct PlayerBolt {
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var age: Float = 0
    let damage: Float
}

struct WeaponSystem {
    private(set) var bolts: [PlayerBolt] = []
    private var cooldown: Float = 0
    private(set) var firedThisStep = false

    mutating func reset() {
        bolts.removeAll()
        cooldown = 0
        firedThisStep = false
    }

    mutating func update(state: FlightState, aircraft: AircraftType, firing: Bool, dt: Float, aimTarget: SIMD3<Float>? = nil) -> [PlayerBolt] {
        firedThisStep = false
        cooldown -= dt
        if firing && cooldown <= 0 && bolts.count < 24 {
            var forward = state.forward
            if let target = aimTarget {
                let delta = target-state.position
                let distance = simd_length(delta)
                // Arena assistance only: retain manual aim, correct a small near miss.
                if distance.isFinite, distance > 1, distance < 700 {
                    let direction = delta/distance
                    if simd_dot(direction,forward) > cos(Float.pi*8/180) { forward = direction }
                }
            }
            bolts.append(PlayerBolt(position: state.position + forward * (aircraft.length * 0.55),
                                    velocity: forward * aircraft.weaponSpeed + (aircraft.isPodracer ? state.velocity : .zero),
                                    damage: aircraft.weaponPower))
            cooldown = aircraft.weaponCooldown
            firedThisStep = true
        }
        for index in bolts.indices {
            bolts[index].position += bolts[index].velocity * dt
            bolts[index].age += dt
        }
        bolts.removeAll { $0.age > 3.2 }
        return bolts
    }

    mutating func consumeBolts(at indices: Set<Int>) {
        guard !indices.isEmpty else { return }
        bolts = bolts.enumerated().compactMap { indices.contains($0.offset) ? nil : $0.element }
    }

    /// Swept shots cannot skip a thin wall between physics steps.
    func surfaceHits(on surface: PlanetExploration, dt: Float) -> Set<Int> {
        guard dt.isFinite, dt > 0 else { return [] }
        var hits:Set<Int> = []
        for (index,bolt) in bolts.enumerated() {
            let segment = bolt.velocity * min(dt,bolt.age)
            let steps = max(1,Int(ceil(simd_length(segment)/8)))
            for step in 0...steps {
                let point = bolt.position-segment*(1-Float(step)/Float(steps))
                if surface.clearance(at:point) <= 2 || surface.hitsObstacle(at:point,radius:2) {
                    hits.insert(index); break
                }
            }
        }
        return hits
    }
}
