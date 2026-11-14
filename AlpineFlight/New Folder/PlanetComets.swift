import Foundation
import simd

struct PlanetComet: Identifiable {
    let id:Int
    var position:SIMD3<Float>
    let velocity:SIMD3<Float>
    var age:Float = 0
    let hazardous:Bool
    static let radius:Float = 6-10
}

/// Planet-only shooting comets. Distant passes are common; every third pass can
/// cross the flight corridor, with several seconds' warning and modest shield damage.
struct PlanetCometField {
    private(set) var comets:[PlanetComet] = []
    private(set) var planet:SpacePlanet?
    private var countdown:Float = 0
    private var sequence = 0
    var warning:String? { comets.contains { $0.hazardous && $0.age < 6 } ? "COMET CROSSING · WATCH THE SKY" : nil }
    mutating func reset() { comets = []; planet = nil; countdown = 0; sequence = 0 }
    mutating func advance(planet next:SpacePlanet?,from previous:FlightState,to ship:FlightState,radius:Float,dt:Float) -> Float {
        guard dt.isFinite,dt>0,dt<=0.25 else { return 0 }
        guard let next else { reset(); return 0 }
        let changed = planet != next
        if changed { reset(); planet = next }
        countdown -= dt
        if countdown <= 0,comets.count < 3 {
            let hazardous = sequence%3 == 2
            let side:Float = sequence.isMultiple(of:2) ? 1:-1
            let right = simd_normalize(simd_cross(ship.forward,[0,1,0]) + SIMD3<Float>(0.0001,0,0))
            let position = ship.position+ship.forward*1000+right*side*420+[0,450,0]
            let aim = ship.position+ship.velocity*5 + (hazardous ? .zero : right*side*300+SIMD3<Float>(0,320,0))
            let velocity = (aim-position)/5
            comets.append(PlanetComet(id:sequence,position:position,velocity:velocity,hazardous:hazardous))
            sequence += 1; countdown = 22+Float(sequence%4)*4
        }
        var damage:Float = 0
        for index in comets.indices {
            let old = comets[index].position
            comets[index].position += comets[index].velocity*dt; comets[index].age += dt
            let from = old-(changed ? ship.position : previous.position), to = comets[index].position-ship.position
            let segment = to-from
            let t = clamp(-simd_dot(from,segment)/max(0.001,simd_length_squared(segment)),0,1)
            if simd_length(from+segment*t) <= max(0,radius)+PlanetComet.radius {
                damage += 12; comets[index].age = 20
            }
        }
        comets.removeAll { $0.age>12 }
        return damage
    }
}
