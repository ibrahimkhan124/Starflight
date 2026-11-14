import XCTest
import simd
import AVFoundation
import RealityKit
@testable import AlpineFlight

final class HandGestureTests: XCTestCase {
    private func pose(_ gesture: ShipHandGesture) -> ShipHandPose {
        var p: [ShipHandPose.Joint:SIMD2<Float>] = [.wrist:[0,0],.indexBase:[-0.8,1],.middleBase:[0,1],.littleBase:[0.8,1],
            .thumbIP:[-1,1],.thumbTip:[-1.5,2],.indexPIP:[-0.6,1.8],.indexTip:[-0.6,3],
            .middlePIP:[0,2],.middleTip:[0,3.2],.ringPIP:[0.6,1.8],.ringTip:[0.6,3],.littlePIP:[1,1.6],.littleTip:[1,2.7]]
        if gesture == .pinch { p[.thumbTip] = p[.indexTip]! + SIMD2<Float>(0.05,0) }
        if gesture == .peace { p[.ringTip] = [0.6,0.8]; p[.littleTip] = [1,0.7] }
        if gesture == .throttleUp || gesture == .throttleDown {
            p[.indexTip] = [-0.6,0.8]; p[.middleTip] = [0,0.9]; p[.ringTip] = [0.6,0.8]; p[.littleTip] = [1,0.7]
            p[.thumbTip] = gesture == .throttleUp ? [-1,2] : [-1,-0.3]
        }
        return ShipHandPose(points:p)
    }
    func testJointGesturesSurviveScaleTranslationAndMirroring() {
        for gesture in [ShipHandGesture.neutral,.pinch,.peace,.throttleUp,.throttleDown] {
            let original = pose(gesture)
            XCTAssertEqual(original.classify(),gesture)
            for scale: Float in [0.1,0.4,1] {
                let points = original.points.mapValues { SIMD2<Float>(-$0.x,$0.y) * scale + SIMD2<Float>(0.4,0.2) }
                XCTAssertEqual(ShipHandPose(points:points).classify(),gesture)
            }
        }
        XCTAssertNil(ShipHandPose(points:[:]).classify())
        var fist = pose(.throttleUp).points
        fist[.thumbTip] = fist[.indexTip]
        XCTAssertEqual(ShipHandPose(points:fist).classify(),.neutral)
    }
    func testPinchHoldStopsOnReleaseAndTrackingLoss() {
        var f = HandGestureFilter()
        f.observe(.pinch,at:0)
        XCTAssertFalse(f.input(at:0.1).firing)
        f.observe(.pinch,at:0.2)
        XCTAssertTrue(f.input(at:0.2).firing)
        f.observe(.neutral,at:0.21)
        XCTAssertFalse(f.input(at:0.21).firing)
        f.observe(.pinch,at:0.3); f.observe(.pinch,at:0.5)
        XCTAssertTrue(f.input(at:0.5).firing)
        XCTAssertFalse(f.input(at:0.8).firing)
        f.observe(nil,at:0.81)
        XCTAssertFalse(f.input(at:0.81).firing)
    }
    func testCameraSwitchIsOneShotAndNeedsNeutralRelease() {
        var f = HandGestureFilter()
        f.observe(.neutral,at:0); f.observe(.neutral,at:0.2); f.observe(.neutral,at:0.3)
        for t in stride(from:0.4,through:1.2,by:0.1) { f.observe(.peace,at:t) }
        XCTAssertTrue(f.input(at:1.2).switchCamera)
        XCTAssertFalse(f.input(at:1.21).switchCamera)
        f.observe(nil,at:1.3)
        for t in stride(from:1.4,through:2.2,by:0.1) { f.observe(.peace,at:t) }
        XCTAssertFalse(f.input(at:2.2).switchCamera)
        for t in stride(from:2.3,through:2.7,by:0.1) { f.observe(.neutral,at:t) }
        for t in stride(from:2.8,through:3.6,by:0.1) { f.observe(.peace,at:t) }
        XCTAssertTrue(f.input(at:3.6).switchCamera)
    }
    func testThrottleNeedsHoldAndDoesNotContinueWithoutHand() {
        var f = HandGestureFilter()
        for t in stride(from:0.0,through:0.6,by:0.1) { f.observe(.throttleUp,at:t) }
        XCTAssertEqual(f.input(at:0.6).throttleDirection,1)
        f.observe(.throttleDown,at:0.7)
        XCTAssertEqual(f.input(at:0.7).throttleDirection,0)
        for t in stride(from:0.8,through:1.3,by:0.1) { f.observe(.throttleDown,at:t) }
        XCTAssertEqual(f.input(at:1.3).throttleDirection,-1)
        XCTAssertEqual(f.input(at:1.6).throttleDirection,0)
        f.reset()
        XCTAssertEqual(f.input(at:1.7).throttleDirection,0)
    }
}

final class HandControlTests: XCTestCase {
    func testOnlyPhonesNewerThanIPhone15AreEligible() {
        for model in ["iPhone12,8", "iPhone15,4", "iPhone16,1", "iPhone16,2", "arm64", "iPhonebad,1"] {
            XCTAssertFalse(HandControlSupport.supports(model: model), model)
        }
        for model in ["iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4", "iPhone17,5", "iPhone18,1", "iPad11,6", "iPad17,1"] {
            XCTAssertTrue(HandControlSupport.supports(model: model), model)
        }
    }
    func testCalibrationSmoothingDirectionsAndLostHandSafety() {
        var filter = HandSteeringFilter()
        filter.observe([0.5, 0.5], at: 0)
        for index in 1...3 { filter.observe([0.5, 0.5], at: Double(index) * 0.1) }
        XCTAssertFalse(filter.calibrated)
        for index in 4...9 { filter.observe([0.5, 0.5], at: Double(index) * 0.1) }
        XCTAssertTrue(filter.calibrated)
        XCTAssertEqual(filter.input(at: 0.9, dt: 1/60), .zero)
        filter.observe([0.72, 0.72], at: 1)
        let first = filter.input(at: 1, dt: 1/60)
        XCTAssertGreaterThan(first.x, 0); XCTAssertLessThan(first.x, 0.3)
        XCTAssertGreaterThan(first.y, 0)
        XCTAssertGreaterThan(filter.input(at: 1.02, dt: 1/60).x, first.x)
        XCTAssertEqual(filter.input(at: 1.4, dt: 1/60), .zero)
        XCTAssertTrue(filter.calibrated) // Keep the paired center through occlusion.
        filter.observe([0.28, 0.28], at: 2)
        let opposite = filter.input(at: 2, dt: 1/60)
        XCTAssertLessThan(opposite.x, 0); XCTAssertLessThan(opposite.y, 0)
        filter.reset()
        XCTAssertFalse(filter.calibrated); XCTAssertEqual(filter.axes, .zero)
    }
    func testRangeLimitPausesAndResumesAtOriginalCenter() {
        var filter = HandSteeringFilter()
        filter.observe([0.5, 0.5], at: 0, span: 0.2)
        for index in 1...9 { filter.observe([0.5, 0.5], at: Double(index) * 0.1, span: 0.2) }
        filter.observe([0.7, 0.5], at: 1, span: 0.045)
        XCTAssertTrue(filter.outOfRange)
        XCTAssertEqual(filter.input(at: 1, dt: 1/60), .zero)
        XCTAssertTrue(filter.calibrated)
        // Hysteresis keeps borderline sizes from flickering in and out.
        filter.observe([0.7, 0.5], at: 1.1, span: 0.07)
        XCTAssertTrue(filter.outOfRange)
        filter.observe([0.7, 0.5], at: 1.2, span: 0.15)
        XCTAssertFalse(filter.outOfRange)
        XCTAssertGreaterThan(filter.input(at: 1.2, dt: 1/60).x, 0)
        filter.observe(nil, at: 1.3)
        XCTAssertEqual(filter.input(at: 1.3, dt: 1/60), .zero)
        filter.suspend()
        XCTAssertTrue(filter.calibrated)
    }
    func testMovingHandCannotCalibrateAndSmallJitterDoesNotSteer() {
        var filter = HandSteeringFilter()
        for index in 0..<20 { filter.observe([Float(index) * 0.05, 0.5], at: Double(index) * 0.1) }
        XCTAssertFalse(filter.calibrated)
        filter.reset()
        filter.observe([0.5, 0.5], at: 0)
        filter.observe(nil, at: 0.3)
        filter.observe([0.5, 0.5], at: 0.9)
        XCTAssertFalse(filter.calibrated)
        for index in 10...18 { filter.observe([0.5, 0.5], at: Double(index) * 0.1) }
        filter.observe([0.51, 0.49], at: 1.9)
        XCTAssertEqual(filter.input(at: 1.9, dt: 1/30), .zero)
        XCTAssertTrue(filter.calibrated)
    }
    func testNaturalTurnsUseWiderTravelAndBothDirectionsMatch() {
        func steering(center: SIMD2<Float>, move: SIMD2<Float>, span: Float = 0.15) -> SIMD2<Float> {
            var filter = HandSteeringFilter()
            for index in 0...9 { filter.observe(center, at: Double(index) * 0.1) }
            for index in 10...25 {
                let time = Double(index) * 0.1
                filter.observe(center + move, at: time, span: span)
                _ = filter.input(at: time, dt: 0.1)
            }
            XCTAssertTrue(filter.tracking)
            return filter.axes
        }
        let left = steering(center: [0.5, 0.5], move: [-0.05, 0])
        let right = steering(center: [0.5, 0.5], move: [0.05, 0])
        XCTAssertLessThan(left.x, -0.15) // Small intentional movement turns readily.
        XCTAssertEqual(-left.x, right.x, accuracy: 0.001)
        XCTAssertEqual(left.y, 0, accuracy: 0.001)
        let medium = steering(center: [0.5, 0.5], move: [0.22, 0])
        XCTAssertLessThan(medium.x, 0.85) // Old mapping was already saturated here.
        XCTAssertGreaterThan(steering(center: [0.5, 0.5], move: [0.34, 0]).x, 0.98)
        XCTAssertLessThan(steering(center: [0.2, 0.5], move: [-0.17, 0]).x, -0.98)
        let distant = steering(center: [0.5, 0.5], move: [-0.05, 0], span: 0.055)
        XCTAssertLessThan(distant.x, left.x) // Less image travel needed further away.
    }
    func testHandSettingPersistsAndDefaultsOff() {
        let name = "HandControlTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var settings = GameSettings(defaults: defaults)
        XCTAssertFalse(settings.handControlEnabled)
        settings.handControlEnabled = true; settings.save(defaults: defaults)
        XCTAssertTrue(GameSettings(defaults: defaults).handControlEnabled)
    }
}

final class FlightSystemsTests: XCTestCase {
    let terrain = TerrainGenerator()

    func testObjectiveDistanceIsUsefulNearLandingAndSafeForInvalidValues() {
        var hud = HUDSnapshot()
        for (distance, label): (Float, String) in [(0, "0 m"), (36, "36 m"), (820, "820 m"), (1000, "1.0 km"), (2560, "2.6 km"), (-8, "0 m"), (.infinity, "—"), (.nan, "—")] {
            hud.checkpointDistance = distance
            XCTAssertEqual(hud.checkpointDistanceLabel, label)
        }
        XCTAssertFalse(hud.shieldNeedsAttention)
        hud.shield = 95
        XCTAssertTrue(hud.shieldNeedsAttention) // Damage stays visible after pursuers leave.
    }

    func testTerrainIsDeterministicAndSeeded() {
        XCTAssertEqual(terrain.height(x: -340, z: -3100), TerrainGenerator().height(x: -340, z: -3100))
        XCTAssertNotEqual(terrain.height(x: -340, z: -3100), TerrainGenerator(seed: 42).height(x: -340, z: -3100))
        XCTAssertGreaterThan(terrain.height(x: 1500, z: -2000), terrain.height(x: terrain.valleyCenter(at: -2000), z: -2000) + 300)
    }

    func testCollisionHeightMatchesRenderedTriangleInterior() {
        let mesh = terrain.mesh(key: TileKey(x: -1, z: -3), divisions: 24)
        // Validate both halves of many terrain cells, excluding skirt triangles.
        for face in stride(from: 0, to: 24 * 24 * 2, by: 13) {
            let a = mesh.positions[face * 3], b = mesh.positions[face * 3 + 1], c = mesh.positions[face * 3 + 2]
            let point = a * 0.2 + b * 0.3 + c * 0.5
            XCTAssertEqual(terrain.surfaceHeight(x: point.x, z: point.z), point.y, accuracy: 0.003)
            XCTAssertGreaterThan(mesh.normals[face * 3].y, 0)
        }
    }

    func testNeighboringTilesShareEdgeHeights() {
        let left = terrain.mesh(key: TileKey(x: -1, z: 0), divisions: 24)
        let right = terrain.mesh(key: TileKey(x: 0, z: 0), divisions: 24)
        let lhs = Set(left.positions.filter { $0.x == 0 }.map { "\($0.y),\($0.z)" })
        let rhs = Set(right.positions.filter { $0.x == 0 }.map { "\($0.y),\($0.z)" })
        XCTAssertEqual(lhs, rhs)
    }

    func testCruiseRemainsFlyableAndThrottleAffectsSpeed() {
        let physics = FlightPhysics()
        var cruise = FlightState(), idle = FlightState(), full = FlightState()
        for _ in 0..<3600 {
            physics.advance(&cruise, input: FlightInput(), wind: .zero, dt: FlightPhysics.step)
            physics.advance(&idle, input: FlightInput(throttle: 0), wind: .zero, dt: FlightPhysics.step)
            physics.advance(&full, input: FlightInput(throttle: 1), wind: .zero, dt: FlightPhysics.step)
        }
        XCTAssertTrue(cruise.position.y.isFinite)
        XCTAssertGreaterThan(cruise.airspeed, 30)
        XCTAssertLessThan(cruise.airspeed, 90)
        XCTAssertLessThan(abs(cruise.position.y - 430), 100)
        XCTAssertLessThan(idle.position.y, full.position.y)
        XCTAssertGreaterThan(full.airspeed, idle.airspeed)
    }

    func testPitchRollAndRudderChangeFlight() {
        var climb = FlightState(), right = FlightState(), yaw = FlightState()
        let physics = FlightPhysics()
        for _ in 0..<600 {
            physics.advance(&climb, input: FlightInput(pitch: 0.5, throttle: 1), wind: .zero, dt: FlightPhysics.step)
            physics.advance(&right, input: FlightInput(roll: 0.6), wind: .zero, dt: FlightPhysics.step)
            physics.advance(&yaw, input: FlightInput(yaw: -1), wind: .zero, dt: FlightPhysics.step)
        }
        XCTAssertGreaterThan(climb.position.y, 450)
        XCTAssertGreaterThan(right.position.x, 0)
        XCTAssertGreaterThan(right.heading, 0)
        XCTAssertLessThan(yaw.heading, 0)
    }

    func testHyperspacePortalEntersAsteroidFieldAndReturns() {
        let freeRoam = TerrainGenerator(seed: FlightLevel.freeRoam.seed, level: .freeRoam)
        var hyperspace = HyperspaceManager(terrain: freeRoam)
        var state = FlightState()
        XCTAssertEqual(hyperspace.portals.count, 4)
        state.position = hyperspace.portals[0].position
        XCTAssertEqual(hyperspace.advance(state: &state, collisionRadius: 8, dt: FlightPhysics.step), .beganHyperspace)
        XCTAssertEqual(hyperspace.zone, .hyperspace)
        XCTAssertEqual(hyperspace.jumpTimeRemaining, 5, accuracy: 0.001)
        XCTAssertEqual(hyperspace.advance(state: &state, collisionRadius: 8, dt: 4.8), .none)
        XCTAssertEqual(hyperspace.zone, .hyperspace)
        XCTAssertEqual(hyperspace.advance(state: &state, collisionRadius: 8, dt: 0.21), .enteredSpace)
        XCTAssertEqual(hyperspace.zone, .asteroidField)
        XCTAssertEqual(hyperspace.targetName(to: state.position), "Return portal")
        XCTAssertEqual(hyperspace.asteroids.count, SpaceChallenge.asteroidBelt.asteroidCount)

        state.position = hyperspace.returnPortal
        XCTAssertEqual(hyperspace.advance(state: &state, collisionRadius: 8, dt: 2.1), .returnedToAtmosphere)
        XCTAssertEqual(hyperspace.zone, .atmosphere)
        XCTAssertGreaterThan(state.velocity.z, 0)
    }

    func testAsteroidsApproachAndImpactOnlyDamagesOnceDuringCooldown() {
        let freeRoam = TerrainGenerator(seed: FlightLevel.freeRoam.seed, level: .freeRoam)
        var hyperspace = HyperspaceManager(terrain: freeRoam)
        var state = FlightState()
        state.position = hyperspace.portals[2].position
        _ = hyperspace.advance(state: &state, collisionRadius: 8, dt: FlightPhysics.step)
        XCTAssertEqual(hyperspace.advance(state: &state, collisionRadius: 8, dt: 5.01), .enteredSpace)
        XCTAssertEqual(hyperspace.challenge, .cometStorm)
        XCTAssertEqual(hyperspace.asteroids.count, SpaceChallenge.cometStorm.asteroidCount)
        let firstZ = hyperspace.asteroids[0].position.z
        let firstVelocity = hyperspace.asteroids[0].velocity
        XCTAssertGreaterThan(simd_length(firstVelocity), 100)
        XCTAssertNotEqual(firstVelocity.x, 0)
        _ = hyperspace.advance(state: &state, collisionRadius: 8, dt: 0.25)
        XCTAssertGreaterThan(hyperspace.asteroids[0].position.z, firstZ)
        XCTAssertNotEqual(hyperspace.asteroids[0].velocity, firstVelocity)

        state.position = hyperspace.asteroids[0].position
        XCTAssertEqual(hyperspace.advance(state: &state, collisionRadius: 8, dt: 0), .asteroidImpact(damage: 34))
        state.position = hyperspace.asteroids[1].position
        XCTAssertEqual(hyperspace.advance(state: &state, collisionRadius: 8, dt: FlightPhysics.step), .none)
    }

    func testPlayerFireDestroysAndRecyclesOneAsteroidPerBolt() {
        let terrain = TerrainGenerator(seed: FlightLevel.freeRoam.seed, level: .freeRoam)
        var hyperspace = HyperspaceManager(terrain: terrain)
        var state = FlightState()
        state.position = hyperspace.portals[1].position
        _ = hyperspace.advance(state: &state, collisionRadius: 8, dt: FlightPhysics.step)
        _ = hyperspace.advance(state: &state, collisionRadius: 8, dt: 5.01)

        let target = hyperspace.asteroids[0]
        let bolt = PlayerBolt(position: target.position, velocity: .zero, damage: 10)
        let consumed = hyperspace.resolvePlayerFire([bolt], shipPosition: state.position)

        XCTAssertEqual(consumed, [0])
        XCTAssertEqual(hyperspace.destroyedAsteroids, 1)
        XCTAssertNotEqual(hyperspace.asteroids[0].id, target.id)
        XCTAssertLessThan(hyperspace.asteroids[0].position.z, state.position.z - 1_500)
    }

    func testSpacePhysicsHasNoGravityAndFollowsShipNose() {
        let physics = FlightPhysics(aircraft: .xwing)
        var state = FlightState()
        state.position = .zero
        state.velocity = [0, 0, -AircraftType.xwing.cruiseSpeed]
        state.airspeed = AircraftType.xwing.cruiseSpeed
        for _ in 0..<480 {
            physics.advanceSpace(&state, input: FlightInput(pitch: 0.45, roll: 0.55, throttle: 0.9), dt: FlightPhysics.step)
        }
        XCTAssertGreaterThan(state.position.y, 0)
        XCTAssertNotEqual(state.heading, 0)
        XCTAssertGreaterThan(simd_dot(state.velocity, state.forward), state.airspeed * 0.9)
        XCTAssertFalse(state.stalled)
    }

    func testHeldKeyboardControlsSteerAndRelease() {
        var keys = KeyboardControls()
        XCTAssertTrue(keys.press("w"))
        XCTAssertTrue(keys.press("d"))
        XCTAssertTrue(keys.press("e"))
        XCTAssertTrue(keys.press("shift"))
        XCTAssertTrue(keys.press("="))
        XCTAssertFalse(keys.press("w"))
        XCTAssertEqual(keys.stick, [1, 1])
        XCTAssertEqual(keys.rudder, 1)
        XCTAssertEqual(keys.throttleDirection, 1)
        XCTAssertTrue(keys.skidding)
        var state = FlightState()
        let physics = FlightPhysics()
        for _ in 0..<240 {
            physics.advance(&state, input: FlightInput(pitch: keys.stick.y, roll: keys.stick.x,
                                                       yaw: keys.rudder, throttle: 0.8),
                            wind: .zero, dt: FlightPhysics.step)
        }
        XCTAssertGreaterThan(state.pitch, 0)
        XCTAssertGreaterThan(state.heading, 0)
        keys.release("w")
        keys.release("d")
        XCTAssertEqual(keys.stick, .zero)
        keys.clear()
        XCTAssertEqual(keys.rudder, 0)
        XCTAssertFalse(keys.skidding)
        XCTAssertEqual(keys.throttleDirection, 0)
    }

    func testTurningAroundKeepsShipsMovingNoseFirst() {
        for aircraft in AircraftType.allCases {
            let physics = FlightPhysics(aircraft: aircraft)
            var state = FlightState()
            state.velocity = [0, 0, -aircraft.cruiseSpeed]
            state.airspeed = aircraft.cruiseSpeed
            var turn: Float = 0
            var minimumAirspeed = aircraft.cruiseSpeed
            for _ in 0..<5400 {
                let previous = state.heading
                physics.advance(&state, input: FlightInput(roll: 0.65, yaw: 0.6, throttle: 0.9),
                                wind: .zero, dt: FlightPhysics.step)
                turn += atan2(sin(state.heading - previous), cos(state.heading - previous))
                minimumAirspeed = min(minimumAirspeed, state.airspeed)
                let nose = SIMD3<Float>(sin(state.heading), 0, -cos(state.heading))
                XCTAssertGreaterThanOrEqual(simd_dot(state.velocity, nose), -0.001, aircraft.name)
            }
            XCTAssertGreaterThan(turn, .pi, aircraft.name)
            XCTAssertGreaterThan(minimumAirspeed, aircraft.cruiseSpeed * 0.55, aircraft.name)
        }
    }

    func testPodRacerTurnsRespondQuicklyWithoutExcessiveBankAndGainSpeedOnBoost() {
        let physics = FlightPhysics(aircraft: .anakinPodracer)
        var turning = FlightState(), boosted = FlightState()
        for state in [turning, boosted] {
            XCTAssertEqual(state.heading, 0)
        }
        turning.velocity = [0, 0, -AircraftType.anakinPodracer.cruiseSpeed]
        turning.airspeed = AircraftType.anakinPodracer.cruiseSpeed
        boosted = turning
        for _ in 0..<360 {
            physics.advance(&turning, input: FlightInput(roll: 0.8, throttle: 0.9), wind: .zero, dt: FlightPhysics.step)
            physics.advance(&boosted, input: FlightInput(throttle: 1, boost: true), wind: .zero, dt: FlightPhysics.step)
        }
        XCTAssertGreaterThan(turning.heading, 0.12)
        XCTAssertLessThan(abs(turning.roll), AircraftType.anakinPodracer.maximumRoll * 0.8)
        XCTAssertGreaterThan(boosted.airspeed, turning.airspeed)
        XCTAssertGreaterThanOrEqual(simd_dot(turning.velocity, SIMD3<Float>(sin(turning.heading), 0, -cos(turning.heading))), 0)
    }

    func testPodRacerSkidCreatesLateralDriftAndKeepsHoverHeightFlat() {
        let physics = FlightPhysics(aircraft: .anakinPodracer)
        var normal = FlightState(), skidding = FlightState()
        for state in [normal, skidding] { XCTAssertEqual(state.position.y, 430) }
        normal.velocity = [0, 0, -205]
        normal.airspeed = 205
        skidding = normal
        for _ in 0..<180 {
            physics.advance(&normal, input: FlightInput(roll: 1, throttle: 1), wind: .zero, dt: FlightPhysics.step)
            physics.advance(&skidding, input: FlightInput(roll: 1, throttle: 1, skid: true), wind: .zero, dt: FlightPhysics.step)
        }
        XCTAssertEqual(normal.position.y, 430, accuracy: 0.001)
        XCTAssertEqual(skidding.position.y, 430, accuracy: 0.001)
        XCTAssertGreaterThan(abs(skidding.position.x), abs(normal.position.x) * 1.4)
    }

    func testRacerContactShovesBothCraftAndAllowsRecovery() {
        let terrain = TerrainGenerator(seed: FlightLevel.boontaEve.seed, level: .boontaEve)
        var race = PodRaceManager(terrain: terrain, aircraft: .anakinPodracer)
        var player = FlightState()
        player.position = race.opponents[0].position
        race.resolveContact(player: &player, dt: FlightPhysics.step)
        XCTAssertNotEqual(player.velocity.x, 0)
        XCTAssertNotEqual(race.opponents[0].lateralVelocity, 0)
        for _ in 0..<400 {
            _ = race.advance(position: player.position, requestedBoost: false, dt: FlightPhysics.step)
        }
        XCTAssertTrue(race.opponents[0].active)
        XCTAssertLessThan(abs(race.opponents[0].lateralOffset), terrain.level.valleyWidth * 0.68)
    }

    func testPodCanDriveCompleteLapIncludingBothDirectionReversals() {
        for level in [FlightLevel.boontaEve, .narShaddaa] {
            let circuit = RaceCircuit(level: level)
            var state = FlightState()
            state.position = circuit.point(at: 0)
            state.velocity = [0, 0, -205]
            state.airspeed = 205
            let physics = FlightPhysics(aircraft: .anakinPodracer)
            var checkpoints = CheckpointSystem(terrain: TerrainGenerator(level: level), aircraft: .anakinPodracer)
            for _ in 0..<18000 {
                let projected = circuit.projection(state.position).distance
                let target = circuit.point(at: projected + 160)
                let desiredHeading = atan2(target.x - state.position.x, -(target.z - state.position.z))
                let error = atan2(sin(desiredHeading - state.heading), cos(desiredHeading - state.heading))
                let previous = state.position
                physics.advance(&state, input: FlightInput(roll: clamp(error * 3.2, -1, 1), throttle: 0.65), wind: .zero, dt: FlightPhysics.step)
                _ = checkpoints.advance(from: previous, to: state.position)
                XCTAssertLessThan(circuit.projection(state.position).offset, level.valleyWidth * 0.48, level.name)
                if checkpoints.nextIndex >= level.gateCount { break }
            }
            XCTAssertGreaterThanOrEqual(checkpoints.nextIndex, level.gateCount, level.name)
        }
    }

    func testSkiddingAndContactChargeRaceEffects() {
        let terrain = TerrainGenerator(seed: FlightLevel.boontaEve.seed, level: .boontaEve)
        var race = PodRaceManager(terrain: terrain, aircraft: .anakinPodracer)
        var player = FlightState()
        player.position = race.opponents[0].position
        race.resolveContact(player: &player, skidding: true, dt: FlightPhysics.step)
        XCTAssertEqual(race.skidIntensity, 1)
        XCTAssertEqual(race.collisionShake, 1)
    }

    func testDeathStarTrenchIsCutIntoStationSurface() {
        let station = TerrainGenerator(seed: FlightLevel.deathStar.seed, level: .deathStar)
        for z in [-1200, -5700, -11100] as [Float] {
            let center = station.valleyCenter(at: z)
            let floor = station.surfaceHeight(x: center, z: z)
            let inner = station.surfaceHeight(x: center + 100, z: z)
            let wall = station.surfaceHeight(x: center + 215, z: z)
            let deck = station.surfaceHeight(x: center + 400, z: z)
            XCTAssertLessThan(abs(inner - floor), 10)
            XCTAssertGreaterThan(wall, floor + 100)
            XCTAssertGreaterThan(deck, floor + 285)
            XCTAssertLessThan(abs(station.surfaceHeight(x: center + 800, z: z) - deck), 15)
            XCTAssertLessThan(floor + FlightLevel.deathStar.gateClearance + FlightLevel.deathStar.gateRadius, deck)
        }
    }

    func testDeathStarTurnsRemainNavigableBetweenGates() {
        let station = TerrainGenerator(seed: FlightLevel.deathStar.seed, level: .deathStar)
        let depths = [Float(250)] + FlightLevel.deathStar.gateDepths.map { -$0 }
        XCTAssertGreaterThan(abs(station.valleyCenter(at: -1000) - station.valleyCenter(at: 250)), 200)
        for (start, end) in zip(depths, depths.dropFirst()) {
            let first = station.valleyCenter(at: start)
            let last = station.valleyCenter(at: end)
            for index in 0...40 {
                let fraction = Float(index) / 40
                let z = start + (end - start) * fraction
                let direct = first + (last - first) * fraction
                XCTAssertLessThan(abs(station.valleyCenter(at: z) - direct), 105)
            }
        }
    }

    func testTurretFireHitsAndResets() {
        let station = TerrainGenerator(seed: FlightLevel.deathStar.seed, level: .deathStar)
        var defenses = DeathStarDefenses(terrain: station)
        XCTAssertEqual(defenses.turrets.count, 17)
        var ship = FlightState()
        ship.position = [station.valleyCenter(at: -400), 300, -400]
        ship.velocity = .zero
        var fired = false
        var hit = false
        for _ in 0..<600 {
            let event = defenses.update(from: ship, to: ship, passedGates: 0, dt: FlightPhysics.step)
            fired = fired || event.fired
            hit = hit || event.hit
            if hit { break }
        }
        XCTAssertTrue(fired)
        XCTAssertTrue(hit)
        defenses.reset()
        XCTAssertTrue(defenses.bolts.isEmpty)
        XCTAssertTrue(DeathStarDefenses(terrain: TerrainGenerator()).turrets.isEmpty)
    }

    func testBossFightersWaitForThirdGateAndJoinInWaves() {
        let station = TerrainGenerator(seed: FlightLevel.deathStar.seed, level: .deathStar)
        var defenses = DeathStarDefenses(terrain: station)
        var ship = FlightState()
        ship.position = [station.valleyCenter(at: -400), 300, -400]
        ship.velocity = .zero
        var fireTimes: [Float] = []
        var pursuerShot = false
        for tick in 0..<840 {
            let elapsed = Float(tick) * FlightPhysics.step
            let event = defenses.update(from: ship, to: ship, passedGates: 2, dt: FlightPhysics.step)
            if event.fired { fireTimes.append(elapsed) }
        }
        XCTAssertGreaterThanOrEqual(fireTimes.count, 5)
        for (first, second) in zip(fireTimes, fireTimes.dropFirst()) {
            XCTAssertLessThan(second - first, 1.3)
        }
        XCTAssertTrue(defenses.pursuers.isEmpty)
        for _ in 0..<1000 {
            _ = defenses.update(from: ship, to: ship, passedGates: 3, dt: FlightPhysics.step)
            pursuerShot = pursuerShot || defenses.bolts.contains(where: \.fromPursuer)
        }
        XCTAssertEqual(defenses.pursuers.count, 1)
        _ = defenses.update(from: ship, to: ship, passedGates: 5, dt: FlightPhysics.step)
        XCTAssertEqual(defenses.pursuers.count, 1)
        _ = defenses.update(from: ship, to: ship, passedGates: 6, dt: FlightPhysics.step)
        XCTAssertEqual(defenses.pursuers.count, 2)
        _ = defenses.update(from: ship, to: ship, passedGates: 9, dt: FlightPhysics.step)
        XCTAssertEqual(defenses.pursuers.count, 3)
        XCTAssertTrue(pursuerShot)
        defenses.reset()
        XCTAssertTrue(defenses.pursuers.isEmpty)
    }

    func testSweptCollisionAndSafeFlight() {
        let collision = CollisionSystem(terrain: terrain)
        var start = FlightState()
        start.position = [0, terrain.surfaceHeight(x: 0, z: 0) + 100, 0]
        var end = start
        end.position.y -= 150
        XCTAssertNotNil(collision.impact(from: start, to: end))
        end.position = start.position + SIMD3<Float>(0, 0, -20)
        XCTAssertNil(collision.impact(from: start, to: end))
        end.position.y = terrain.surfaceHeight(x: 0, z: -20) + 25
        XCTAssertEqual(collision.warning(for: end), "TERRAIN · PULL UP")
    }

    func testWingTipCollision() {
        let collision = CollisionSystem(terrain: terrain)
        var state = FlightState()
        state.position = [1200, terrain.surfaceHeight(x: 1200, z: -1200) + 4, -1200]
        state.roll = .pi / 2
        XCTAssertNotNil(collision.impact(from: state, to: state))
    }

    func testCheckpointRequiresCorrectDirectionAndOpening() {
        var route = CheckpointSystem(terrain: terrain)
        let gate = route.next!.position
        XCTAssertFalse(route.advance(from: gate + [0, 0, -10], to: gate + [0, 0, 10]))
        XCTAssertFalse(route.advance(from: gate + [200, 0, 10], to: gate + [200, 0, -10]))
        XCTAssertTrue(route.advance(from: gate + [0, 0, 10], to: gate + [0, 0, -10]))
        XCTAssertEqual(route.nextIndex, 1)
        XCTAssertFalse(route.advance(from: gate + [0, 0, 10], to: gate + [0, 0, -10]))
        while let next = route.next {
            XCTAssertTrue(route.advance(from: next.position + [0, 0, 10], to: next.position + [0, 0, -10]))
        }
        XCTAssertTrue(route.complete)
        route.reset()
        XCTAssertEqual(route.nextIndex, 0)
        XCTAssertFalse(route.complete)
    }
}

final class FlightEconomyTests: XCTestCase {
    struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    }
    func testExactQuarterCreditsAndPersistence() {
        let name = "EconomyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName:name)!; defer { defaults.removePersistentDomain(forName:name) }
        var wallet = FlightEconomy()
        wallet.earn(lowFlightPoints:1); XCTAssertEqual(wallet.creditsLabel,"0.25")
        wallet.earn(lowFlightPoints:3); XCTAssertEqual(wallet.creditsLabel,"1.00")
        wallet.earn(lowFlightPoints:-5); XCTAssertEqual(wallet.quarterCredits,4)
        wallet.save(to:defaults)
        XCTAssertEqual(FlightEconomy.load(from:defaults).quarterCredits,4)
    }
    func testPackCostCardsAndNoNegativeBalance() {
        var wallet = FlightEconomy(), rng = Seeded(state:21)
        XCTAssertNil(wallet.buy(.scout,rng:&rng)); XCTAssertEqual(wallet.quarterCredits,0)
        wallet.earn(lowFlightPoints:BlueprintPack.scout.cost*4)
        XCTAssertNotNil(wallet.buy(.scout,rng:&rng)); XCTAssertEqual(wallet.quarterCredits,0)
        XCTAssertEqual(wallet.blueprints.values.reduce(0,+),3)
        XCTAssertNil(wallet.buy(.elite,rng:&rng))
        wallet.earn(lowFlightPoints:BlueprintPack.elite.cost*4)
        XCTAssertNotNil(wallet.buy(.elite,rng:&rng)); XCTAssertEqual(wallet.quarterCredits,0)
        XCTAssertEqual(wallet.blueprints.values.reduce(0,+),9)
        XCTAssertEqual(BlueprintPack.scout.weights.reduce(0,+),100)
        XCTAssertEqual(BlueprintPack.elite.weights.reduce(0,+),100)
        XCTAssertGreaterThan(BlueprintPack.elite.weights[2],BlueprintPack.scout.weights[2])
        for pack in BlueprintPack.allCases {
            XCTAssertGreaterThan(pack.weights[0],pack.weights[1])
            XCTAssertGreaterThan(pack.weights[1],pack.weights[2])
        }
    }
    func testRarityUnlocksAndSpareSales() {
        var wallet = FlightEconomy()
        XCTAssertFalse(wallet.unlocked(.bWing)); XCTAssertTrue(wallet.unlocked(.xwing))
        wallet.grant(.bWing,count:11); XCTAssertFalse(wallet.unlocked(.bWing))
        wallet.grant(.bWing,count:1); XCTAssertTrue(wallet.unlocked(.bWing))
        wallet.grant(.bWing,count:3); XCTAssertEqual(wallet.count(for:.bWing),12)
        XCTAssertEqual(wallet.quarterCredits,0)
        XCTAssertEqual(wallet.extras(for:.bWing),3)
        XCTAssertEqual(wallet.sellExtras(for:.bWing),150)
        XCTAssertEqual(wallet.quarterCredits,600)
        XCTAssertEqual(wallet.sellExtras(for:.bWing),0)
        XCTAssertLessThan(AircraftType.bWing.blueprintRequirement,AircraftType.imperialShuttle.blueprintRequirement)
        XCTAssertLessThan(AircraftType.imperialShuttle.blueprintRequirement,AircraftType.tieDefender.blueprintRequirement)
        XCTAssertLessThan(AircraftType.bWing.weaponPower,AircraftType.tieDefender.weaponPower)
    }
    func testSurplusSalesPricesPersistenceAndProtectedProgress() {
        let name = "EconomySales.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        for (ship,price) in [(AircraftType.bWing,50),(.imperialShuttle,150),(.tieDefender,900)] {
            var wallet = FlightEconomy()
            wallet.earn(lowFlightPoints:3)
            wallet.grant(ship,count:ship.blueprintRequirement-1)
            XCTAssertEqual(wallet.sellExtras(for:ship),0)
            wallet.grant(ship,count:4) // One completes the ship; three become tradable.
            XCTAssertEqual(wallet.extras(for:ship),3)
            wallet.save(to:defaults)
            wallet = FlightEconomy.load(from:defaults)
            XCTAssertEqual(wallet.sellExtras(for:ship),price*3)
            XCTAssertEqual(wallet.quarterCredits,3+price*12)
            XCTAssertEqual(wallet.count(for:ship),ship.blueprintRequirement)
            XCTAssertTrue(wallet.unlocked(ship))
            XCTAssertEqual(wallet.sellExtras(for:ship),0)
            wallet.save(to:defaults)
            XCTAssertEqual(FlightEconomy.load(from:defaults),wallet)
        }
    }
    func testDailyWheelPersistsAndOnlyResetsAtNextUTCDay() {
        let name = "EconomyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        var wallet = FlightEconomy(), rng = Seeded(state:7)
        let day = Date(timeIntervalSince1970:2_000_000_000)
        XCTAssertNotNil(wallet.spin(at:day,rng:&rng))
        let before = wallet.quarterCredits, shards = wallet.blueprints
        XCTAssertNil(wallet.spin(at:day,rng:&rng)); XCTAssertEqual(wallet.quarterCredits,before); XCTAssertEqual(wallet.blueprints,shards)
        wallet.save(to:defaults); wallet = FlightEconomy.load(from:defaults)
        XCTAssertFalse(wallet.canSpin(at:day)); XCTAssertFalse(wallet.canSpin(at:day.addingTimeInterval(-86400)))
        let nextMidnight = Date(timeIntervalSince1970:Double(FlightEconomy.day(day)+1)*86400)
        XCTAssertFalse(wallet.canSpin(at:nextMidnight.addingTimeInterval(-1)))
        XCTAssertNotNil(wallet.spin(at:nextMidnight,rng:&rng))
        XCTAssertFalse(wallet.lastSpinReceipt.isEmpty)
    }
    @MainActor
    func testTwoWindowsCannotClaimTheSameDailyReward() {
        let name = "EconomyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        let first = GameEngine(defaults:defaults), second = GameEngine(defaults:defaults)
        let now = Date()
        XCTAssertNotNil(first.spinDailyWheel(at:now))
        let saved = FlightEconomy.load(from:defaults)
        XCTAssertNil(second.spinDailyWheel(at:now))
        XCTAssertEqual(FlightEconomy.load(from:defaults),saved)
        XCTAssertEqual(second.economy,saved)
    }
    func testPackDistributionMakesAdvancedBlueprintsRarer() {
        var rng = Seeded(state:593)
        var totals = [0,0,0]
        for _ in 0..<1000 {
            var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:BlueprintPack.scout.cost*4)
            _ = wallet.buy(.scout,rng:&rng)
            for ship in AircraftType.blueprintFleet { totals[ship.blueprintRarityIndex] += wallet.count(for:ship) }
        }
        XCTAssertEqual(totals.reduce(0,+),3000)
        XCTAssertGreaterThan(totals[0],totals[1]); XCTAssertGreaterThan(totals[1],totals[2])
        XCTAssertEqual(Double(totals[2])/3000,0.01,accuracy:0.008)
    }
    func testExpandedFleetOddsUnlocksAndSaleValues() {
        XCTAssertEqual(AircraftType.blueprintFleet.count,6)
        for pack in BlueprintPack.allCases {
            XCTAssertEqual(AircraftType.blueprintFleet.reduce(0) { $0+pack.chance(for:$1) },100,accuracy:0.001)
        }
        var wallet = FlightEconomy()
        for ship in [AircraftType.tieInterceptor,.slaveI,.scimitar] {
            XCTAssertFalse(wallet.unlocked(ship))
            wallet.grant(ship,count:ship.blueprintRequirement-1)
            XCTAssertFalse(wallet.unlocked(ship))
            wallet.grant(ship,count:3)
            XCTAssertTrue(wallet.unlocked(ship))
            XCTAssertEqual(wallet.extras(for:ship),2)
            XCTAssertEqual(wallet.sellExtras(for:ship),ship.blueprintSaleCredits*2)
        }
        var rng = Seeded(state:724)
        var seen = Set<AircraftType>()
        for _ in 0..<200 {
            wallet.earn(lowFlightPoints:BlueprintPack.nebula.cost*4)
            _ = wallet.buy(.nebula,rng:&rng)
            seen.formUnion((wallet.lastBlueprintRewards ?? []).map(\.ship))
        }
        XCTAssertEqual(seen,Set(AircraftType.blueprintFleet))
    }
    func testOldSaveKeepsCreditsBlueprintsAndCompletedLegendary() throws {
        let name = "EconomyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        let legacy = "{\"quarterCredits\":12345,\"blueprints\":{\"tieDefender\":60,\"bWing\":7},\"lastSpinDay\":23100,\"lastSpinReceipt\":\"Saved prize\"}"
        defaults.set(Data(legacy.utf8),forKey:FlightEconomy.key)
        var wallet = FlightEconomy.load(from:defaults)
        XCTAssertEqual(wallet.quarterCredits,12345)
        XCTAssertEqual(wallet.count(for:.bWing),7)
        XCTAssertTrue(wallet.unlocked(.tieDefender))
        XCTAssertEqual(wallet.lastSpinDay,23100)
        wallet.grant(.tieDefender,count:1)
        XCTAssertEqual(wallet.quarterCredits,12345)
        XCTAssertEqual(wallet.extras(for:.tieDefender),1)
        wallet.save(to:defaults)
        XCTAssertTrue(FlightEconomy.load(from:defaults).unlocked(.tieDefender))
        let partial = legacy.replacingOccurrences(of:"tieDefender\":60",with:"tieDefender\":59")
        defaults.set(Data(partial.utf8),forKey:FlightEconomy.key)
        let unfinished = FlightEconomy.load(from:defaults)
        XCTAssertFalse(unfinished.unlocked(.tieDefender))
        XCTAssertEqual(unfinished.count(for:.tieDefender),59)
    }
    func testEveryPackSavesExactRevealCardsWithoutRerolling() {
        let name = "EconomyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        var rng = Seeded(state:912)
        for pack in BlueprintPack.allCases {
            var wallet = FlightEconomy()
            wallet.earn(lowFlightPoints:pack.cost*4)
            XCTAssertNotNil(wallet.buy(pack,rng:&rng))
            let rewards = wallet.lastBlueprintRewards ?? []
            XCTAssertEqual(rewards.count,pack.cards)
            XCTAssertEqual(Set(rewards.map(\.id)).count,pack.cards)
            XCTAssertEqual(rewards.reduce(0) { $0+$1.collected+($1.spareCount ?? 0)+$1.duplicateCredits/10 },pack.cards)
            for ship in AircraftType.blueprintFleet {
                XCTAssertEqual(rewards.filter { $0.ship == ship }.reduce(0) { $0+$1.collected },wallet.count(for:ship))
            }
            wallet.save(to:defaults)
            XCTAssertEqual(FlightEconomy.load(from:defaults),wallet)
            XCTAssertEqual(FlightEconomy.load(from:defaults).lastBlueprintRewards,rewards)
            XCTAssertEqual(pack.weights.reduce(0,+),100)
        }
    }
    func testDailyCreditPrizeDoesNotReplayAnOldPack() {
        var rng = Seeded(state:177), sawCreditPrize = false
        for _ in 0..<100 {
            var wallet = FlightEconomy()
            wallet.grant(.bWing,count:1)
            let prize = wallet.spin(at:Date(timeIntervalSince1970:2000000000),rng:&rng)
            if [.credits100,.credits250,.credits500].contains(prize) {
                sawCreditPrize = true
                XCTAssertNil(wallet.lastBlueprintRewards)
            } else if prize == .avatarAccessory { XCTAssertFalse(wallet.profile?.owned.isEmpty ?? true) }
            else { XCTAssertFalse(wallet.lastBlueprintRewards?.isEmpty ?? true) }
        }
        XCTAssertTrue(sawCreditPrize)
    }
    func testFuelUsesTravelDistanceAndHandlesFractions() {
        var fuel = FlightFuel()
        fuel.travel(4999); XCTAssertEqual(fuel.percent,99.0002,accuracy:0.00001)
        fuel.travel(1); XCTAssertEqual(fuel.percent,99,accuracy:0.000001)
        fuel.travel(-5000); fuel.travel(.nan); XCTAssertEqual(fuel.percent,99)
        fuel.travel(495000); XCTAssertEqual(fuel.percent,0); XCTAssertTrue(fuel.empty)
        fuel.travel(5000); XCTAssertEqual(fuel.percent,0)
    }
    @MainActor
    func testLockedSelectionCannotBypassCollectionAndUnlockSurvivesReload() {
        let name = "EconomyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        let game = GameEngine(defaults:defaults)
        game.selectAircraft(.tieDefender); XCTAssertEqual(game.aircraft,.kestrel)
        var wallet = FlightEconomy.load(from:defaults)
        wallet.grant(.tieDefender,count:AircraftType.tieDefender.blueprintRequirement); wallet.save(to:defaults)
        let unlocked = GameEngine(defaults:defaults)
        unlocked.selectAircraft(.tieDefender); XCTAssertEqual(unlocked.aircraft,.tieDefender)
        XCTAssertEqual(GameEngine(defaults:defaults).aircraft,.tieDefender)
    }
}

final class PilotLogbookTests: XCTestCase {
    private func record(_ outcome:PilotFlightOutcome = .returned,date:Date = Date()) -> PilotFlightRecord {
        var flight = PilotFlightRecord(startedAt:date.addingTimeInterval(-120),endedAt:date,aircraft:"X-wing",route:"Hoth")
        flight.outcome = outcome; flight.seconds = 120; flight.metres = 12000
        return flight
    }
    func testRanksReviewEveryThirtyFlightsAndDoNotDuplicate() {
        var book = PilotLogbook()
        for _ in 0..<29 { book.append(record()) }
        XCTAssertNil(book.latestReview)
        let thirtieth = record(); XCTAssertTrue(book.append(thirtieth))
        XCTAssertEqual(book.reviews.count,1); XCTAssertEqual(book.latestReview?.score,80)
        XCTAssertFalse(book.append(thirtieth)); XCTAssertEqual(book.rankedFlights.count,30)
        for _ in 0..<29 { book.append(record(.crashed)) }
        XCTAssertEqual(book.latestReview?.score,80)
        book.append(record(.crashed))
        XCTAssertEqual(book.reviews.count,2); XCTAssertEqual(book.latestReview?.crashes,30)
        XCTAssertEqual(book.latestReview?.rank,.cadet)
        XCTAssertEqual(book.latestReview?.flightNumber,60)
    }
    func testShortPracticesInterruptedFlightsAndCrashScores() {
        var flight = record(); flight.seconds = 5
        XCTAssertFalse(flight.ranked)
        flight.outcome = .crashed; XCTAssertTrue(flight.ranked)
        flight.controlledTurns = 100; flight.soaringClimbs = 100; flight.closeShaves = 100
        XCTAssertLessThanOrEqual(flight.score,45)
        flight.outcome = .completed; flight.seconds = 15; XCTAssertTrue(flight.ranked)
        flight.outcome = .interrupted; flight.seconds = 100; XCTAssertFalse(flight.ranked)
        var safe = record(); let ordinary = safe.score
        safe.stallSeconds = 24; XCTAssertEqual(safe.score,ordinary-25)
        safe.stallSeconds = 0; safe.closeShaves = 999
        XCTAssertEqual(safe.score,ordinary+2) // Dangerous flying cannot dominate the review.
        safe.controlledTurns = 20; XCTAssertEqual(safe.score,100)
    }
    func testDistanceSkipsTeleportsAndHyperspaceAndCountsActualSecondsOnly() {
        var tracker = PilotFlightTracker(aircraft:"X-wing",route:"Space")
        var state = FlightState(); state.position = .zero; state.airspeed = 100
        tracker.observe(state:state,clearance:nil,planet:nil,region:"space",canManeuver:true,dt:0.1)
        for _ in 0..<10 {
            state.position.z -= 10
            tracker.observe(state:state,clearance:nil,planet:nil,region:"space",canManeuver:true,dt:0.1)
        }
        XCTAssertEqual(tracker.record.metres,100,accuracy:0.01)
        state.position.z -= 10000
        tracker.observe(state:state,clearance:nil,planet:nil,region:"space",canManeuver:true,dt:0.1)
        XCTAssertEqual(tracker.record.metres,100,accuracy:0.01)
        for _ in 0..<10 {
            state.position.z -= 10
            tracker.observe(state:state,clearance:nil,planet:nil,region:"jump",canManeuver:false,countDistance:false,dt:0.1)
        }
        XCTAssertEqual(tracker.record.metres,100,accuracy:0.01)
        let seconds = tracker.record.seconds
        tracker.observe(state:state,clearance:nil,planet:nil,region:"space",canManeuver:true,dt:.nan)
        XCTAssertEqual(tracker.record.seconds,seconds)
        tracker.relocate(); state.position = [10000,500,9000]
        tracker.observe(state:state,clearance:500,planet:.hoth,region:"hoth",canManeuver:true,dt:0.1)
        XCTAssertEqual(tracker.record.metres,100,accuracy:0.01)
    }
    func testCloseShaveNeedsSafeRecoveryAndDoesNotRepeatDuringCooldown() {
        var tracker = PilotFlightTracker(aircraft:"X-wing",route:"Hoth")
        var state = FlightState(); state.position = [0,100,0]; state.airspeed = 100
        func samples(_ clearance:Float,_ count:Int) {
            for _ in 0..<count {
                state.position.z -= 10
                tracker.observe(state:state,clearance:clearance,planet:nil,region:"terrain",canManeuver:true,dt:0.1)
            }
        }
        samples(100,12); samples(20,6)
        XCTAssertEqual(tracker.record.closeShaves,0)
        samples(60,12); XCTAssertEqual(tracker.record.closeShaves,1)
        samples(20,6); samples(60,12); XCTAssertEqual(tracker.record.closeShaves,1)
        samples(100,220); samples(5,2); samples(20,8); samples(60,12)
        XCTAssertEqual(tracker.record.closeShaves,1)
        samples(20,6); samples(60,12); XCTAssertEqual(tracker.record.closeShaves,2)
    }
    func testControlledTurnsHandleHeadingWrapAndRequireLevellingBetweenTurns() {
        var tracker = PilotFlightTracker(aircraft:"X-wing",route:"Space")
        var state = FlightState(); state.position = .zero; state.airspeed = 100; state.heading = 3
        func turn(_ steps:Int) {
            for _ in 0..<steps {
                state.position.z -= 5; state.roll = 0.5
                state.heading = atan2(sin(state.heading+0.04),cos(state.heading+0.04))
                tracker.observe(state:state,clearance:200,planet:nil,region:"terrain",canManeuver:true,dt:0.1)
            }
        }
        turn(45); XCTAssertEqual(tracker.record.controlledTurns,1)
        turn(80); XCTAssertEqual(tracker.record.controlledTurns,1)
        state.roll = 0
        tracker.observe(state:state,clearance:200,planet:nil,region:"terrain",canManeuver:true,dt:0.1)
        turn(45); XCTAssertEqual(tracker.record.controlledTurns,2)
    }
    func testSoaringNeedsSustainedClearClimbAndCannotRepeatOneClimb() {
        var tracker = PilotFlightTracker(aircraft:"X-wing",route:"Hoth")
        var state = FlightState(); state.position = [0,500,0]; state.airspeed = 100; state.velocity.y = 15
        for _ in 0..<220 {
            state.position += [0,1.5,-5]
            tracker.observe(state:state,clearance:200,planet:nil,region:"terrain",canManeuver:true,dt:0.1)
        }
        XCTAssertEqual(tracker.record.soaringClimbs,1)
        state.velocity.y = 0
        tracker.observe(state:state,clearance:200,planet:nil,region:"terrain",canManeuver:true,dt:0.1)
        state.velocity.y = 15
        for _ in 0..<110 {
            state.position += [0,1.5,-5]
            tracker.observe(state:state,clearance:200,planet:nil,region:"terrain",canManeuver:true,dt:0.1)
        }
        XCTAssertEqual(tracker.record.soaringClimbs,2)
    }
    func testHothNorthernExpeditionRequiresTheReturnJourneyOnSameSurface() {
        var tracker = PilotFlightTracker(aircraft:"X-wing",route:"Hoth")
        var state = FlightState(); state.position = [0,600,8400]; state.airspeed = 100
        tracker.observe(state:state,clearance:500,planet:.hoth,region:"hoth",canManeuver:true,dt:0.1)
        for _ in 0..<1441 {
            state.position.z -= 10
            tracker.observe(state:state,clearance:500,planet:.hoth,region:"hoth",canManeuver:true,dt:0.1)
        }
        XCTAssertFalse(tracker.record.hothRoundTrip)
        var abandoned = tracker
        abandoned.relocate()
        state.position.z = 8400
        abandoned.observe(state:state,clearance:500,planet:.hoth,region:"hoth",canManeuver:true,dt:0.1)
        XCTAssertFalse(abandoned.record.hothRoundTrip)
        state.position.z = -6010
        for _ in 0..<1400 {
            state.position.z += 10
            tracker.observe(state:state,clearance:500,planet:.hoth,region:"hoth",canManeuver:true,dt:0.1)
        }
        XCTAssertTrue(tracker.record.hothRoundTrip)
    }
    @MainActor
    func testInterruptedDraftRecoveryIsIdempotentAndKeepsOtherWindowsLive() {
        let name = "PilotRecovery.\(UUID())"
        let defaults = UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        let session = UUID(), first = PilotLogbookStore(defaults:defaults,session:session)
        var flight = record(); flight.metres = 20000
        first.checkpoint(flight)
        XCTAssertTrue(first.recover().flights.isEmpty) // Another window in this process is still active.
        let relaunched = PilotLogbookStore(defaults:defaults,session:UUID())
        let recovered = relaunched.recover()
        XCTAssertEqual(recovered.flights.count,1)
        XCTAssertEqual(recovered.flights.first?.outcome,.interrupted)
        XCTAssertTrue(recovered.rankedFlights.isEmpty)
        XCTAssertNotNil(recovered.awards[PilotAchievement.km20.rawValue])
        XCTAssertEqual(relaunched.recover(),recovered)
        flight.outcome = .crashed
        var committed = relaunched.load(); XCTAssertFalse(committed.append(flight))
    }
    func testLifetimeAchievementsIncludingTwentyThousandKilometresAndSafeStreak() {
        var book = PilotLogbook(), flight = record()
        flight.metres = 20_000_000; flight.hothRoundTrip = true
        flight.visitedPlanets = Set(SpacePlanet.allCases.map(\.rawValue))
        book.append(flight)
        let now = Date(), earned = book.unlock(at:now)
        XCTAssertTrue(earned.contains(.km20000)); XCTAssertTrue(earned.contains(.hothReturn)); XCTAssertTrue(earned.contains(.worlds4))
        XCTAssertTrue(book.unlock(at:now.addingTimeInterval(1000)).isEmpty)
        XCTAssertEqual(book.awards[PilotAchievement.km20000.rawValue],now)
        for _ in 0..<9 { book.append(record()) }
        XCTAssertTrue(book.unlock(at:now).contains(.safe10))
        book.append(record(.crashed)); XCTAssertEqual(book.progress(.safe10),0)
        XCTAssertNotNil(book.awards[PilotAchievement.safe10.rawValue])
    }
    func testCalendarMonthRollingThirtyDaysAndYearUseDistinctRealDateBuckets() throws {
        var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(secondsFromGMT:0)!
        func date(_ month:Int,_ day:Int) -> Date { calendar.date(from:DateComponents(year:2026,month:month,day:day,hour:12))! }
        let anchor = date(10,15)
        var book = PilotLogbook()
        for day in [date(9,10),date(9,25),date(10,1),date(10,15)] { book.append(record(date:day)) }
        XCTAssertEqual(book.chartFlights(period:.month,ending:anchor,calendar:calendar).count,2)
        XCTAssertEqual(book.chartFlights(period:.days30,ending:anchor,calendar:calendar).count,3)
        XCTAssertEqual(book.chartFlights(period:.year,ending:anchor,calendar:calendar).count,4)
        let year = book.performance(period:.year,ending:anchor,calendar:calendar)
        XCTAssertEqual(year.count,2); XCTAssertEqual(year.map(\.flights),[2,2])
        XCTAssertTrue(year.allSatisfy { $0.score == 80 })
        book.reviews = [PilotRankReview(date:date(9,25),flightNumber:30,score:70,crashes:2,closeShaves:2,turns:20,soars:5),PilotRankReview(date:date(10,15),flightNumber:60,score:95,crashes:0,closeShaves:4,turns:60,soars:30)]
        XCTAssertEqual(book.chartReviews(period:.month,ending:anchor,calendar:calendar).count,1)
        XCTAssertEqual(book.chartReviews(period:.days30,ending:anchor,calendar:calendar).count,2)
        let encoded = try JSONEncoder().encode(book)
        XCTAssertEqual(try JSONDecoder().decode(PilotLogbook.self,from:encoded),book)
    }
}


final class PodRaceIntensityTests: XCTestCase {
    func testCircuitPaceIsFasterAndBoostStillAddsSpeedWithoutChangingOtherFlights() {
        let physics = FlightPhysics(aircraft: .anakinPodracer)
        var normal = FlightState(), race = normal, boosted = normal
        for _ in 0..<1200 {
            physics.advance(&normal, input: FlightInput(throttle:1), wind:.zero, dt:FlightPhysics.step)
            physics.advance(&race, input: FlightInput(throttle:1), wind:.zero, dt:FlightPhysics.step, raceSpeedMultiplier:FlightLevel.boontaEve.podRaceSpeedMultiplier)
            physics.advance(&boosted, input: FlightInput(throttle:1,boost:true), wind:.zero, dt:FlightPhysics.step, raceSpeedMultiplier:FlightLevel.narShaddaa.podRaceSpeedMultiplier)
        }
        XCTAssertEqual(race.airspeed / normal.airspeed, 2.0, accuracy:0.01)
        XCTAssertGreaterThan(boosted.airspeed, race.airspeed * 1.3)
        XCTAssertEqual(race.position.y,430,accuracy:0.001)
        XCTAssertEqual(FlightLevel.freeRoam.podRaceSpeedMultiplier,1)
        var previous: Float = 1
        for level in FlightLevel.allCases.filter(\.isPodRace) {
            XCTAssertGreaterThan(level.podRaceSpeedMultiplier,previous)
            previous = level.podRaceSpeedMultiplier
        }
        let plane = FlightPhysics(aircraft:.xwing)
        var a = FlightState(), b = a
        plane.advance(&a,input:FlightInput(throttle:1),wind:.zero,dt:1/60)
        plane.advance(&b,input:FlightInput(throttle:1),wind:.zero,dt:1/60,raceSpeedMultiplier:1.26)
        XCTAssertEqual(a.position,b.position)
    }

    func testExtremeSpeedPodCannotOvertakeItsOwnShots() {
        for heading: Float in [0,.pi/2,.pi] {
            var state = FlightState()
            state.heading = heading
            state.velocity = state.forward * 1400
            state.airspeed = 1400
            var weapons = WeaponSystem()
            let bolts = weapons.update(state:state,aircraft:.voltwingPodracer,firing:true,dt:1/120)
            XCTAssertEqual(bolts.count,1)
            XCTAssertEqual(simd_dot(bolts[0].velocity-state.velocity,state.forward),AircraftType.voltwingPodracer.weaponSpeed,accuracy:0.01)
            XCTAssertGreaterThan(simd_dot(bolts[0].position-(state.position+state.velocity/120),state.forward),0)
        }
    }

    func testChargedDriftReleasesCornerExitTurboAndStraightSkidCannotFarmIt() {
        let physics = FlightPhysics(aircraft:.anakinPodracer)
        var drift = FlightState(), straight = FlightState()
        drift.airspeed = 600; drift.velocity = [0,0,-600]
        straight = drift
        for _ in 0..<180 {
            physics.advance(&drift,input:FlightInput(roll:0.5,throttle:1,skid:true),wind:.zero,dt:1/120,raceSpeedMultiplier:2.4)
            physics.advance(&straight,input:FlightInput(throttle:1,skid:true),wind:.zero,dt:1/120,raceSpeedMultiplier:2.4)
        }
        XCTAssertGreaterThan(drift.driftCharge,0.9)
        XCTAssertEqual(straight.driftCharge,0)
        physics.advance(&drift,input:FlightInput(throttle:1),wind:.zero,dt:1/120,raceSpeedMultiplier:2.4)
        physics.advance(&straight,input:FlightInput(throttle:1),wind:.zero,dt:1/120,raceSpeedMultiplier:2.4)
        XCTAssertGreaterThan(drift.driftBoostRemaining,1)
        XCTAssertEqual(straight.driftBoostRemaining,0)
        for _ in 0..<60 { physics.advance(&drift,input:FlightInput(throttle:1),wind:.zero,dt:1/120,raceSpeedMultiplier:2.4) }
        XCTAssertGreaterThan(drift.airspeed,straight.airspeed*1.15)
        for _ in 0..<240 { physics.advance(&drift,input:FlightInput(throttle:1),wind:.zero,dt:1/120,raceSpeedMultiplier:2.4) }
        XCTAssertEqual(drift.driftBoostRemaining,0)
    }

    func testDraftBuildsBehindRivalThenFadesWhenLeavingTheSlipstream() {
        var race = PodRaceManager(terrain:TerrainGenerator(level:.boontaEve),aircraft:.anakinPodracer)
        for _ in 0..<180 {
            let target = race.opponents[0], t = race.circuit.tangent(at:target.progress)
            _ = race.advance(position:target.position-t*100,requestedBoost:false,dt:1/120)
        }
        XCTAssertGreaterThan(race.draftStrength,0.85)
        for _ in 0..<240 { _ = race.advance(position:[100000,204,100000],requestedBoost:false,dt:1/120) }
        XCTAssertLessThan(race.draftStrength,0.01)
        let physics = FlightPhysics(aircraft:.anakinPodracer)
        var a = FlightState(), b = a
        for _ in 0..<600 {
            physics.advance(&a,input:FlightInput(throttle:1),wind:.zero,dt:1/120,raceSpeedMultiplier:2.4)
            physics.advance(&b,input:FlightInput(throttle:1),wind:.zero,dt:1/120,raceSpeedMultiplier:2.4,draftStrength:1)
        }
        XCTAssertEqual(b.airspeed/a.airspeed,1.12,accuracy:0.01)
    }

    func testPodGustsStaySmallAndConsistentAcrossPhysicsRates() {
        let physics = FlightPhysics(aircraft:.anakinPodracer)
        var results: [FlightState] = []
        for dt: Float in [1/60,1/120] {
            var state = FlightState()
            for _ in 0..<Int(10/dt) {
                physics.advance(&state,input:FlightInput(throttle:1),wind:[20,0,10],dt:dt,raceSpeedMultiplier:1.26)
            }
            results.append(state)
            XCTAssertLessThan(abs(state.velocity.x),2)
        }
        XCTAssertEqual(results[0].velocity.x,results[1].velocity.x,accuracy:0.01)
        XCTAssertEqual(results[0].position.x,results[1].position.x,accuracy:0.1)
    }

    func testAllSixPodsCanCompleteAllEightCircuitsAtFullThrottle() {
        for level in FlightLevel.allCases.filter(\.isPodRace) {
            let terrain = TerrainGenerator(level:level), circuit = RaceCircuit(level:level)
            for aircraft in AircraftType.allCases.filter(\.isPodracer) {
                let physics = FlightPhysics(aircraft:aircraft)
                var state = FlightState()
                state.position = circuit.point(at:0)
                state.airspeed = aircraft.cruiseSpeed
                state.velocity = circuit.tangent(at:0) * state.airspeed
                state.heading = atan2(state.velocity.x,-state.velocity.z)
                var gates = CheckpointSystem(terrain:terrain,aircraft:aircraft)
                var worst: Float = 0
                var minimumClearance: Float = .greatestFiniteMagnitude
                for step in 0..<24000 {
                    let d = circuit.projection(state.position).distance
                    let target = circuit.point(at:d + max(150,min(240,state.airspeed * 0.22)))
                    let desired = atan2(target.x-state.position.x,-(target.z-state.position.z))
                    let error = atan2(sin(desired-state.heading),cos(desired-state.heading))
                    let old = state.position
                    physics.advance(&state,input:FlightInput(roll:clamp(error*3.2,-1,1),throttle:1,boost:true,skid:abs(error)>0.42),wind:.zero,dt:1/60,raceSpeedMultiplier:level.podRaceSpeedMultiplier)
                    _ = gates.advance(from:old,to:state.position)
                    worst = max(worst,circuit.projection(state.position).offset)
                    if step.isMultiple(of:30) {
                        for probe in aircraft.collisionProbes {
                            let point = state.position + state.orientation.act(probe)
                            minimumClearance = min(minimumClearance,point.y-terrain.surfaceHeight(x:point.x,z:point.z))
                        }
                    }
                    if gates.complete { break }
                }
                XCTAssertEqual(gates.nextIndex,level.totalCheckpoints,"\(level.name) / \(aircraft.name)")
                XCTAssertLessThan(worst,level.valleyWidth * 0.48,"\(level.name) / \(aircraft.name): \(worst) m")
                XCTAssertEqual(state.position.y,204,accuracy:0.001)
                XCTAssertGreaterThan(minimumClearance,1,"\(level.name) / \(aircraft.name): ground clearance \(minimumClearance)")
            }
        }
    }

    func testFastestAndWidestPodsClearSweptTerrainOnNarrowestCircuit() {
        let level = FlightLevel.narShaddaa
        let terrain = TerrainGenerator(level:level), circuit = RaceCircuit(level:level)
        for aircraft in [AircraftType.voltwingPodracer,.nevaKeePodracer] {
            let physics = FlightPhysics(aircraft:aircraft)
            let collision = CollisionSystem(terrain:terrain,aircraft:aircraft)
            var state = FlightState()
            state.position = circuit.point(at:0)
            state.airspeed = aircraft.cruiseSpeed
            state.velocity = circuit.tangent(at:0)*state.airspeed
            state.heading = atan2(state.velocity.x,-state.velocity.z)
            var gates = CheckpointSystem(terrain:terrain,aircraft:aircraft)
            for _ in 0..<10000 {
                let d = circuit.projection(state.position).distance
                let target = circuit.point(at:d+max(150,min(240,state.airspeed*0.22)))
                let desired = atan2(target.x-state.position.x,-(target.z-state.position.z))
                let error = atan2(sin(desired-state.heading),cos(desired-state.heading))
                let old = state
                physics.advance(&state,input:FlightInput(roll:clamp(error*3.2,-1,1),throttle:1,boost:true,skid:abs(error)>0.42),wind:.zero,dt:1/60,raceSpeedMultiplier:level.podRaceSpeedMultiplier)
                if collision.impact(from:old,to:state) != nil { XCTFail("Terrain impact: \(aircraft.name), gate \(gates.nextIndex)"); break }
                _ = gates.advance(from:old.position,to:state.position)
                if gates.nextIndex >= level.gateCount { break }
            }
            XCTAssertGreaterThanOrEqual(gates.nextIndex,level.gateCount,aircraft.name)
        }
    }

    func testRivalsRaceThreeLapsUseBoostAndStayOnAllCourses() {
        for level in FlightLevel.allCases.filter(\.isPodRace) {
            var race = PodRaceManager(terrain:TerrainGenerator(level:level),aircraft:.anakinPodracer)
            let originals = race.opponents
            var boosted = false, changedLane = false
            for _ in 0..<20000 {
                _ = race.advance(position:[100000,204,100000],requestedBoost:false,dt:1/30)
                boosted = boosted || race.opponents.contains( where: { $0.boosting })
                changedLane = changedLane || zip(originals,race.opponents).contains { abs($0.lateralOffset-$1.lateralOffset)>8 }
                if race.opponents.allSatisfy({$0.progress >= race.circuit.length*3}) { break }
            }
            XCTAssertTrue(boosted,level.name)
            XCTAssertTrue(changedLane,level.name)
            XCTAssertTrue(race.opponents.allSatisfy { $0.active && $0.finished },level.name)
            XCTAssertTrue(race.opponents.allSatisfy { $0.position.x.isFinite && abs($0.lateralOffset) < level.valleyWidth*0.68 },level.name)
        }
        XCTAssertTrue(PodRaceManager.rivalTypes.allSatisfy(\.isPodracer))
    }

    func testRivalMovesInToBumpAndContactHasRecoveryAcrossPhysicsRates() {
        for dt: Float in [1/30,1/60,1/120] {
            var race = PodRaceManager(terrain:TerrainGenerator(level:.narShaddaa),aircraft:.anakinPodracer)
            var player = FlightState()
            for _ in 0..<Int(8/dt) {
                let rival = race.opponents[0], t = race.circuit.tangent(at:rival.progress)
                player.position = race.circuit.point(at:rival.progress)
                player.heading = atan2(t.x,-t.z)
                player.velocity = t*320
                player.airspeed = 320
                _ = race.advance(position:player.position,requestedBoost:false,dt:dt)
                race.resolveContact(player:&player,dt:dt)
                if race.contacts>0 { break }
            }
            XCTAssertGreaterThan(race.contacts,0,"dt \(dt)")
            XCTAssertNotNil(race.proximityWarning(for:player))
            let count = race.contacts, velocity = player.velocity
            for _ in 0..<60 { race.resolveContact(player:&player,dt:dt) }
            XCTAssertEqual(race.contacts,count)
            XCTAssertEqual(player.velocity,velocity)
            XCTAssertGreaterThan(simd_dot(player.velocity,SIMD3<Float>(sin(player.heading),0,-cos(player.heading))),280)
        }
    }

    func testContactIsHeadingIndependentAndVerticallySeparatedCraftCannotCollide() {
        var forwardSpeeds: [Float] = []
        for heading: Float in [0,.pi/2,.pi,-.pi/2] {
            var race = PodRaceManager(terrain:TerrainGenerator(level:.boontaEve),aircraft:.anakinPodracer)
            var player = FlightState()
            player.position = race.opponents[0].position
            player.heading = heading
            let forward = SIMD3<Float>(sin(heading),0,-cos(heading))
            player.velocity = forward*300
            player.airspeed = 300
            race.resolveContact(player:&player,dt:FlightPhysics.step)
            forwardSpeeds.append(simd_dot(player.velocity,forward))
            XCTAssertEqual(race.contacts,1)
        }
        for speed in forwardSpeeds { XCTAssertEqual(speed,294,accuracy:0.01) }
        var race = PodRaceManager(terrain:TerrainGenerator(level:.boontaEve),aircraft:.anakinPodracer)
        var high = FlightState()
        high.position = race.opponents[0].position + SIMD3<Float>(0,30,0)
        race.resolveContact(player:&high,dt:FlightPhysics.step)
        XCTAssertEqual(race.contacts,0)
    }

    func testEmptyBoostRechargesBeforeRestartingInsteadOfFlickeringEveryStep() {
        var race = PodRaceManager(terrain:TerrainGenerator(level:.boontaEve),aircraft:.anakinPodracer)
        let far = SIMD3<Float>(100000,204,100000)
        for _ in 0..<440 { _ = race.advance(position:far,requestedBoost:true,dt:1/120) }
        XCTAssertFalse(race.isBoosting)
        XCTAssertLessThan(race.boostCharge,2)
        for _ in 0..<240 {
            XCTAssertFalse(race.advance(position:far,requestedBoost:true,dt:1/120))
        }
        for _ in 0..<150 { _ = race.advance(position:far,requestedBoost:true,dt:1/120) }
        XCTAssertTrue(race.isBoosting)
        _ = race.advance(position:far,requestedBoost:false,dt:1/120)
        XCTAssertFalse(race.isBoosting)
    }

    func testSweptShotsAreConsumedAndRivalArmourNeedsFourPodHits() {
        var race = PodRaceManager(terrain:TerrainGenerator(level:.boontaEve),aircraft:.anakinPodracer)
        let target = race.opponents[0].position
        let velocity = SIMD3<Float>(0,0,-10000)
        let bolt = PlayerBolt(position:target + SIMD3<Float>(0,0,-40),velocity:velocity,damage:14)
        for hit in 1...4 {
            XCTAssertEqual(race.resolvePlayerFire([bolt],dt:0.01),[0])
            XCTAssertEqual(race.opponents[0].active,hit<4)
        }
        XCTAssertEqual(race.opponents.filter { !$0.active }.count,1)
        XCTAssertTrue(race.resolvePlayerFire([bolt],dt:0.01).isEmpty)
        race.reset(aircraft:.anakinPodracer)
        XCTAssertTrue(race.opponents.allSatisfy { $0.active && $0.armour == 56 })
        XCTAssertEqual(race.contacts,0)
        XCTAssertEqual(race.boostCharge,100)
    }
}

final class PodSteeringSmoothnessTests: XCTestCase {
    private let pace: Float = 2.4

    private func readyState(for aircraft: AircraftType) -> FlightState {
        var state = FlightState()
        state.airspeed = aircraft.cruiseSpeed * pace * 1.34
        state.velocity = [0, 0, -state.airspeed]
        return state
    }

    private func advance(_ state: inout FlightState, physics: FlightPhysics,
                         roll: Float, seconds: Float, dt: Float, skid: Bool = false) {
        for _ in 0..<Int((seconds / dt).rounded()) {
            physics.advance(&state, input: FlightInput(roll: roll, throttle: 1, skid: skid),
                            wind: .zero, dt: dt, raceSpeedMultiplier: pace)
        }
    }

    func testDigitalTurnBuildsSmoothlyWithoutLosingFullSteeringAuthority() {
        for aircraft in AircraftType.allCases.filter(\.isPodracer) {
            let physics = FlightPhysics(aircraft: aircraft)
            let dt: Float = 1 / 120
            var state = readyState(for: aircraft)
            physics.advance(&state, input: FlightInput(roll: 1, throttle: 1), wind: .zero,
                            dt: dt, raceSpeedMultiplier: pace)
            let initialRate = state.podTurnRate
            let initialSteering = state.podSteering
            advance(&state, physics: physics, roll: 1, seconds: 0.5, dt: dt)
            XCTAssertGreaterThan(initialRate, 0, aircraft.name)
            XCTAssertLessThan(initialRate, state.podTurnRate * 0.4, aircraft.name)
            XCTAssertGreaterThan(state.podTurnRate, 1, aircraft.name)
            XCTAssertLessThan(initialSteering, 0.4, aircraft.name)
            XCTAssertGreaterThan(state.podSteering, 0.98, aircraft.name)
        }
    }

    func testOppositeInputCountersteersPromptlyWithoutAnInstantDirectionFlip() {
        for dt: Float in [1 / 60, 1 / 120] {
            let physics = FlightPhysics(aircraft: .anakinPodracer)
            var state = readyState(for: .anakinPodracer)
            advance(&state, physics: physics, roll: 1, seconds: 0.5, dt: dt)
            let rightRate = state.podTurnRate
            physics.advance(&state, input: FlightInput(roll: -1, throttle: 1), wind: .zero,
                            dt: dt, raceSpeedMultiplier: pace)
            XCTAssertGreaterThan(state.podSteering, 0, "Countersteer snapped at \(dt) s")
            XCTAssertGreaterThan(state.podTurnRate, 0, "Turn direction snapped at \(dt) s")
            advance(&state, physics: physics, roll: -1, seconds: 0.2 - dt, dt: dt)
            XCTAssertLessThan(state.podSteering, -0.9, "Countersteer stayed sluggish at \(dt) s")
            XCTAssertLessThan(state.podTurnRate, -rightRate * 0.7, "Turn stayed sluggish at \(dt) s")
        }
    }

    func testReleasingSteeringRecentresQuicklyInsteadOfContinuingTheTurn() {
        for dt: Float in [1 / 60, 1 / 120] {
            let physics = FlightPhysics(aircraft: .nevaKeePodracer)
            var state = readyState(for: .nevaKeePodracer)
            advance(&state, physics: physics, roll: 1, seconds: 0.5, dt: dt)
            let heldRate = state.podTurnRate
            advance(&state, physics: physics, roll: 0, seconds: 0.25, dt: dt)
            XCTAssertLessThan(abs(state.podSteering), 0.03)
            XCTAssertLessThan(abs(state.podTurnRate), heldRate * 0.12)
            XCTAssertTrue(state.position.x.isFinite && state.position.z.isFinite)
        }
    }

    func testSmallAlternatingInputIsAttenuatedWhileDeliberateGentleTurnsRemainUsable() {
        let physics = FlightPhysics(aircraft: .rattsPodracer)
        let dt: Float = 1 / 120
        var jitter = readyState(for: .rattsPodracer)
        var gentle = jitter
        var jitterRateSquared: Float = 0
        var samples: Float = 0
        for step in 0..<120 {
            physics.advance(&jitter, input: FlightInput(roll: step.isMultiple(of: 2) ? 0.1 : -0.1, throttle: 1),
                            wind: .zero, dt: dt, raceSpeedMultiplier: pace)
            physics.advance(&gentle, input: FlightInput(roll: 0.1, throttle: 1),
                            wind: .zero, dt: dt, raceSpeedMultiplier: pace)
            if step >= 30 {
                jitterRateSquared += jitter.podTurnRate * jitter.podTurnRate
                samples += 1
            }
        }
        XCTAssertGreaterThan(gentle.podTurnRate, 0.05)
        XCTAssertLessThan(sqrt(jitterRateSquared / samples), gentle.podTurnRate * 0.25)
        XCTAssertLessThan(abs(jitter.heading), 0.01)
        XCTAssertGreaterThan(gentle.heading, 0.05)
    }

    func testSkidEngagementAndReleaseBlendTurnRateWithoutAngularSteps() {
        let physics = FlightPhysics(aircraft: .voltwingPodracer)
        let dt: Float = 1 / 120
        var state = readyState(for: .voltwingPodracer)
        advance(&state, physics: physics, roll: 1, seconds: 0.5, dt: dt)
        let normalRate = state.podTurnRate
        physics.advance(&state, input: FlightInput(roll: 1, throttle: 1, skid: true), wind: .zero,
                        dt: dt, raceSpeedMultiplier: pace)
        XCTAssertLessThan(state.podTurnRate - normalRate, normalRate * 0.25)
        advance(&state, physics: physics, roll: 1, seconds: 0.3, dt: dt, skid: true)
        let skidRate = state.podTurnRate
        XCTAssertGreaterThan(skidRate, normalRate * 1.4)
        physics.advance(&state, input: FlightInput(roll: 1, throttle: 1), wind: .zero,
                        dt: dt, raceSpeedMultiplier: pace)
        XCTAssertLessThan(skidRate - state.podTurnRate, skidRate * 0.25)
        advance(&state, physics: physics, roll: 1, seconds: 0.3, dt: dt)
        XCTAssertEqual(state.podTurnRate, normalRate, accuracy: normalRate * 0.05)
    }

    func testMixedSteeringTrajectoryIsConsistentAtSixtyAndOneTwentyHertz() {
        for aircraft in [AircraftType.anakinPodracer, .nevaKeePodracer] {
            let physics = FlightPhysics(aircraft: aircraft)
            let segments: [(seconds: Float, roll: Float, skid: Bool)] = [
                (0.5, 0.7, false), (0.4, 0.7, true), (0.3, -0.8, true),
                (0.4, 0, false), (0.5, -0.3, false), (0.4, 0, false)
            ]
            var results: [FlightState] = []
            for dt: Float in [1 / 60, 1 / 120] {
                var state = readyState(for: aircraft)
                for segment in segments {
                    advance(&state, physics: physics, roll: segment.roll,
                            seconds: segment.seconds, dt: dt, skid: segment.skid)
                }
                results.append(state)
            }
            let a = results[0], b = results[1]
            let angle = atan2(sin(a.heading - b.heading), cos(a.heading - b.heading))
            XCTAssertLessThan(abs(angle), 0.04, aircraft.name)
            XCTAssertLessThan(simd_distance(a.position, b.position), 12, aircraft.name)
            XCTAssertEqual(a.podSteering, b.podSteering, accuracy: 0.002)
            XCTAssertEqual(a.podTurnRate, b.podTurnRate, accuracy: 0.02)
        }
    }
}

final class SpaceTradingTests: XCTestCase {
    func testThirtyMaterialsAndExactRarityDistribution() {
        XCTAssertEqual(TradeMineral.all.count,30)
        XCTAssertEqual(Set(TradeMineral.all.map(\.id)).count,30)
        XCTAssertEqual(MineralRarity.allCases.map(\.weight).reduce(0,+),10000)
        var totals: [MineralRarity:Int] = [:]
        for roll in 0..<10000 { totals[TradeMineral.draw(tierRoll:roll,materialRoll:0).rarity,default:0] += 1 }
        for rarity in MineralRarity.allCases { XCTAssertEqual(totals[rarity],rarity.weight) }
        var reachable: Set<String> = []; var start = 0
        for rarity in MineralRarity.allCases {
            for index in 0..<8 { reachable.insert(TradeMineral.draw(tierRoll:start,materialRoll:index).id) }
            start += rarity.weight
        }
        XCTAssertEqual(reachable.count,30)
    }

    func testCargoCapacityAndSaleCannotPayTwice() {
        var wallet = FlightEconomy(); let iron = TradeMineral.all[0]
        XCTAssertEqual(wallet.collectMineral(iron,quantity:119),119)
        XCTAssertEqual(wallet.collectMineral(iron,quantity:8),1)
        XCTAssertEqual(wallet.collectMineral(iron,quantity:1),0)
        XCTAssertEqual(wallet.sellMineralCargo(at:.coruscant),0)
        XCTAssertTrue(wallet.openTradeRoute(SpaceTradeRoute.all[0]))
        XCTAssertEqual(wallet.sellMineralCargo(at:.coruscant),120*9)
        let paid = wallet.quarterCredits
        XCTAssertEqual(wallet.sellMineralCargo(at:.coruscant),0)
        XCTAssertEqual(wallet.quarterCredits,paid)
        XCTAssertEqual(wallet.trading?.used,0)
        XCTAssertEqual(wallet.trading?.discovered,[iron.id])
    }

    func testRouteCostAndDeliveryPremiumAreAtomic() {
        var wallet = FlightEconomy()
        XCTAssertFalse(wallet.openTradeRoute(SpaceTradeRoute.all[1]))
        wallet.earn(lowFlightPoints:3000)
        XCTAssertTrue(wallet.openTradeRoute(SpaceTradeRoute.all[1]))
        XCTAssertEqual(wallet.quarterCredits,0)
        XCTAssertFalse(wallet.openTradeRoute(SpaceTradeRoute.all[1]))
        XCTAssertTrue(wallet.beginTradeRun(SpaceTradeRoute.all[1],from:.tatooine))
        XCTAssertFalse(wallet.beginTradeRun(SpaceTradeRoute.all[1],from:.hoth))
        let quartz = TradeMineral.all.first { $0.id == "quartz" }!
        XCTAssertEqual(wallet.collectMineral(quartz,quantity:10),10)
        XCTAssertEqual(wallet.trading?.quote(at:.hoth),288)
        XCTAssertEqual(wallet.sellMineralCargo(at:.hoth),288)
        XCTAssertEqual(wallet.trading?.deliveries,1)
        XCTAssertNil(wallet.trading?.delivery)
        XCTAssertEqual(wallet.quarterCredits,1152)
    }

    func testTradingSurvivesSaveAndOldWalletMigrates() throws {
        var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:1234)
        _ = wallet.collectMineral(TradeMineral.all.last!,quantity:2)
        _ = wallet.openTradeRoute(SpaceTradeRoute.all[0])
        _ = wallet.beginTradeRun(SpaceTradeRoute.all[0],from:.coruscant)
        let data = try JSONEncoder().encode(wallet)
        let decoded = try JSONDecoder().decode(FlightEconomy.self,from:data)
        XCTAssertEqual(decoded,wallet)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        old.removeValue(forKey:"trading")
        let legacy = try JSONDecoder().decode(FlightEconomy.self,from:JSONSerialization.data(withJSONObject:old))
        XCTAssertNil(legacy.trading); XCTAssertEqual(legacy.quarterCredits,1234)
        var corrupt = SpaceTrading(); corrupt.cargo = ["unknown":1]
        XCTAssertFalse(corrupt.valid)
        corrupt = SpaceTrading(); corrupt.cargo = ["iron":121]
        XCTAssertFalse(corrupt.valid)
    }

    func testMiningFieldAndSweptLaserHitRecycleBoundedPool() {
        var field = HyperspaceManager(terrain:TerrainGenerator(seed:1,level:.freeRoam))
        var state = FlightState(); field.beginRelaxedSpace(state:&state,speed:100)
        _ = field.advance(state:&state,collisionRadius:5,dt:FlightPhysics.step)
        XCTAssertTrue(field.asteroids.isEmpty)
        _ = field.advance(state:&state,collisionRadius:5,dt:FlightPhysics.step,mining:true)
        XCTAssertEqual(field.asteroids.count,26)
        let target = field.asteroids[0]
        XCTAssertNotNil(field.miningTarget(from:state))
        let bolt = PlayerBolt(position:target.position+[0,0,-400],velocity:[0,0,-96000],damage:1)
        XCTAssertEqual(field.resolvePlayerFire([bolt],shipPosition:state.position),[0])
        XCTAssertEqual(field.salvageableHits,1)
        XCTAssertEqual(field.asteroids.count,26)
        _ = field.advance(state:&state,collisionRadius:5,dt:FlightPhysics.step,mining:false)
        XCTAssertTrue(field.asteroids.isEmpty)
    }

    func testMiningProgressTravelsInPlayerSave() throws {
        let name = "mining-save-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName:name))
        defer { defaults.removePersistentDomain(forName:name) }
        var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:3000)
        _ = wallet.openTradeRoute(SpaceTradeRoute.all[1]); _ = wallet.collectMineral(TradeMineral.all[12],quantity:7)
        wallet.save(to:defaults)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let archive = try PlayerSaveArchive.capture(defaults:defaults,creationsURL:root)
        let decoded = try JSONDecoder().decode(PlayerSaveArchive.self,from:archive.encoded())
        guard case .data(let data) = decoded.preferences[FlightEconomy.key] else { return XCTFail("Missing wallet") }
        let restored = try JSONDecoder().decode(FlightEconomy.self,from:data)
        XCTAssertEqual(restored,wallet)
    }
}

final class FlightPresentationSmoothnessTests: XCTestCase {
    func testRenderInterpolationHandlesHeadingWrapAndNeverMutatesSimulation() {
        var previous = FlightState(); previous.position = [0, 100, 0]; previous.heading = 2 * .pi - 0.02
        var current = previous; current.position.x = 6; current.heading = 0.02
        let rendered = FlightState.rendered(from: previous, to: current, fraction: 0.5)
        XCTAssertEqual(rendered.position.x, 3, accuracy: 0.0001)
        XCTAssertEqual(sin(rendered.heading), 0, accuracy: 0.0001)
        XCTAssertGreaterThan(cos(rendered.heading), 0.999)
        XCTAssertEqual(current.position.x, 6)
        current.position = [5000, 900, -10000]
        XCTAssertEqual(FlightState.rendered(from: previous, to: current, fraction: 0.2).position, current.position)
    }

    func testRudderEasingIsFrameRateIndependentAndReversesPromptly() {
        var results: [Float] = []
        for hz: Float in [30, 60, 120] {
            var state = FlightState()
            let first = state.easedRudder(1, dt: 1 / hz)
            XCTAssertGreaterThan(first, 0)
            XCTAssertLessThan(first, 0.5)
            for _ in 1..<Int(hz / 2) { _ = state.easedRudder(1, dt: 1 / hz) }
            results.append(state.rudderResponse)
            XCTAssertGreaterThan(state.rudderResponse, 0.99)
            for _ in 0..<Int(hz / 10) { _ = state.easedRudder(-1, dt: 1 / hz) }
            XCTAssertLessThan(state.rudderResponse, -0.5)
            for _ in 0..<Int(hz / 4) { _ = state.easedRudder(0, dt: 1 / hz) }
            XCTAssertLessThan(abs(state.rudderResponse), 0.005)
        }
        XCTAssertEqual(results[0], results[1], accuracy: 0.00001)
        XCTAssertEqual(results[1], results[2], accuracy: 0.00001)
    }

    func testDisplayMotionStaysUniformBetweenSimulationTicks() {
        // A 144 Hz screen has frames with no 120 Hz physics tick. Rendering must still advance.
        var previous = FlightState(); previous.position = .zero; previous.airspeed = 120
        var current = previous
        var accumulator: Float = 0
        var displayed: [Float] = []
        for _ in 0..<144 {
            accumulator += 1 / 144
            while accumulator >= FlightPhysics.step {
                previous = current; current.position.x += 120 * FlightPhysics.step
                accumulator -= FlightPhysics.step
            }
            displayed.append(FlightState.rendered(from: previous, to: current, fraction: accumulator / FlightPhysics.step).position.x)
        }
        for i in 2..<displayed.count {
            XCTAssertEqual(displayed[i] - displayed[i - 1], 120 / 144, accuracy: 0.0001)
        }
    }

    @MainActor
    func testChaseCameraMaintainsDistanceAtHighSpeedAndEasesTurns() {
        let terrain = TerrainGenerator(seed: 1, level: .freeRoam)
        let camera = CameraController()
        var state = FlightState(); state.position = [0, 1000, 0]
        camera.update(state: state, terrain: terrain, dt: 1 / 60, inSpace: true)
        let offset = camera.entity.position - state.position
        for _ in 0..<120 {
            state.position.z -= 800 / 60
            camera.update(state: state, terrain: terrain, dt: 1 / 60, inSpace: true)
            XCTAssertLessThan(simd_distance(camera.entity.position - state.position, offset), 0.01)
        }
        let oldOrientation = camera.entity.orientation
        state.heading = .pi
        camera.update(state: state, terrain: terrain, dt: 1 / 60, inSpace: true)
        let firstAngle = 2 * acos(min(1, abs(simd_dot(oldOrientation.vector, camera.entity.orientation.vector))))
        XCTAssertGreaterThan(firstAngle, 0.001)
        XCTAssertLessThan(firstAngle, 0.7)
        camera.reset()
        state.position = [20000, 2000, -5000]
        camera.update(state: state, terrain: terrain, dt: 1 / 60, inSpace: true)
        XCTAssertLessThan(simd_distance(camera.entity.position, state.position), 200)
    }
}

final class WidgetShortcutTests: XCTestCase {
    func testOnlyKnownLocalWidgetDestinationsAreAccepted() {
        for destination in [StarflightShortcut.hangar, .planner, .space] {
            XCTAssertEqual(StarflightShortcut(url: URL(string: "starflight://" + destination.rawValue)!), destination)
        }
        XCTAssertEqual(StarflightShortcut(url: URL(string: "STARFLIGHT://PLANNER/")!), .planner)
        for value in ["https://planner", "starflight://unknown", "starflight://space/delete", "starflight:///planner"] {
            XCTAssertNil(StarflightShortcut(url: URL(string: value)!))
        }
    }
}

final class LaunchFilmPlaybackTests: XCTestCase {
    func testBundledOpeningFilmIsPlayable() async throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "StarflightIntro", withExtension: "mp4"))
        let asset = AVURLAsset(url: url)
        let playable = try await asset.load(.isPlayable)
        let duration = try await asset.load(.duration)
        XCTAssertTrue(playable)
        XCTAssertGreaterThan(duration.seconds, 20)
        XCTAssertLessThan(duration.seconds, 25)
    }

    @MainActor
    func testMissingMovieDoesNotLeaveLaunchStuckOrCompleteTwice() {
        var completions = 0
        let player = LaunchFilmPlayback(url: URL(fileURLWithPath: "/nonexistent/starflight-test-\(UUID()).mp4"), muted: true) { completions += 1 }
        player.setActive(true)
        XCTAssertEqual(completions, 1)
        XCTAssertNil(player.player.currentItem)
        player.finishOnce(); player.setActive(true)
        XCTAssertEqual(completions, 1)
    }
    @MainActor
    func testSkippingBeforePlaybackAndInactiveStateAreSafe() {
        var completions = 0
        let player = LaunchFilmPlayback(url: URL(fileURLWithPath: "/unused.mp4"), muted: true) { completions += 1 }
        player.setActive(false)
        XCTAssertEqual(completions, 0)
        XCTAssertTrue(player.player.isMuted)
        player.finishOnce(); player.stop(); player.finishOnce()
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(player.player.rate, 0)
    }
}

final class ReviewPolishTests: XCTestCase {
    func testRequiredMarketConnectionChoosesCheapestRouteAndStopsOfferingItOnceOpen() {
        var hold = SpaceTrading()
        XCTAssertEqual(hold.requiredRoute(at: .tatooine)?.cost, 0)
        XCTAssertEqual(hold.requiredRoute(at: .coruscant)?.cost, 0)
        XCTAssertEqual(hold.requiredRoute(at: .hoth)?.id, "iceRun")
        XCTAssertEqual(hold.requiredRoute(at: .endor)?.id, "forestLink")
        hold.routes.insert("coreDesert")
        XCTAssertNil(hold.requiredRoute(at: .tatooine))
        XCTAssertNil(hold.requiredRoute(at: .coruscant))
        XCTAssertEqual(hold.requiredRoute(at: .hoth)?.cost, 750)
    }

    @MainActor
    func testCrashCameraEscapesAnEnclosingObstacleAndResetsForAnotherImpact() {
        let camera = CameraController()
        var state = FlightState(); state.position = [0,120,0]
        let blocked: (SIMD3<Float>) -> Bool = { abs($0.x) < 180 && abs($0.z) < 180 && $0.y < 600 }
        let terrain = TerrainGenerator(seed: 1, level: .alpine)
        camera.mode = .cockpit
        camera.update(state: state, terrain: terrain, dt: 1/60, inSpace: true)
        for frame in 0...120 {
            camera.updateCrash(state: state, elapsed: Float(frame)/30, groundHeight: { _,_ in 0 }, isObstructed: blocked)
            XCTAssertFalse(blocked(camera.entity.position))
            XCTAssertGreaterThan(camera.entity.position.y, 18)
            for value in 0..<4 { XCTAssertTrue(camera.entity.orientation.vector[value].isFinite) }
        }
        camera.reset()
        state.position = [10000,60,10000]
        camera.updateCrash(state: state, elapsed: 0, groundHeight: { _,_ in 0 }, isObstructed: { _ in false })
        XCTAssertLessThan(simd_distance(camera.entity.position,state.position), 400)
    }

    @MainActor
    func testCrashCameraStaysAboveSlopesAndClearOfActualPlanetObstacles() {
        for planet in SpacePlanet.allCases {
            let surface = PlanetExploration(planet: planet)
            guard let obstacle = surface.obstacles.first else { return XCTFail("Missing planet scenery") }
            var state = FlightState(); state.position = obstacle.center
            let camera = CameraController()
            for elapsed: Float in [0, 0.25, 1, 4] {
                camera.updateCrash(state: state, elapsed: elapsed,
                    groundHeight: { surface.groundHeight(x: $0,z: $1) },
                    isObstructed: { surface.hitsObstacle(at: $0,radius: 8) })
                XCTAssertFalse(surface.hitsObstacle(at: camera.entity.position,radius: 8), planet.name)
                XCTAssertGreaterThan(surface.clearance(at:camera.entity.position),18)
                XCTAssertTrue(camera.entity.orientation.vector.x.isFinite)
            }
        }
    }
}


final class FlightEnhancementTests: XCTestCase {
    func testEveryFlyingShipCanCompletePositiveAndNegativeLoopsWithoutReversing() {
        for ship in AircraftType.allCases where !ship.isPodracer {
            for sign: Float in [-1,1] {
                var state = FlightState(); state.position = [0,10000,0]
                state.velocity = [0,0,-ship.cruiseSpeed]; state.airspeed = ship.cruiseSpeed
                let physics = FlightPhysics(aircraft: ship)
                for _ in 0..<2400 {
                    physics.advance(&state, input: FlightInput(pitch: sign, throttle: 1), wind: .zero, dt: FlightPhysics.step)
                    XCTAssertTrue(state.position.y.isFinite, ship.name)
                    XCTAssertGreaterThanOrEqual(simd_dot(state.velocity,state.forward), -0.01, ship.name)
                }
                XCTAssertGreaterThan(state.pitch * sign, 2 * .pi, ship.name)
            }
        }
    }
    func testSpaceLoopIsSmoothAcrossVerticalAndInvertedFlight() {
        var state = FlightState(); let physics = FlightPhysics(aircraft: .xwing)
        for _ in 0..<1200 {
            let previous = state.forward
            physics.advanceSpace(&state,input:FlightInput(pitch:1),dt:FlightPhysics.step)
            XCTAssertGreaterThan(simd_dot(previous,state.forward),0.999)
        }
        XCTAssertGreaterThan(state.pitch,2 * .pi)
        XCTAssertGreaterThan(simd_dot(state.velocity,state.forward),state.airspeed * 0.9)
    }
    @MainActor
    func testChaseCameraOrientationRemainsFiniteThroughoutLoop() {
        let camera = CameraController(); let terrain = TerrainGenerator()
        var state = FlightState(); state.position.y = 5000
        for i in 0...360 {
            state.pitch = Float(i) * .pi / 180
            camera.update(state:state,terrain:terrain,dt:1/60,inSpace:true)
            XCTAssertTrue(camera.entity.orientation.vector.x.isFinite)
            XCTAssertTrue(camera.entity.orientation.vector.w.isFinite)
            XCTAssertGreaterThan(simd_length(camera.entity.position - state.position), 5)
        }
    }
    func testDroidHoldsAltitudeThroughNormalPhysics() {
        var state = FlightState(); state.position.y = 500
        var assist = DroidFlightAssist(); assist.engage(.altitude,state:state)
        state.position.y += 30; state.pitch = 0.12
        let physics = FlightPhysics()
        for _ in 0..<3600 {
            let input = assist.controls(state:state,target:nil)
            physics.advanceSpace(&state,input:FlightInput(pitch:input.y,roll:input.x),dt:FlightPhysics.step)
        }
        XCTAssertEqual(state.position.y,500,accuracy:8)
        XCTAssertFalse(assist.pilotOverride(axes: [0.01,0], yaw:0))
        XCTAssertTrue(assist.pilotOverride(axes: [0.5,0], yaw:0))
        XCTAssertEqual(assist.mode,.off)
        XCTAssertEqual(assist.controls(state:state,target:[500,500,0]),.zero)
    }
    func testDroidVoiceRecognisesAssistsAndOreWithoutConfusingEnemyScan() {
        XCTAssertEqual(DroidCommandParser.parse("Hey droid level my ship"),.levelShip)
        XCTAssertEqual(DroidCommandParser.parse("Hey droid hold altitude"),.holdAltitude)
        XCTAssertEqual(DroidCommandParser.parse("Hey droid follow my route"),.followRoute)
        XCTAssertEqual(DroidCommandParser.parse("Hey droid scan ore"),.scanOre)
        XCTAssertEqual(DroidCommandParser.parse("Hey droid scan for enemies"),.scan)
    }
    func testSurveyAndCollectedOreMatchTheSameAsteroid() throws {
        var state = FlightState(); var space = HyperspaceManager(terrain:TerrainGenerator(level:.freeRoam))
        space.beginRelaxedSpace(state:&state,speed:90)
        _ = space.advance(state:&state,collisionRadius:2,dt:FlightPhysics.step,mining:true)
        let scan = try XCTUnwrap(space.oreSurvey(from:state))
        let target = try XCTUnwrap(space.asteroids.first(where:{$0.id == scan.asteroidID}))
        let bolt = PlayerBolt(position:target.position,velocity:.zero,damage:20)
        _ = space.resolvePlayerFire([bolt],shipPosition:state.position)
        XCTAssertEqual(space.salvageableOre.first?.id,scan.mineral.id)
        XCTAssertEqual(space.salvageableHits,1)
        XCTAssertEqual(target.ore.id,target.ore.id)
    }
    func testAllRarityTiersAreReachableIncludingNewRareTiers() {
        var start = 0
        for rarity in MineralRarity.allCases {
            XCTAssertEqual(TradeMineral.draw(tierRoll:start,materialRoll:0).rarity,rarity)
            start += rarity.weight
        }
        XCTAssertEqual(start,MineralRarity.totalWeight)
    }
    func testShortcutIsDriveableAndStaysBetweenRequiredCheckpoints() {
        for level in FlightLevel.allCases where level.isPodRace {
            let terrain = TerrainGenerator(seed:level.seed,level:level), circuit = RaceCircuit(level:level)
            XCTAssertTrue(circuit.hasShortcut, level.name)
            let interval = circuit.length / Float(level.gateCount)
            XCTAssertGreaterThan(circuit.shortcutStart,0)
            XCTAssertLessThan(circuit.shortcutEnd,interval)
            for index in 0...40 {
                let point = circuit.shortcutPoint(Float(index)/40)
                XCTAssertLessThan(terrain.surfaceHeight(x:point.x,z:point.z),120,level.name)
            }
            let race = PodRaceManager(terrain:terrain,aircraft:.anakinPodracer)
            XCTAssertEqual(Set(race.pads.map(\.id)).count,race.pads.count)
        }
    }
}

final class FlightAdventureTests: XCTestCase {
    func testEveryFlyingShipHoldsBoundedBankWithoutRollingOver() {
        for ship in AircraftType.allCases where !ship.isPodracer {
            for direction:Float in [-1,1] {
                for space in [true,false] {
                    var state = FlightState(); state.position.y = 10000; state.airspeed = ship.cruiseSpeed; state.velocity = state.forward*ship.cruiseSpeed
                    let physics = FlightPhysics(aircraft:ship)
                    for _ in 0..<1200 {
                        let previousHeading = state.heading, previousRight = state.orientation.act(SIMD3<Float>(1,0,0))
                        if space { physics.advanceSpace(&state,input:FlightInput(roll:direction,throttle:1),dt:FlightPhysics.step) }
                        else { physics.advance(&state,input:FlightInput(roll:direction,throttle:1),wind:.zero,dt:FlightPhysics.step) }
                        XCTAssertLessThan(abs(atan2(sin(state.heading-previousHeading),cos(state.heading-previousHeading))),0.05,ship.name)
                        XCTAssertGreaterThan(simd_dot(previousRight,state.orientation.act(SIMD3<Float>(1,0,0))),0.995,ship.name)
                        XCTAssertTrue(state.position.y.isFinite)
                    }
                    XCTAssertGreaterThan(state.roll*direction,ship.maximumRoll*0.95,ship.name)
                    XCTAssertLessThanOrEqual(abs(state.roll),ship.maximumRoll+0.001,ship.name)
                }
            }
        }
    }
    func testReleasedBankLevelsSmoothlyAndAssistCanRecover() {
        var state = FlightState(); state.roll = 0.4
        let initial = state.roll, physics = FlightPhysics(aircraft:.xwing)
        for _ in 0..<1200 { physics.advanceSpace(&state,input:FlightInput(),dt:FlightPhysics.step) }
        XCTAssertLessThan(abs(atan2(sin(state.roll),cos(state.roll))),0.01)
        XCTAssertLessThan(abs(state.roll-initial),1)
        var assist = DroidFlightAssist(); state.roll = 12 * .pi+0.5; assist.engage(.level,state:state)
        let axes = assist.controls(state:state,target:nil)
        XCTAssertLessThan(axes.x,0); XCTAssertGreaterThan(axes.x,-0.71)
    }
    func testReplayIsBoundedInterpolatesFastFlightAndDropsPreviousWorld() throws {
        var replay = FlightReplayBuffer(), state = FlightState(); state.airspeed = 10000
        for i in 0...300 { state.position.x = Float(i)*1000; replay.record(state,time:Float(i)*0.1,context:"orbit") }
        XCTAssertLessThanOrEqual(replay.samples.count,151)
        XCTAssertLessThanOrEqual(replay.duration,15.01)
        let a = try XCTUnwrap(replay.state(at:0.5))
        XCTAssertEqual(a.position.x,225000,accuracy:600)
        state.position.x = 0; replay.record(state,time:30.1,context:"Hoth")
        XCTAssertEqual(replay.samples.count,1); XCTAssertEqual(replay.duration,0)
    }
    func testFastGhostInterpolatesAndOnlyFasterLapsReplaceRecord() throws {
        var state = FlightState(); state.airspeed = 10000
        let first = FlightPathSample(time:0,state:state)
        state.position.x = 1000
        let last = FlightPathSample(time:1,state:state)
        let ghost = LapGhost(key:"pod/track/clear",duration:1,frames:[first,last])
        XCTAssertEqual(try XCTUnwrap(ghost.state(at:0.5)).position.x,500,accuracy:0.01)
        var progress = FlightAdventureProgress()
        XCTAssertTrue(progress.saveLap(ghost)); XCTAssertFalse(progress.saveLap(ghost))
        var slower = ghost; slower.duration = 2; slower.frames[1].time = 2
        XCTAssertFalse(progress.saveLap(slower)); XCTAssertEqual(progress.bestLaps.count,1)
        slower.frames[0].position.x = .nan
        XCTAssertFalse(progress.saveLap(slower)); XCTAssertNil(ghost.state(at:2))
    }
    func testCareerAndScanRewardsCannotRepeatSamePromotionOrDiscovery() {
        var wallet = FlightEconomy()
        XCTAssertEqual(wallet.recordCareer(.courier),0)
        XCTAssertEqual(wallet.recordCareer(.courier),100)
        XCTAssertEqual(wallet.quarterCredits,400)
        for _ in 0..<4 { _ = wallet.recordCareer(.courier) }
        XCTAssertEqual(wallet.quarterCredits,1400)
        let material = TradeMineral.all[0]
        wallet.discoverOre(material); wallet.discoverOre(material)
        XCTAssertEqual(wallet.adventureProgress.career["explorer"],1)
        XCTAssertEqual(wallet.adventureProgress.scanned.count,1)
    }
    func testEmergencyRejectsFastOrBankedTouchdownAndPaysOnlyOnce() {
        var mission = EmergencyFlightContract(kind:.engine,target:.zero), state = FlightState()
        state.position = .zero; state.airspeed = 60
        for _ in 0..<40 { XCTAssertFalse(mission.advance(state:state,dt:0.1)) }
        state.airspeed = 0; state.velocity = .zero; state.roll = 0.5
        for _ in 0..<40 { XCTAssertFalse(mission.advance(state:state,dt:0.1)) }
        state.roll = 0
        for _ in 0..<31 { _ = mission.advance(state:state,dt:0.1) }
        XCTAssertTrue(mission.completed)
        var wallet = FlightEconomy()
        XCTAssertEqual(wallet.claimEmergency(mission),120)
        XCTAssertEqual(wallet.claimEmergency(mission),0)
        XCTAssertEqual(wallet.quarterCredits,480)
        var expired = EmergencyFlightContract(kind:.approach,target:[1000,0,0])
        _ = expired.advance(state:state,dt:91)
        XCTAssertTrue(expired.failed); XCTAssertEqual(wallet.claimEmergency(expired),0)
    }
    func testRoutesCareersAndGhostsSurviveValidatedCloudArchive() throws {
        let suite = "AdventureTests."+UUID().uuidString, defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        var wallet = FlightEconomy()
        let route = SavedFlightRoute(name:"Outer Rim loop",planets:["tatooine","hoth","coruscant"])
        XCTAssertTrue(wallet.saveRoute(route)); _ = wallet.recordCareer(.courier)
        wallet.discoverOre(TradeMineral.all[1])
        var state = FlightState(); var lap = LapGhostRecorder(); lap.begin(state:state,time:0)
        for i in 1...100 { state.position.z -= 5; lap.record(state:state,time:Float(i)*0.1) }
        let ghost = try XCTUnwrap(lap.finished(state:state,time:10.01,key:"test-pod/track/clear"))
        XCTAssertTrue(wallet.saveBestLap(ghost)); wallet.save(to:defaults)
        let archive = try PlayerSaveArchive.capture(defaults:defaults,creationsURL:URL(fileURLWithPath:"/tmp/nonexistent-"+UUID().uuidString))
        let decoded = try JSONDecoder().decode(PlayerSaveArchive.self,from:archive.encoded()).validated()
        guard case .data(let data) = decoded.preferences[FlightEconomy.key] else { return XCTFail("Missing wallet") }
        let restored = try JSONDecoder().decode(FlightEconomy.self,from:data)
        XCTAssertEqual(restored.adventureProgress.routes,[route])
        XCTAssertEqual(restored.adventureProgress.bestLaps,[ghost])
        XCTAssertEqual(restored.adventureProgress.career["courier"],1)
        XCTAssertEqual(restored.adventureProgress.scanned.count,1)
    }
    func testWeatherIsFiniteBoundedAndPersistsWithoutChangingSpacePhysics() {
        for weather in FlightWeather.allCases {
            for t in stride(from:Float(0),through:1000,by:0.17) { XCTAssertLessThanOrEqual(simd_length(weather.wind(at:t)),18) }
        }
        XCTAssertEqual(FlightWeather.clear.wind(at:12),.zero)
        let suite = "WeatherTests."+UUID().uuidString, defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        var settings = GameSettings(defaults:defaults); settings.weather = .whiteout; settings.showGhost = false; settings.save(defaults:defaults)
        XCTAssertEqual(GameSettings(defaults:defaults).weather,.whiteout)
        XCTAssertFalse(GameSettings(defaults:defaults).showGhost)
    }
    func testPodracerDoesNotBarrelRoll() {
        var state = FlightState(); let physics = FlightPhysics(aircraft:.anakinPodracer)
        for _ in 0..<1200 { physics.advance(&state,input:FlightInput(roll:1),wind:.zero,dt:FlightPhysics.step) }
        XCTAssertLessThan(abs(state.roll),2)
    }
}

final class StoryCampaignTests: XCTestCase {
    private let chapters: [[StoryEvent]] = [[.cityJob(.spaceportLink),.orbit(.coruscant)], [.mined(3),.sold(.tatooine,3)],
        [.scout(.hoth,0),.scout(.hoth,1),.scout(.hoth,2),.orbit(.hoth)], [.scout(.endor,0),.scout(.endor,1),.orbit(.endor)],
        [.bounty(.runaway),.orbit(.coruscant)], [.repaired(.engine)], [.route(.deathStar)]]
    func testCompleteCampaignPaysEachChapterOnceAndKeepsChosenEnding() {
        var wallet = FlightEconomy()
        wallet.chooseStoryEnding(.guardian); XCTAssertNil(wallet.campaignProgress.ending)
        for (index,events) in chapters.enumerated() {
            XCTAssertEqual(wallet.campaignProgress.current?.rawValue,index)
            XCTAssertNil(wallet.recordStory(events.last!))
            wallet.beginStory()
            for event in events { _ = wallet.recordStory(event) }
            XCTAssertEqual(wallet.campaignProgress.completed.count,index+1)
            let credits = wallet.quarterCredits
            XCTAssertNil(wallet.recordStory(events.last!)); XCTAssertEqual(wallet.quarterCredits,credits)
            XCTAssertTrue(wallet.campaignProgress.valid)
        }
        XCTAssertEqual(wallet.quarterCredits,2800*4)
        XCTAssertTrue(wallet.campaignProgress.finished); XCTAssertNil(wallet.campaignProgress.current)
        wallet.chooseStoryEnding(.guardian); wallet.chooseStoryEnding(.independent)
        XCTAssertEqual(wallet.campaignProgress.ending,.guardian)
        XCTAssertEqual(wallet.quarterCredits,2800*4)
    }
    func testCargoMustBeFreshAndDeliveredToCorrectPlanet() {
        var progress = StoryCampaignProgress(); progress.begin(); _ = progress.record(.cityJob(.spaceportLink)); _ = progress.record(.orbit(.coruscant)); progress.begin()
        XCTAssertNil(progress.record(.sold(.tatooine,3))); XCTAssertEqual(progress.delivered,0)
        XCTAssertNil(progress.record(.mined(-1))); XCTAssertEqual(progress.mined,0)
        _ = progress.record(.mined(2)); progress.begin(); XCTAssertEqual(progress.mined,2)
        _ = progress.record(.mined(1)); XCTAssertNil(progress.record(.sold(.hoth,3)))
        XCTAssertNil(progress.record(.sold(.tatooine,2)))
        XCTAssertEqual(progress.record(.sold(.tatooine,1)),.salvage)
    }
    func testScoutObjectivesRejectDuplicatesWrongWorldsAndPrematureDeparture() {
        var wallet = FlightEconomy()
        for events in chapters.prefix(2) { wallet.beginStory(); for event in events { _ = wallet.recordStory(event) } }
        wallet.beginStory()
        XCTAssertNil(wallet.recordStory(.scout(.endor,0)))
        _ = wallet.recordStory(.scout(.hoth,0)); _ = wallet.recordStory(.scout(.hoth,0))
        XCTAssertEqual(wallet.campaignProgress.scouts.count,1)
        _ = wallet.recordStory(.scout(.hoth,1)); XCTAssertNil(wallet.recordStory(.scout(.hoth,2))); XCTAssertEqual(wallet.recordStory(.orbit(.hoth)),.whiteout)
        wallet.beginStory(); XCTAssertNil(wallet.recordStory(.orbit(.endor)))
        _ = wallet.recordStory(.scout(.endor,0)); _ = wallet.recordStory(.scout(.endor,1))
        XCTAssertNil(wallet.recordStory(.orbit(.hoth)))
        XCTAssertEqual(wallet.recordStory(.orbit(.endor)),.canopy)
    }
    func testUnrelatedJobsRepairsAndRoutesDoNotCompleteChapter() {
        var wallet = FlightEconomy(); wallet.beginStory()
        XCTAssertNil(wallet.recordStory(.cityJob(.courierRun)))
        XCTAssertNil(wallet.recordStory(.bounty(.runaway)))
        for (index,events) in chapters.enumerated() {
            if index > 0 { wallet.beginStory() }
            XCTAssertNil(wallet.recordStory(.route(.alpine)))
            if wallet.campaignProgress.current == .lifeline { XCTAssertNil(wallet.recordStory(.repaired(.rescue))) }
            for event in events { _ = wallet.recordStory(event) }
        }
        XCTAssertTrue(wallet.campaignProgress.finished)
    }
    func testPartialCampaignAndRewardReceiptsSurviveCloudArchiveRoundTrip() throws {
        let suite = "StoryTests."+UUID().uuidString, defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        var wallet = FlightEconomy(); wallet.beginStory(); _ = wallet.recordStory(.cityJob(.spaceportLink)); _ = wallet.recordStory(.orbit(.coruscant)); wallet.beginStory()
        _ = wallet.recordStory(.mined(2)); wallet.save(to:defaults)
        let root = URL(fileURLWithPath:"/tmp/unused-story-"+UUID().uuidString)
        let archive = try PlayerSaveArchive.capture(defaults:defaults,creationsURL:root)
        let decoded = try JSONDecoder().decode(PlayerSaveArchive.self,from:archive.encoded()).validated()
        guard case .data(let data) = decoded.preferences[FlightEconomy.key] else { return XCTFail("Missing story wallet") }
        var restored = try JSONDecoder().decode(FlightEconomy.self,from:data)
        XCTAssertEqual(restored.campaignProgress.current,.salvage); XCTAssertEqual(restored.campaignProgress.mined,2)
        XCTAssertEqual(restored.quarterCredits,600)
        _ = restored.recordStory(.mined(1)); XCTAssertEqual(restored.recordStory(.sold(.tatooine,3)),.salvage)
        XCTAssertEqual(restored.quarterCredits,1600)
    }
    func testOlderWalletDoesNotRequireCampaignData() throws {
        var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:400)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(wallet)) as? [String:Any])
        json.removeValue(forKey:"story")
        let old = try JSONDecoder().decode(FlightEconomy.self,from:JSONSerialization.data(withJSONObject:json))
        XCTAssertEqual(old.quarterCredits,400); XCTAssertNil(old.story); XCTAssertEqual(old.campaignProgress.current,.signal)
    }
    func testInvalidChapterOrderAndPrematureEndingAreRejected() throws {
        for object: [String:Any] in [
            ["completed":["beacon.6"],"accepted":false,"mined":0,"delivered":0,"scouts":[]],
            ["completed":[],"accepted":false,"mined":0,"delivered":0,"scouts":[],"ending":"guardian"]] {
            let progress = try JSONDecoder().decode(StoryCampaignProgress.self,from:JSONSerialization.data(withJSONObject:object))
            XCTAssertFalse(progress.valid)
        }
    }
}

final class StoryBranchAndWeatherTests: XCTestCase {
    func testEndorArrivalAndChaseViewClearTheForestCanopy() {
        let surface = PlanetExploration(planet:.endor)
        XCTAssertGreaterThan(surface.clearance(at:surface.arrival),800)
        for ship in AircraftType.allCases where !ship.isPodracer {
            let view = surface.arrival + ship.chaseOffset
            XCTAssertFalse(surface.hitsObstacle(at:view,radius:20),ship.name)
            XCTAssertGreaterThan(surface.clearance(at:view),600,ship.name)
        }
    }
    func testCovertPlanChangesRealRequirementsAndCannotChangeMidFlight() {
        var p = StoryCampaignProgress(); p.selectApproach(.covert); p.begin(); p.selectApproach(.rescue)
        XCTAssertEqual(p.plan,.covert); XCTAssertNil(p.record(.orbit(.coruscant)))
        XCTAssertNil(p.record(.cityJob(.spaceportLink))); XCTAssertTrue(p.passengerSafe)
        XCTAssertEqual(p.record(.orbit(.coruscant)),.signal); p.begin()
        _ = p.record(.mined(3)); XCTAssertNil(p.record(.sold(.tatooine,4)))
        _ = p.record(.mined(1)); XCTAssertEqual(p.record(.sold(.tatooine,4)),.salvage); p.begin()
        _ = p.record(.scout(.hoth,0)); XCTAssertNil(p.record(.orbit(.hoth)))
        _ = p.record(.scout(.hoth,1)); XCTAssertEqual(p.record(.orbit(.hoth)),.whiteout)
        p.selectRelay(.silent); p.begin(); p.selectRelay(.broadcast); XCTAssertEqual(p.relay,.silent)
        for i in 0..<2 { _ = p.record(.scout(.endor,i)) }; XCTAssertNil(p.record(.orbit(.endor)))
        _ = p.record(.scout(.endor,2)); XCTAssertEqual(p.record(.orbit(.endor)),.canopy)
        p.begin(); XCTAssertNil(p.record(.orbit(.coruscant))); XCTAssertNil(p.record(.bounty(.runaway)))
        XCTAssertEqual(p.record(.orbit(.coruscant)),.shadow); XCTAssertTrue(p.valid)
        XCTAssertEqual(p.evidence.count,5)
    }
    func testMidChapterEvidenceAndChoicesSurviveSaveAndOldProgressMigrates() throws {
        var p = StoryCampaignProgress(); p.selectApproach(.covert); p.begin(); _ = p.record(.cityJob(.spaceportLink))
        var q = try JSONDecoder().decode(StoryCampaignProgress.self,from:JSONEncoder().encode(p))
        XCTAssertTrue(q.passengerSafe); XCTAssertEqual(q.plan,.covert); XCTAssertTrue(q.valid)
        XCTAssertEqual(q.record(.orbit(.coruscant)),.signal)
        let old = Data(#"{"completed":[],"accepted":true,"mined":0,"delivered":0,"scouts":[]}"#.utf8)
        let legacy = try JSONDecoder().decode(StoryCampaignProgress.self,from:old)
        XCTAssertEqual(legacy.plan,.rescue); XCTAssertTrue(legacy.valid)
        var migrated = legacy; migrated.selectApproach(.covert); XCTAssertEqual(migrated.plan,.covert)
        migrated.selectApproach(.rescue); XCTAssertEqual(migrated.plan,.covert)
        var defaultPlan = StoryCampaignProgress(); defaultPlan.begin(); defaultPlan.selectApproach(.covert)
        XCTAssertEqual(defaultPlan.plan,.rescue)
    }
    func testWeatherAudioCrossfadesAndMutesOutsideAtmosphereAtDifferentFrameRates() {
        var slow = WeatherSoundMix(), fast = WeatherSoundMix(), cockpit = WeatherSoundMix()
        for _ in 0..<60 { slow.advance(weather:.rain,active:true,cockpit:false,dt:1/30) }
        for _ in 0..<120 { fast.advance(weather:.rain,active:true,cockpit:false,dt:1/60); cockpit.advance(weather:.rain,active:true,cockpit:true,dt:1/60) }
        XCTAssertEqual(slow.rain,fast.rain,accuracy:0.0001); XCTAssertLessThan(cockpit.rain,fast.rain*0.5)
        for _ in 0..<240 { fast.advance(weather:.mist,active:true,cockpit:false,dt:1/60) }
        XCTAssertLessThan(fast.rain,0.001); XCTAssertGreaterThan(fast.mist,0.1)
        for _ in 0..<240 { fast.advance(weather:.mist,active:false,cockpit:false,dt:1/60) }
        XCTAssertLessThan(fast.mist,0.001)
        fast.advance(weather:.dust,active:true,cockpit:false,dt:.nan); XCTAssertTrue(fast.dust.isFinite)
    }
    @MainActor
    func testMistUsesFixedEntityPoolWithoutRegeneratingGeometry() {
        let renderer = FlightAdventureRenderer(), template = Entity()
        let weather = Array(renderer.root.children).last!, ids = weather.children.map(\.id)
        for i in 0..<60 { renderer.update(ghostState:nil,template:template,target:nil,weather:.mist,active:true,camera:[Float(i),0,0],cameraOrientation:simd_quatf(angle:0,axis:[0,1,0]),dt:1/60,reducedDetail:true) }
        XCTAssertTrue(weather.isEnabled); XCTAssertEqual(weather.children.map(\.id),ids)
        XCTAssertEqual(weather.children.filter(\.isEnabled).count,8) // 3 haze shells and 5 mist banks; no snow/rain particles.
        renderer.update(ghostState:nil,template:template,target:nil,weather:.mist,active:false,camera:.zero,cameraOrientation:simd_quatf(angle:0,axis:[0,1,0]),dt:0,reducedDetail:false)
        XCTAssertFalse(weather.isEnabled)
    }
}

final class StoryReplayTests: XCTestCase {
    private let events:[[StoryEvent]] = [[.cityJob(.spaceportLink),.orbit(.coruscant)], [.mined(3),.sold(.tatooine,3)],
        [.scout(.hoth,0),.scout(.hoth,1),.scout(.hoth,2),.orbit(.hoth)], [.scout(.endor,0),.scout(.endor,1),.orbit(.endor)],
        [.bounty(.runaway),.orbit(.coruscant)], [.repaired(.engine)], [.route(.deathStar)]]
    private func complete(_ chapters:Int,wallet:inout FlightEconomy) {
        for chapter in events.prefix(chapters) { wallet.beginStory(); for event in chapter { _ = wallet.recordStory(event) } }
    }
    func testCompletedStoryCanReplayWithDifferentChoicesWithoutRepeatingBonuses() {
        var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:2000); complete(7,wallet:&wallet); wallet.chooseStoryEnding(.guardian)
        let before = wallet, credits = wallet.quarterCredits
        wallet.restartStory()
        XCTAssertEqual(wallet.campaignProgress,StoryCampaignProgress()); XCTAssertEqual(wallet.quarterCredits,credits)
        var expected = before; expected.restartStory(); XCTAssertEqual(wallet,expected)
        wallet.chooseStoryApproach(.covert); XCTAssertEqual(wallet.campaignProgress.plan,.covert)
        wallet.chooseStoryApproach(.rescue); complete(7,wallet:&wallet); wallet.chooseStoryEnding(.independent)
        XCTAssertEqual(wallet.campaignProgress.ending,.independent); XCTAssertEqual(wallet.quarterCredits,credits)
        wallet.restartStory(); complete(7,wallet:&wallet); XCTAssertEqual(wallet.quarterCredits,credits)
    }
    func testPartialReplayKeepsAllNonStoryDataAndPaysOnlyNewChapterBonuses() throws {
        var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:1234); complete(1,wallet:&wallet)
        wallet.beginStory(); _ = wallet.recordStory(.mined(2))
        let old = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(wallet)) as? [String:Any])
        let credits = wallet.quarterCredits; wallet.restartStory()
        var new = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(wallet)) as? [String:Any]), rest = old
        for key in ["story","previousStoryRewards"] { new.removeValue(forKey:key); rest.removeValue(forKey:key) }
        XCTAssertEqual(NSDictionary(dictionary:new),NSDictionary(dictionary:rest))
        wallet.restartStory(); complete(2,wallet:&wallet)
        XCTAssertEqual(wallet.quarterCredits,credits+StoryChapter.salvage.reward*4)
        XCTAssertFalse(wallet.storyRewardAvailable(for:.signal)); XCTAssertTrue(wallet.storyRewardAvailable(for:.salvage))
    }
    func testReplayRewardLedgerSurvivesCloudArchiveAndLegacyWallets() throws {
        let suite = "StoryReplay."+UUID().uuidString, defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        var wallet = FlightEconomy(); complete(2,wallet:&wallet); wallet.restartStory(); wallet.chooseStoryApproach(.covert); wallet.save(to:defaults)
        let archive = try PlayerSaveArchive.capture(defaults:defaults,creationsURL:URL(fileURLWithPath:"/tmp/unused-replay-"+UUID().uuidString))
        let decoded = try JSONDecoder().decode(PlayerSaveArchive.self,from:archive.encoded()).validated()
        guard case .data(let data) = decoded.preferences[FlightEconomy.key] else { return XCTFail("Missing wallet") }
        let restored = try JSONDecoder().decode(FlightEconomy.self,from:data)
        XCTAssertEqual(wallet,restored); XCTAssertTrue(restored.validStoryRewards)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(wallet)) as? [String:Any])
        old.removeValue(forKey:"previousStoryRewards")
        let legacy = try JSONDecoder().decode(FlightEconomy.self,from:JSONSerialization.data(withJSONObject:old))
        XCTAssertTrue(legacy.validStoryRewards)
        old["previousStoryRewards"] = ["invented-chapter"]
        let invalid = try JSONDecoder().decode(FlightEconomy.self,from:JSONSerialization.data(withJSONObject:old))
        XCTAssertFalse(invalid.validStoryRewards)
    }
}

final class UniverseExplorationTests:XCTestCase {
    func testRealCatalogueContainsThreeThousandValidDistinctStarsAndKnownPositions() throws {
        XCTAssertEqual(StarCatalogue.all.count,3000); XCTAssertEqual(Set(StarCatalogue.all.map(\.hip)).count,3000)
        XCTAssertTrue(StarCatalogue.all.allSatisfy(\.valid))
        let sirius = try XCTUnwrap(StarCatalogue.star(32349)), polaris = try XCTUnwrap(StarCatalogue.star(11767))
        XCTAssertEqual(sirius.title,"Sirius"); XCTAssertEqual(sirius.raDegrees,101.28854,accuracy:0.001)
        XCTAssertEqual(sirius.distanceLY,8.6,accuracy:0.1); XCTAssertGreaterThan(polaris.decDegrees,89)
        XCTAssertGreaterThan(try XCTUnwrap(StarCatalogue.star(27989)).bv,1)
        XCTAssertLessThan(try XCTUnwrap(StarCatalogue.star(24436)).bv,0.1)
    }
    func testCatalogCoordinatesBrightnessAndObserverParallax() throws {
        let origin = CatalogStar(hip:1,name:nil,raDegrees:0,decDegrees:0,magnitude:2,parallaxMas:100,parallaxErrorMas:1,bv:0.4)
        XCTAssertEqual(origin.positionPC.x,0,accuracy:0.0001); XCTAssertEqual(origin.positionPC.z,-10,accuracy:0.0001)
        let star = try XCTUnwrap(StarCatalogue.star(32349))
        XCTAssertLessThan(star.apparentMagnitude(from:star.positionPC*0.9),star.magnitude-4.9)
        var flight = UniverseFlight(),state = FlightState()
        XCTAssertEqual(flight.observerPC(local:[0,0,260]),.zero)
        XCTAssertTrue(flight.begin(.star(star.hip),state:state))
        for _ in 0..<601 { _ = flight.advanceJump(state:&state,dt:1/120) }
        XCTAssertEqual(flight.galaxy,.milkyWay); XCTAssertEqual(flight.observerHIP,star.hip)
        XCTAssertGreaterThan(simd_dot(state.forward,SIMD3<Float>(simd_normalize(star.positionPC))),0.999)
        XCTAssertEqual(simd_distance(star.positionPC,flight.observerPC(local:state.position)),0.03,accuracy:0.00001)
        let oldDirection = simd_normalize(origin.positionPC)
        XCTAssertLessThan(simd_dot(oldDirection,simd_normalize(origin.positionPC-flight.observerPC(local:state.position))),0.999)
    }
    func testEveryGalaxyJumpTakesFiveActiveSecondsAndCancelRestoresDeparture() {
        var flight = UniverseFlight(),state = FlightState(); let original = state
        XCTAssertTrue(flight.begin(.galaxy(.andromeda),state:state))
        for _ in 0..<240 { XCTAssertNil(flight.advanceJump(state:&state,dt:1/120)) }
        XCTAssertEqual(flight.remaining,3,accuracy:0.01); XCTAssertEqual(flight.galaxy,.milkyWay)
        flight.cancel(state:&state); XCTAssertEqual(state.position,original.position); XCTAssertEqual(state.velocity,original.velocity)
        XCTAssertFalse(flight.jumping); XCTAssertFalse(flight.begin(.star(-1),state:state))
        for galaxy in Galaxy.allCases {
            XCTAssertTrue(flight.begin(.galaxy(galaxy),state:state)); XCTAssertFalse(flight.begin(.solarSystem,state:state))
            for _ in 0..<599 { XCTAssertNil(flight.advanceJump(state:&state,dt:1/120)) }
            var arrivals = 0
            for _ in 0..<4 { if flight.advanceJump(state:&state,dt:1/120) != nil { arrivals += 1 } }
            XCTAssertEqual(arrivals,1); XCTAssertEqual(flight.galaxy,galaxy); XCTAssertFalse(flight.jumping)
            XCTAssertEqual(state.velocity,.zero); XCTAssertEqual(state.airspeed,0); XCTAssertGreaterThan(simd_distance(state.position,galaxy.blackHole.center),galaxy.blackHole.influence)
        }
    }
    func testBlackHoleZonesPullAndFastHorizonCrossing() {
        let hole = BlackHoleField(center:.zero)
        XCTAssertEqual(hole.zone(at:[0,0,4000]),.clear); XCTAssertEqual(hole.zone(at:[0,0,1800]),.outer)
        XCTAssertEqual(hole.zone(at:[0,0,600]),.strong); XCTAssertEqual(hole.zone(at:[0,0,100]),.horizon)
        XCTAssertEqual(hole.acceleration(at:[0,0,4000]),.zero)
        XCTAssertGreaterThan(simd_length(hole.acceleration(at:[0,0,600])),simd_length(hole.acceleration(at:[0,0,1800])))
        XCTAssertLessThan(hole.acceleration(at:[0,0,1800]).z,0)
        XCTAssertTrue(hole.crossed(from:[0,0,1000],to:[0,0,-1000],radius:10))
        XCTAssertFalse(hole.crossed(from:[1000,0,1000],to:[1000,0,-1000],radius:10))
        XCTAssertEqual(hole.acceleration(at:.zero),.zero)
    }
    func testBlackHoleCanCaptureAnIdleShipAndReverseThrustEscapesOuterZone() {
        var flight = UniverseFlight(), state = FlightState(); let physics = FlightPhysics(aircraft:.kestrel)
        state.position = flight.blackHole!.center+[0,0,500]; state.velocity = .zero; var captured = false
        for _ in 0..<3600 {
            let previous = state.position; physics.advanceSpace(&state,input:FlightInput(throttle:0),dt:1/120)
            if flight.applyGravity(state:&state,from:previous,radius:10,dt:1/120) { captured = true; break }
        }
        XCTAssertTrue(captured)
        flight = UniverseFlight(); state = FlightState(); state.position = flight.blackHole!.center+[0,0,2900]; state.velocity = .zero
        for _ in 0..<7200 {
            let previous = state.position; physics.advanceSpace(&state,input:FlightInput(throttle:-1),dt:1/120)
            XCTAssertFalse(flight.applyGravity(state:&state,from:previous,radius:10,dt:1/120))
        }
        XCTAssertGreaterThan(simd_distance(state.position,flight.blackHole!.center),5000)
    }
    func testSignedThrottleStopsHoversAndReversesEveryFlyingShipSmoothly() {
        for ship in AircraftType.allCases where !ship.isPodracer {
            let physics = FlightPhysics(aircraft:ship); var state = FlightState(); state.position = [0,1000,0]
            state.velocity = [0,0,-ship.cruiseSpeed]
            for _ in 0..<1200 {
                let old = state.velocity; physics.advanceSpace(&state,input:FlightInput(throttle:-1),dt:1/120)
                XCTAssertLessThan(simd_length(state.velocity-old),max(8,ship.cruiseSpeed*0.05),ship.name)
            }
            XCTAssertLessThan(simd_dot(state.velocity,state.forward),-ship.cruiseSpeed,ship.name)
            XCTAssertGreaterThanOrEqual(state.airspeed,0); XCTAssertEqual(state.heading,0)
            for _ in 0..<1200 { physics.advanceSpace(&state,input:FlightInput(throttle:0),dt:1/120) }
            XCTAssertLessThan(simd_length(state.velocity),0.01); XCTAssertEqual(state.position.y,1000,accuracy:0.01)
            for _ in 0..<1200 { physics.advanceSpace(&state,input:FlightInput(throttle:1),dt:1/120) }
            XCTAssertGreaterThan(simd_dot(state.velocity,state.forward),ship.cruiseSpeed,ship.name)
        }
        XCTAssertEqual(DroidCommandParser.parse("Hey droid reverse throttle 50 percent"),.throttle(-50))
        XCTAssertEqual(DroidCommandParser.parse("Hey droid throttle minus fifty percent"),.throttle(-50))
    }
    func testRemoteGalaxiesDoNotUseInvisibleHomePlanetCollisionsOrReturnPortal() {
        let terrain = TerrainGenerator(seed:FlightLevel.freeRoam.seed,level:.freeRoam)
        var manager = HyperspaceManager(terrain:terrain),state = FlightState()
        manager.beginRelaxedSpace(state:&state,speed:100); state.position = SpacePlanet.tatooine.position
        XCTAssertEqual(manager.advance(state:&state,collisionRadius:10,dt:1/120,planetAccess:false),.none)
        state.position = manager.returnPortal
        XCTAssertEqual(manager.advance(state:&state,collisionRadius:10,dt:1/120,planetAccess:false),.none)
        XCTAssertEqual(manager.zone,.asteroidField)
        state.position = SpacePlanet.tatooine.position
        XCTAssertEqual(manager.advance(state:&state,collisionRadius:10,dt:1/120,planetAccess:true),.planetImpact(.tatooine))
    }
    func testSolarFlybyHasEightPlanetsSunMoonAndSweptCollision() {
        XCTAssertEqual(SolarBody.all.count,10); XCTAssertEqual(Set(SolarBody.all.map(\.name)).count,10)
        XCTAssertEqual(SolarBody.impact(from:[-1400,0,0],to:[-1400,0,-2000],radius:5)?.name,"Earth")
        var flight = UniverseFlight(),state = FlightState(); _ = flight.begin(.solarSystem,state:state)
        for _ in 0..<601 { _ = flight.advanceJump(state:&state,dt:1/120) }
        XCTAssertEqual(flight.sector,.solarSystem); XCTAssertNil(flight.blackHole); XCTAssertFalse(flight.homePlanets)
    }
    func testUniverseVisitsSurviveCloudWalletWithoutSpendingCredits() throws {
        var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:1000); let credits = wallet.quarterCredits
        wallet.recordUniverseVisit(.andromeda,star:nil); wallet.recordUniverseVisit(.milkyWay,star:32349)
        let restored = try JSONDecoder().decode(FlightEconomy.self,from:JSONEncoder().encode(wallet))
        XCTAssertEqual(restored.adventureProgress.visitedGalaxies,["andromeda","milkyWay"])
        XCTAssertEqual(restored.adventureProgress.visitedStars,[32349]); XCTAssertEqual(restored.quarterCredits,credits); XCTAssertTrue(restored.adventureProgress.valid)
    }
    @MainActor
    func testCatalogueUsesThreeReusableMeshBatchesWithoutEntityChurn() throws {
        let renderer = UniverseRenderer(),camera = PerspectiveCamera(); var state = FlightState(); let flight = UniverseFlight()
        let sky = try XCTUnwrap(renderer.root.children.first), ids = sky.children.map(\.id)
        XCTAssertEqual(ids.count,3)
        let meshes = sky.children.compactMap { ($0 as? ModelEntity)?.model?.mesh }
        for _ in 0..<20 { state.position.x += 100; renderer.update(flight:flight,active:true,camera:camera,state:state,dt:0.12,reduced:false,target:nil) }
        XCTAssertEqual(sky.children.map(\.id),ids)
        XCTAssertEqual(meshes.compactMap(\.lowLevelMesh).reduce(0) { $0+$1.parts[0].indexCount },3000*6)
        renderer.update(flight:flight,active:true,camera:camera,state:state,dt:0.3,reduced:true,target:nil)
        XCTAssertEqual(meshes.compactMap(\.lowLevelMesh).reduce(0) { $0+$1.parts[0].indexCount },1000*6)
        XCTAssertEqual(sky.children.map(\.id),ids)
    }
}

final class PodBankDirectionTests: XCTestCase {
    func testPodLeansIntoBothTurnsAndSkids() {
        for ship in AircraftType.allCases where ship.isPodracer {
            for direction: Float in [-1, 1] {
                for skid in [false, true] {
                    var state = FlightState()
                    let physics = FlightPhysics(aircraft: ship)
                    for _ in 0..<60 { physics.advance(&state, input: FlightInput(roll: direction, throttle: 1, skid: skid), wind: .zero, dt: 1/120, raceSpeedMultiplier: 2) }
                    XCTAssertGreaterThan(state.roll * direction, 0)
                    XCTAssertLessThan(state.orientation.act([1,0,0]).y * direction, 0, ship.name)
                }
            }
        }
    }
}

final class AvatarEconomyTests: XCTestCase {
    func testAccessoryPurchaseIsPaidOnceAndSurvivesSave() throws {
        var wallet = FlightEconomy()
        XCTAssertFalse(wallet.buyAccessory(.headset))
        wallet.earn(lowFlightPoints: 4000)
        let before = wallet.quarterCredits
        XCTAssertTrue(wallet.buyAccessory(.headset))
        XCTAssertEqual(wallet.quarterCredits, before - AvatarAccessory.headset.price * 4)
        XCTAssertFalse(wallet.buyAccessory(.headset))
        wallet.equipAccessory(.starCrown)
        XCTAssertEqual(wallet.profile?.equipped, .headset)
        wallet.editProfile(name: "  Test pilot  ", suit: "Violet", species: "Droid")
        let restored = try JSONDecoder().decode(FlightEconomy.self, from: JSONEncoder().encode(wallet))
        XCTAssertEqual(restored, wallet); XCTAssertEqual(restored.profile?.name, "Test pilot")
        XCTAssertTrue(restored.profile?.valid ?? false)
    }
    func testAccessoryPrizesGiveNewItemsThenCreditFallback() {
        var wallet = FlightEconomy(), rng = SystemRandomNumberGenerator()
        for expected in 1...AvatarAccessory.allCases.count {
            _ = wallet.awardAccessory(rng: &rng)
            XCTAssertEqual(wallet.profile?.owned.count, expected)
        }
        let before = wallet.quarterCredits
        XCTAssertTrue(wallet.awardAccessory(rng: &rng).contains("250 credits"))
        XCTAssertEqual(wallet.quarterCredits, before + 1000)
        XCTAssertTrue(DailyPrize.allCases.contains(.avatarAccessory))
    }
}

final class SolarSurfaceExplorationTests: XCTestCase {
    func testEveryPlanetEntryHasSafeSpawnAndReturnToOrbit() {
        for body in SolarBody.all where body.name != "Sun" {
            var flight = UniverseFlight(), state = FlightState()
            XCTAssertFalse(flight.begin(.surface(body.name),state:state))
            XCTAssertTrue(flight.begin(.solarSystem,state:state))
            for _ in 0..<601 { _ = flight.advanceJump(state:&state,dt:1/120) }
            XCTAssertTrue(flight.begin(.surface(body.name),state:state))
            for _ in 0..<601 { _ = flight.advanceJump(state:&state,dt:1/120) }
            XCTAssertEqual(flight.surfaceBody?.name,body.name)
            XCTAssertFalse(SolarLandscape(body:body).impact(from:state.position,to:state.position,radius:30))
            XCTAssertEqual(state.velocity,.zero); XCTAssertNil(flight.blackHole)
            XCTAssertTrue(flight.begin(.solarSystem,state:state))
            for _ in 0..<601 { _ = flight.advanceJump(state:&state,dt:1/120) }
            XCTAssertNil(flight.surfaceBody); XCTAssertEqual(flight.sector,.solarSystem)
        }
    }
    func testSunEntryRejectedAndCancelledJumpKeepsSurface() throws {
        var flight = UniverseFlight(), state = FlightState()
        XCTAssertTrue(flight.begin(.solarSystem,state:state))
        for _ in 0..<601 { _ = flight.advanceJump(state:&state,dt:1/120) }
        XCTAssertFalse(flight.begin(.surface("Sun"),state:state))
        XCTAssertFalse(flight.begin(.surface("Not a planet"),state:state))
        XCTAssertTrue(flight.begin(.surface("Earth"),state:state))
        for _ in 0..<601 { _ = flight.advanceJump(state:&state,dt:1/120) }
        let before = state.position
        XCTAssertTrue(flight.begin(.solarSystem,state:state))
        _ = flight.advanceJump(state:&state,dt:0.1)
        flight.cancel(state:&state)
        XCTAssertEqual(flight.surfaceBody?.name,"Earth"); XCTAssertEqual(state.position,before)
    }
    func testLandscapeSweepAndEarthHasBothCoastAndMountains() throws {
        let earth = SolarLandscape(body:try XCTUnwrap(SolarBody.all.first { $0.name == "Earth" }))
        var heights:[Float] = []
        for x in stride(from:Float(-9000),through:9000,by:600) { for z in stride(from:Float(-9000),through:9000,by:600) { heights.append(earth.height(x:x,z:z)) } }
        XCTAssertLessThan(heights.min()!,0); XCTAssertGreaterThan(heights.max()!,600)
        XCTAssertTrue(earth.impact(from:[0,2000,0],to:[0,-500,0],radius:5))
        XCTAssertFalse(earth.impact(from:[0,2500,0],to:[1000,2500,0],radius:5))
    }
    func testStarPickingSharesNormalizedDeflectedDirections() throws {
        let star = try XCTUnwrap(StarCatalogue.star(32349))
        let plain = StarSkyGeometry.direction(position:star.positionPC,observer:.zero,lens:nil)
        XCTAssertEqual(simd_length(plain),1,accuracy:0.0001)
        let lensed = StarSkyGeometry.direction(position:star.positionPC,observer:.zero,lens:plain*2000+SIMD3<Float>(200,0,0))
        XCTAssertEqual(simd_length(lensed),1,accuracy:0.0001)
        XCTAssertLessThan(simd_dot(plain,lensed),1)
        XCTAssertNotNil(star.featureFact)
        XCTAssertNotNil(StarCatalogue.star(11767)?.featureFact)
    }
    func testHangarPreviewPersistsWithoutChangingControls() {
        let name = "Starflight-Hangar-Test-"+UUID().uuidString
        let defaults = UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        var settings = GameSettings(defaults:defaults)
        let sensitivity = settings.sensitivity
        XCTAssertEqual(settings.hangarPreview,.hangar)
        settings.hangarPreview = .selectedLevel; settings.save(defaults:defaults)
        let loaded = GameSettings(defaults:defaults)
        XCTAssertEqual(loaded.hangarPreview,.selectedLevel); XCTAssertEqual(loaded.sensitivity,sensitivity)
    }
}
