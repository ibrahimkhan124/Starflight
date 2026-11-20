@main struct NativeFlightParity {
    static func main() {
        func values(_ fields: [Float]) -> String {
            fields.map { String(format: "%.9g", Double($0)) }.joined(separator: ",")
        }
        let cases: [(AircraftType, FlightInput, SIMD3<Float>)] = [
            (.kestrel, FlightInput(pitch: 0.04, throttle: 0.65), [3, 0.5, -2]),
            (.xwing, FlightInput(pitch: 0.2, roll: 0.67, yaw: -0.4, throttle: 0.85, boost: true), [12, -0.3, 4]),
            (.enterprise, FlightInput(pitch: -0.2, roll: -0.83, yaw: 0.48, throttle: 0.0), [-8, 1, -1])
        ]
        for (craft, input, wind) in cases {
            let model = FlightPhysics(aircraft: craft)
            var state = FlightState()
            state.airspeed = craft.cruiseSpeed
            state.velocity = SIMD3<Float>(0, 0, -state.airspeed)
            for _ in 0..<240 { model.advance(&state,input:input,wind:wind,dt:FlightPhysics.step) }
            let setup = [craft.cruiseSpeed, craft.response, craft.maximumPitch, craft.maximumRoll, craft.yawAuthority,
                         input.pitch, input.roll, input.yaw, input.throttle, input.boost ? Float(1) : 0,
                         wind.x, wind.y, wind.z]
            let output = [state.position.x, state.position.y, state.position.z,
                          state.velocity.x, state.velocity.y, state.velocity.z,
                          state.pitch, state.roll, state.heading, state.airspeed, state.stalled ? Float(1) : 0]
            print(values(setup + output))
        }
    }
}
