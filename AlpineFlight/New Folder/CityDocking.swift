import Foundation
import simd

/// Short-range skyport guidance. It moves through the real city; it never teleports across it.
struct CityDocking {
    static let captureRadius: Float = 450
    static let approachRadius: Float = 1100
    private(set) var station: CityStation?
    private(set) var arrived = false

    mutating func begin(_ station: CityStation, state: inout FlightState, aircraft: AircraftType = .kestrel) -> Bool {
        guard self.station == nil, simd_distance(state.position,station.position) < Self.captureRadius,
              Self.clearApproach(from:state, to:station, aircraft:aircraft) else { return false }
        self.station = station
        arrived = false
        // Repulsor brakes remove cruise momentum before the gentle parking manoeuvre.
        state.velocity *= 0.12
        state.airspeed = simd_length(state.velocity)
        return true
    }

    static func clearApproach(from state: FlightState, to station: CityStation, aircraft: AircraftType) -> Bool {
        let distance = simd_distance(state.position,station.position)
        guard distance.isFinite, distance < captureRadius else { return false }
        let city = PlanetExploration(planet:.coruscant)
        let steps = max(1,Int(ceil(distance / 15)))
        for index in 0...steps {
            let point = simd_mix(state.position,station.position,SIMD3<Float>(repeating:Float(index)/Float(steps)))
            if city.clearance(at:point) <= aircraft.bodyRadius + 3 || city.hitsObstacle(at:point,radius:aircraft.bodyRadius + 3) { return false }
        }
        return true
    }

    /// Slow an inbound approach without taking steering away from the pilot.
    static func approachSpeedLimit(for state: FlightState, target: CityStation) -> Float? {
        let delta = target.position-state.position
        let distance = simd_length(delta)
        guard distance.isFinite, distance > 1, distance < approachRadius,
              abs(delta.y) < 300, simd_dot(state.velocity,delta/distance) > 10,
              state.airspeed > 0 else { return nil }
        return 35
    }

    /// Returns true once, when parked. The caller then starts its boarding/scan timer.
    mutating func advance(state: inout FlightState, dt: Float) -> Bool {
        guard let station, dt.isFinite, dt > 0 else { return false }
        if arrived {
            state.position = station.position
            state.velocity = .zero; state.airspeed = 0; state.pitch = 0; state.roll = 0
            return false
        }
        let delta = station.position-state.position
        let distance = simd_length(delta)
        let desired = delta * min(2.2,60/max(1,distance))
        state.velocity += (desired-state.velocity)*(1-exp(-dt*10))
        state.position += state.velocity*dt
        state.airspeed = simd_length(state.velocity)
        state.pitch *= exp(-dt*8); state.roll *= exp(-dt*8)
        state.stalled = false
        if simd_distance(state.position,station.position) < 2 && state.airspeed < 6 {
            state.position = station.position; state.velocity = .zero; state.airspeed = 0
            arrived = true
            return true
        }
        return false
    }

    mutating func depart(state: inout FlightState, speed: Float) {
        guard station != nil else { return }
        station = nil; arrived = false
        state.airspeed = clamp(speed,60,120)
        state.velocity = state.forward*state.airspeed
    }

    mutating func reset() { station = nil; arrived = false }
}
