import XCTest
import simd
@testable import AlpineFlight

final class UrbanFlightFeedbackTests: XCTestCase {
    func testApproachBrakesFastShipsButLeavesSteeringAndDepartureFree() {
        let target = CityStation.spaceport
        for aircraft in AircraftType.allCases {
            var state = FlightState()
            state.position = target.position + [0,100,1000]
            state.heading = 0; state.velocity = [0,0,-aircraft.cruiseSpeed*1.4]
            state.airspeed = simd_length(state.velocity)
            let physics = FlightPhysics(aircraft:aircraft)
            var secondsInWindow:Float = 0
            for _ in 0..<2400 {
                let limit = CityDocking.approachSpeedLimit(for:state,target:target)
                physics.advanceSpace(&state,input:FlightInput(throttle:1),dt:1/120,speedLimit:limit)
                if simd_distance(state.position,target.position) < CityDocking.captureRadius { secondsInWindow += 1/120 }
            }
            XCTAssertGreaterThan(secondsInWindow,3,aircraft.name)
            state.position = target.position + [0,100,700]
            state.velocity = [0,0,100]
            XCTAssertNil(CityDocking.approachSpeedLimit(for:state,target:target))
        }
    }

    func testLargerDockWindowWorksAndBlocksAnOccupiedApproach() {
        let station = CityStation.spaceport
        var state = FlightState()
        state.position = station.position + [0,100,-350]
        state.velocity = [0,0,100]; state.airspeed = 100
        var dock = CityDocking()
        XCTAssertGreaterThan(simd_distance(state.position,station.position),200)
        XCTAssertTrue(dock.begin(station,state:&state))
        let city = PlanetExploration(planet:.coruscant)
        let blocked = city.obstacles.map { SIMD3<Float>($0.center.x,180,$0.center.z) }.first {
            simd_distance($0,station.position) < 450 && city.hitsObstacle(at:$0,radius:4)
        }
        XCTAssertNotNil(blocked)
        state.position = blocked!
        var unsafeDock = CityDocking()
        XCTAssertFalse(unsafeDock.begin(station,state:&state))
    }

    func testSurfaceLaserHitsAreRealAndDoNotInventHitsInOpenSky() {
        let city = PlanetExploration(planet:.coruscant)
        let obstacle = city.obstacles.first!
        var state = FlightState()
        state.position = [obstacle.center.x,180,obstacle.center.z + obstacle.size.z/2 + 50]
        state.heading = 0
        var weapons = WeaponSystem()
        _ = weapons.update(state:state,aircraft:.xwing,firing:true,dt:0.2)
        let hits = weapons.surfaceHits(on:city,dt:0.2)
        XCTAssertFalse(hits.isEmpty)
        weapons.consumeBolts(at:hits)
        XCTAssertTrue(weapons.bolts.isEmpty)
        state.position = [0,1200,0]
        weapons.reset()
        _ = weapons.update(state:state,aircraft:.xwing,firing:true,dt:0.2)
        XCTAssertTrue(weapons.surfaceHits(on:city,dt:0.2).isEmpty)
    }

    func testCrashAdviceDescribesTheEnvironmentAndCause() {
        XCTAssertEqual(FlightCrashAdvice(cause:"Coruscant building collision").title,"Building collision.")
        XCTAssertTrue(FlightCrashAdvice(cause:"Coruscant building collision").advice.contains("avenues"))
        XCTAssertEqual(FlightCrashAdvice(cause:"Hoth ground impact").title,"Ground impact.")
        XCTAssertTrue(FlightCrashAdvice(cause:"Asteroid impact").advice.contains("Asteroid"))
        XCTAssertEqual(FlightCrashAdvice(cause:"Enemy fighter").title,"Shot down.")
        XCTAssertEqual(FlightCrashAdvice(cause:"Death Star exploded").title,"Time ran out.")
    }
}

final class CoruscantJobsTests: XCTestCase {
    func testApproachGuidanceOnlyEstimatesArrivalWhenClosingAndUsesHeight() {
        let target = CityStation.spaceport.position
        let approach = CityApproach(position:target + [0,100,1000],velocity:[0,0,-100],target:target)
        XCTAssertTrue(approach.guidance.contains("Descend 100 m"))
        XCTAssertEqual(approach.estimatedSeconds!, 10.1, accuracy:0.1)
        let away = CityApproach(position:target + [0,-100,1000],velocity:[0,0,100],target:target)
        XCTAssertNil(away.estimatedSeconds)
        XCTAssertTrue(away.guidance.contains("Climb 100 m"))
        XCTAssertTrue(away.guidance.contains("steer towards"))
        XCTAssertNil(CityApproach(position:target + [0,0,1000],velocity:.zero,target:target).estimatedSeconds)
        XCTAssertTrue(CityApproach(position:target + [0,140,120],velocity:.zero,target:target).guidance.contains("Dock ready"))
        XCTAssertFalse(CityApproach(position:target + [0,0,450],velocity:.zero,target:target).guidance.contains("Dock ready"))
        XCTAssertEqual(CityApproach(position:[.nan,0,0],velocity:.zero,target:target).guidance,"Navigation unavailable")
    }

    func testRouteProgressIncludesServiceAndResetsOnCancellation() {
        var jobs = CoruscantJobs()
        jobs.accept(.shuttle)
        XCTAssertEqual(jobs.progress,0)
        XCTAssertTrue(jobs.beginService(at:CityStation.spaceport.position))
        _ = jobs.advance(dt:1.5)
        XCTAssertEqual(jobs.progress,0.5 / 6,accuracy:0.001)
        _ = jobs.advance(dt:1.5)
        XCTAssertEqual(jobs.progress,1.0 / 6,accuracy:0.001)
        jobs.cancel()
        XCTAssertEqual(jobs.progress,0)
        jobs.accept(.patrol)
        XCTAssertEqual(jobs.progress,0)
    }
    private func completeStop(_ jobs: inout CoruscantJobs) -> CityJobEvent {
        guard let target = jobs.target else {
            XCTFail("A job stop needs a target")
            return .none
        }
        XCTAssertTrue(jobs.beginService(at: target.position))
        XCTAssertTrue(jobs.docking)
        XCTAssertFalse(jobs.beginService(at: target.position), "Repeated taps cannot restart service")
        XCTAssertEqual(jobs.advance(dt: 1.5), .none)
        XCTAssertEqual(jobs.serviceRemaining, 1.5, accuracy: 0.001)
        return jobs.advance(dt: 1.5)
    }

    func testEveryJobFollowsItsWholeRouteAndPaysExactlyOnce() {
        for kind in CityJobKind.allCases {
            var jobs = CoruscantJobs()
            jobs.accept(kind)
            XCTAssertEqual(jobs.active, kind)
            XCTAssertEqual(jobs.stage, 0)
            var rewardID: UUID?
            for (index, station) in kind.stops.enumerated() {
                XCTAssertEqual(jobs.target, station)
                XCTAssertEqual(jobs.stage, index)
                let event = completeStop(&jobs)
                if index < kind.stops.count - 1 {
                    XCTAssertEqual(event, .stopCompleted)
                    XCTAssertFalse(jobs.docking)
                    XCTAssertNotEqual(jobs.target, station, "One location cannot service consecutive stops")
                    XCTAssertFalse(jobs.beginService(at: station.position))
                } else if case .completed(let id, let credits) = event {
                    rewardID = id
                    XCTAssertEqual(credits, kind.rewardCredits)
                } else {
                    XCTFail("Final stop did not complete \(kind.title)")
                }
            }
            XCTAssertNotNil(rewardID)
            XCTAssertEqual(jobs.completedJobs, 1)
            XCTAssertNil(jobs.active)
            XCTAssertNil(jobs.target)
            XCTAssertFalse(jobs.docking)
            XCTAssertEqual(jobs.advance(dt: 1000), .none)
            XCTAssertFalse(jobs.beginService(at: CityStation.medical.position))
        }
    }

    func testShuttleHasThreeSeparatePickupAndDropOffLegs() {
        XCTAssertEqual(CityJobKind.shuttle.stops.count, 6)
        for index in stride(from: 0, to: 6, by: 2) {
            XCTAssertNotEqual(CityJobKind.shuttle.stops[index], CityJobKind.shuttle.stops[index + 1])
        }
        var jobs = CoruscantJobs()
        jobs.accept(.shuttle)
        XCTAssertTrue(jobs.status.contains("Collect passenger 1"))
        XCTAssertEqual(completeStop(&jobs), .stopCompleted)
        XCTAssertTrue(jobs.status.contains("Drop off passenger 1"))
        XCTAssertEqual(completeStop(&jobs), .stopCompleted)
        XCTAssertTrue(jobs.status.contains("Collect passenger 2"))
    }

    func testServiceRequiresAnActiveJobAndStrictThreeDimensionalProximity() {
        var jobs = CoruscantJobs()
        let industrial = CityStation.industrial.position
        XCTAssertFalse(jobs.beginService(at: industrial))
        jobs.accept(.rescue)
        XCTAssertFalse(jobs.beginService(at: industrial + SIMD3<Float>(200, 0, 0)))
        XCTAssertFalse(jobs.beginService(at: industrial + SIMD3<Float>(0, 201, 0)))
        XCTAssertFalse(jobs.beginService(at: [Float.nan, 180, 0]))
        XCTAssertFalse(jobs.beginService(at: CityStation.medical.position))
        XCTAssertTrue(jobs.beginService(at: industrial + SIMD3<Float>(199, 0, 0)))
        XCTAssertEqual(jobs.stage, 0, "Entering docking does not instantly finish a stop")
        XCTAssertEqual(jobs.advance(dt: 2.99), .none)
        XCTAssertEqual(jobs.stage, 0)
        XCTAssertEqual(jobs.advance(dt: 0.02), .stopCompleted)
        XCTAssertEqual(jobs.target, .medical)
    }

    func testTimedJobsExpireOnceAndUntimedJobsRemainAvailable() {
        for kind in [CityJobKind.courier, .rescue] {
            var jobs = CoruscantJobs()
            jobs.accept(kind)
            let limit = kind.timeLimit!
            XCTAssertEqual(jobs.timeRemaining, limit)
            XCTAssertEqual(jobs.advance(dt: limit - 0.5), .none)
            XCTAssertEqual(jobs.timeRemaining!, 0.5, accuracy: 0.001)
            XCTAssertEqual(jobs.advance(dt: 0.5), .expired)
            XCTAssertNil(jobs.active)
            XCTAssertFalse(jobs.docking)
            XCTAssertEqual(jobs.completedJobs, 0)
            XCTAssertEqual(jobs.advance(dt: 10), .none)
        }
        for kind in [CityJobKind.shuttle, .patrol] {
            var jobs = CoruscantJobs()
            jobs.accept(kind)
            XCTAssertNil(jobs.timeRemaining)
            XCTAssertEqual(jobs.advance(dt: 1000), .none)
            XCTAssertEqual(jobs.active, kind)
        }
    }

    func testFinalServiceMustBeatDeadlineAndLargeFramesPreserveEventOrder() {
        let limit = CityJobKind.rescue.timeLimit!
        var expired = CoruscantJobs()
        expired.accept(.rescue)
        XCTAssertEqual(completeStop(&expired), .stopCompleted)
        XCTAssertEqual(expired.advance(dt: limit - 6), .none)
        XCTAssertTrue(expired.beginService(at: CityStation.medical.position))
        XCTAssertEqual(expired.advance(dt: 3), .expired, "Completion tied with the deadline is too late")
        XCTAssertEqual(expired.completedJobs, 0)

        var completed = CoruscantJobs()
        completed.accept(.rescue)
        XCTAssertEqual(completeStop(&completed), .stopCompleted)
        XCTAssertEqual(completed.advance(dt: limit - 7), .none)
        XCTAssertTrue(completed.beginService(at: CityStation.medical.position))
        if case .completed(_, let credits) = completed.advance(dt: 20) {
            XCTAssertEqual(credits, CityJobKind.rescue.rewardCredits)
            XCTAssertEqual(completed.elapsed, limit - 1)
        } else { XCTFail("Final service finished before the deadline inside a large frame") }

        var intermediate = CoruscantJobs()
        intermediate.accept(.courier)
        XCTAssertTrue(intermediate.beginService(at: CityStation.market.position))
        XCTAssertEqual(intermediate.advance(dt: CityJobKind.courier.timeLimit! + 20), .expired)
        XCTAssertEqual(intermediate.completedJobs, 0)
    }

    func testCancelDuringServiceOrReplacingAJobNeverPaysForAbandonedWork() {
        var jobs = CoruscantJobs()
        jobs.accept(.rescue)
        XCTAssertTrue(jobs.beginService(at: CityStation.industrial.position))
        XCTAssertEqual(jobs.advance(dt: 1), .none)
        jobs.cancel()
        XCTAssertNil(jobs.active)
        XCTAssertFalse(jobs.docking)
        XCTAssertEqual(jobs.advance(dt: 1000), .none)
        XCTAssertEqual(jobs.completedJobs, 0)
        jobs.accept(.courier)
        XCTAssertTrue(jobs.beginService(at: CityStation.market.position))
        jobs.accept(.patrol)
        XCTAssertEqual(jobs.target, .spaceport)
        XCTAssertEqual(jobs.stage, 0)
        XCTAssertEqual(jobs.elapsed, 0)
        XCTAssertFalse(jobs.docking)
        XCTAssertEqual(jobs.completedJobs, 0)
    }

    func testNewJobsHaveDistinctRewardIdentifiersAndInvalidTimeDoesNotAdvance() {
        var jobs = CoruscantJobs()
        var identifiers: Set<UUID> = []
        for _ in 0..<2 {
            jobs.accept(.patrol)
            XCTAssertEqual(jobs.advance(dt: .nan), .none)
            XCTAssertEqual(jobs.advance(dt: .infinity), .none)
            XCTAssertEqual(jobs.advance(dt: -1), .none)
            XCTAssertEqual(jobs.elapsed, 0)
            for _ in CityJobKind.patrol.stops {
                if case .completed(let id, _) = completeStop(&jobs) { identifiers.insert(id) }
            }
        }
        XCTAssertEqual(identifiers.count, 2)
        XCTAssertEqual(jobs.completedJobs, 2)
    }
}

final class CityDockingTests: XCTestCase {
    func testSmallerCityEnvelopeAllowsGrazingButStillStopsDirectBuildingAndGroundImpacts() {
        let city = PlanetExploration(planet: .coruscant)
        // Find an exposed, axis-aligned tower wall clear of neighbouring buildings.
        let tower = city.obstacles.first { obstacle in
            guard obstacle.yaw == 0, obstacle.center.y > 40 else { return false }
            let edge = obstacle.center + SIMD3<Float>(obstacle.size.x / 2, 0, 0)
            return !city.hitsObstacle(at: edge + SIMD3<Float>(4, 0, 0), radius: 3)
        }!
        for aircraft in AircraftType.allCases {
            var space = HyperspaceManager(terrain: TerrainGenerator(level: .freeRoam))
            var state = FlightState()
            space.beginRelaxedSpace(state: &state, speed: 100)
            space.enterPlanet(.coruscant, state: &state)
            let edge = tower.center + SIMD3<Float>(tower.size.x / 2, 0, 0)
            state.position = edge + SIMD3<Float>(aircraft.bodyRadius * 0.8, 0, 0)
            XCTAssertTrue(city.hitsObstacle(at: state.position, radius: aircraft.bodyRadius), aircraft.name)
            XCTAssertFalse(city.hitsObstacle(at: state.position, radius: aircraft.cityCollisionRadius), aircraft.name)
            XCTAssertNotEqual(space.advance(state: &state, collisionRadius: aircraft.bodyRadius,
                cityCollisionRadius: aircraft.cityCollisionRadius, dt: 1/120), .planetImpact(.coruscant), aircraft.name)
            state.position = tower.center
            XCTAssertEqual(space.advance(state: &state, collisionRadius: aircraft.bodyRadius,
                cityCollisionRadius: aircraft.cityCollisionRadius, dt: 1/120), .planetImpact(.coruscant), aircraft.name)
            state.position = CityStation.spaceport.position
            state.position.y = city.groundHeight(x: state.position.x, z: state.position.z) + aircraft.bodyRadius * 0.8
            XCTAssertEqual(space.advance(state: &state, collisionRadius: aircraft.bodyRadius,
                cityCollisionRadius: aircraft.cityCollisionRadius, dt: 1/120), .planetImpact(.coruscant), aircraft.name)
        }
    }

    func testAllAircraftDockThroughActualCoruscantCollisionGeometryAndDepart() {
        let city = PlanetExploration(planet: .coruscant)
        let dt: Float = 1 / 120
        XCTAssertEqual(AircraftType.allCases.count, 28)
        for station in CityStation.allCases {
            for aircraft in AircraftType.allCases {
                var docking = CityDocking()
                var state = FlightState()
                state.position = station.position + SIMD3<Float>(0, 140, 120)
                state.velocity = [0, 0, -100]
                state.airspeed = 100
                state.heading = 0.6
                state.pitch = 0.2
                state.roll = -0.2
                XCTAssertTrue(docking.begin(station, state: &state, aircraft:aircraft), aircraft.name)
                XCTAssertEqual(state.velocity, SIMD3<Float>(0, 0, -12))
                XCTAssertFalse(docking.begin(.market, state: &state))
                var arrivals = 0
                var elapsed: Float = 0
                for _ in 0..<2400 {
                    let previous = state.position
                    if docking.advance(state: &state, dt: dt) { arrivals += 1 }
                    elapsed += dt
                    XCTAssertLessThan(simd_distance(state.position, previous), 2.1,
                                      "Docking teleported \(aircraft.name)")
                    for probe in aircraft.collisionProbes {
                        let point = state.position + state.orientation.act(probe)
                        XCTAssertGreaterThan(city.clearance(at: point), 1, aircraft.name)
                        XCTAssertFalse(city.hitsObstacle(at: point, radius: aircraft.bodyRadius), "\(station.name) / \(aircraft.name)")
                    }
                    if docking.arrived { break }
                }
                XCTAssertTrue(docking.arrived, aircraft.name)
                XCTAssertEqual(arrivals, 1, aircraft.name)
                XCTAssertLessThan(elapsed, 20, aircraft.name)
                XCTAssertEqual(state.position, station.position)
                XCTAssertEqual(state.velocity, .zero)
                XCTAssertEqual(state.airspeed, 0)

                var jobs = CoruscantJobs()
                jobs.accept(.shuttle)
                while jobs.target != station, let next = jobs.target {
                    XCTAssertTrue(jobs.beginService(at: next.position))
                    _ = jobs.advance(dt: 3)
                }
                let serviceStage = jobs.stage
                XCTAssertTrue(jobs.beginService(at: state.position))
                let parked = state.position
                for _ in 0..<365 {
                    XCTAssertFalse(docking.advance(state: &state, dt: dt), "Arrival was emitted more than once")
                    _ = jobs.advance(dt: dt)
                    XCTAssertEqual(state.position, parked, aircraft.name)
                    XCTAssertEqual(state.velocity, .zero)
                    XCTAssertEqual(state.airspeed, 0)
                }
                XCTAssertEqual(jobs.stage, serviceStage + 1)
                XCTAssertFalse(jobs.docking)
                docking.depart(state: &state, speed: aircraft.cruiseSpeed)
                XCTAssertNil(docking.station)
                XCTAssertFalse(docking.arrived)
                XCTAssertGreaterThan(simd_dot(state.velocity, state.forward), 0)
                XCTAssertEqual(simd_length(state.velocity), state.airspeed, accuracy: 0.001)
                XCTAssertEqual(state.velocity, state.forward * state.airspeed)
            }
        }
    }

    func testDockingRangeInvalidTimeAndResetCannotMoveTheAircraft() {
        let station = CityStation.spaceport
        var state = FlightState()
        state.position = station.position + SIMD3<Float>(450, 0, 0)
        state.velocity = [0, 0, -100]
        var docking = CityDocking()
        XCTAssertFalse(docking.begin(station, state: &state))
        XCTAssertEqual(state.velocity, SIMD3<Float>(0, 0, -100))
        state.position = station.position + SIMD3<Float>(0, 451, 0)
        XCTAssertFalse(docking.begin(station, state: &state))
        state.position = station.position + SIMD3<Float>(0, 140, 120)
        XCTAssertTrue(docking.begin(station, state: &state))
        let position = state.position, velocity = state.velocity
        for dt: Float in [0, -1, .nan, .infinity] {
            XCTAssertFalse(docking.advance(state: &state, dt: dt))
            XCTAssertEqual(state.position, position)
            XCTAssertEqual(state.velocity, velocity)
            XCTAssertFalse(docking.arrived)
        }
        docking.reset()
        XCTAssertNil(docking.station)
        XCTAssertFalse(docking.arrived)
        XCTAssertFalse(docking.advance(state: &state, dt: 1))
        XCTAssertEqual(state.position, position)
        XCTAssertEqual(state.velocity, velocity)
    }
}

final class CityJobWalletTests: XCTestCase {
    func testJobCreditsUseExactQuarterAccountingAndRejectInvalidOrRepeatedClaims() {
        var wallet = FlightEconomy()
        wallet.earn(lowFlightPoints: 7)
        var expectedQuarters = 7
        for kind in CityJobKind.allCases {
            let id = UUID()
            XCTAssertTrue(wallet.claimCityJob(id: id, credits: kind.rewardCredits))
            expectedQuarters += kind.rewardCredits * 4
            XCTAssertEqual(wallet.quarterCredits, expectedQuarters)
            XCTAssertTrue(wallet.cityJobReceipts?.contains(id) == true)
            XCTAssertFalse(wallet.claimCityJob(id: id, credits: kind.rewardCredits))
            XCTAssertEqual(wallet.quarterCredits, expectedQuarters)
        }
        let invalidID = UUID()
        for amount in [-1, 0, 1001, Int.max] {
            XCTAssertFalse(wallet.claimCityJob(id: invalidID, credits: amount))
            XCTAssertEqual(wallet.quarterCredits, expectedQuarters)
        }
        XCTAssertTrue(wallet.claimCityJob(id: invalidID, credits: 1000), "An invalid claim must not consume its receipt")
        XCTAssertEqual(wallet.quarterCredits, expectedQuarters + 4000)
    }

    func testSavedJobReceiptRefusesReplayAfterReopeningTheWallet() {
        let name = "CityJobWalletTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var wallet = FlightEconomy()
        wallet.earn(lowFlightPoints: 13)
        _ = wallet.grant(.tieDefender, count: 17)
        let id = UUID()
        XCTAssertTrue(wallet.claimCityJob(id: id, credits: 150))
        wallet.save(to: defaults)
        var reopened = FlightEconomy.load(from: defaults)
        XCTAssertEqual(reopened, wallet)
        XCTAssertEqual(reopened.quarterCredits, 613)
        XCTAssertFalse(reopened.claimCityJob(id: id, credits: 150))
        XCTAssertEqual(reopened.quarterCredits, 613)
        XCTAssertEqual(reopened.count(for: .tieDefender), 17)
        reopened.save(to: defaults)
        XCTAssertEqual(FlightEconomy.load(from: defaults), wallet)
    }

    func testLegacyWalletWithoutJobReceiptsPreservesCurrencyBlueprintsAndUnlocks() throws {
        let name = "CityJobWalletLegacyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var wallet = FlightEconomy()
        wallet.earn(lowFlightPoints: 12345)
        _ = wallet.grant(.bWing, count: 15)
        _ = wallet.grant(.tieDefender, count: 17)
        let data = try JSONEncoder().encode(wallet)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "cityJobReceipts")
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: FlightEconomy.key)

        var restored = FlightEconomy.load(from: defaults)
        XCTAssertEqual(restored.quarterCredits, wallet.quarterCredits)
        XCTAssertEqual(restored.blueprints, wallet.blueprints)
        XCTAssertEqual(restored.unlockedShips, wallet.unlockedShips)
        XCTAssertEqual(restored.spareBlueprints, wallet.spareBlueprints)
        XCTAssertTrue(restored.unlocked(.bWing))
        XCTAssertEqual(restored.extras(for: .bWing), 3)
        XCTAssertEqual(restored.count(for: .tieDefender), 17)
        let id = UUID()
        XCTAssertTrue(restored.claimCityJob(id: id, credits: 120))
        XCTAssertEqual(restored.quarterCredits, 12345 + 480)
        restored.save(to: defaults)
        var reopened = FlightEconomy.load(from: defaults)
        XCTAssertFalse(reopened.claimCityJob(id: id, credits: 120))
        XCTAssertEqual(reopened.quarterCredits, restored.quarterCredits)
        XCTAssertEqual(reopened.blueprints, wallet.blueprints)
        XCTAssertEqual(reopened.spareBlueprints, wallet.spareBlueprints)
    }
}
