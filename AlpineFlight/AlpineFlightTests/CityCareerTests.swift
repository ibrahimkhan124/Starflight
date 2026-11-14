import XCTest
import simd
@testable import AlpineFlight

final class CityCareerTests: XCTestCase {
    private func stop(_ jobs:inout CoruscantJobs) -> CityJobEvent {
        guard let target = jobs.target else { XCTFail("Missing stop"); return .none }
        XCTAssertTrue(jobs.beginService(at:target.position))
        return jobs.advance(dt:jobs.serviceDuration)
    }
    private func cruise(_ jobs:inout CoruscantJobs, seconds:Float, bank:Float = 0, firing:Bool = false) {
        var state = FlightState()
        state.airspeed = 100; state.velocity = [0,0,-100]; state.roll = bank
        for _ in 0..<Int(seconds*120) {
            state.position += state.velocity/120
            jobs.observeFlight(state,flying:true,firing:firing,dt:1/120)
            _ = jobs.advance(dt:1/120)
        }
    }

    func testCatalogHasThreeDistinctContractsPerJobWithValidRoutesAndRewards() {
        XCTAssertEqual(CityContract.allCases.filter { $0.faction == nil }.count,12)
        XCTAssertEqual(Set(CityContract.allCases.map(\.id)).count,CityContract.allCases.count)
        for kind in CityJobKind.allCases {
            XCTAssertEqual(CityContract.allCases.filter { $0.kind == kind && $0.faction == nil }.count,3)
            let standard = CityContract.standard(for:kind)
            XCTAssertEqual(standard.stops,kind.stops)
            XCTAssertEqual(standard.baseCredits,kind.rewardCredits)
        }
        for contract in CityContract.allCases {
            XCTAssertGreaterThanOrEqual(contract.stops.count,2)
            XCTAssertGreaterThan(contract.routeDistance,1000)
            XCTAssertTrue(zip(contract.stops,contract.stops.dropFirst()).allSatisfy { $0 != $1 })
            // Match the wallet's city-job receipt ceiling; advanced contracts exceed 300.
            XCTAssertLessThanOrEqual(contract.baseCredits+contract.maximumBonus,1000)
            if contract.kind == .shuttle || contract.kind == .rescue { XCTAssertTrue(contract.stops.count.isMultiple(of:2)) }
        }
    }

    func testEveryContractCompletesInOrderWithItsOwnServiceDurationAndOneReceipt() {
        for contract in CityContract.allCases {
            var jobs = CoruscantJobs(); jobs.accept(contract)
            for (index,station) in contract.stops.enumerated() {
                XCTAssertEqual(jobs.target,station,contract.title)
                let event = stop(&jobs)
                if index == contract.stops.count-1 {
                    guard case .completed(let id,let credits) = event else { XCTFail(contract.title); continue }
                    XCTAssertEqual(credits,contract.baseCredits,"No bonus without actual flight")
                    XCTAssertEqual(jobs.lastCompletion?.id,id)
                    XCTAssertEqual(jobs.lastCompletion?.contract,contract)
                } else { XCTAssertEqual(event,.stopCompleted) }
            }
            XCTAssertNil(jobs.active)
            XCTAssertEqual(jobs.advance(dt:999),.none)
            XCTAssertEqual(jobs.completedJobs,1)
        }
    }

    func testShuttleAndRescueLoadChangesOnlyAfterActualPickupAndDeliveryService() {
        for contract in [CityContract.shuttleShift,.senateCircuit,.clinicEvacuation] {
            var jobs = CoruscantJobs(); jobs.accept(contract)
            for stage in contract.stops.indices {
                XCTAssertEqual(jobs.carryingPayload,!stage.isMultiple(of:2))
                XCTAssertTrue(jobs.beginService(at:jobs.target!.position))
                _ = jobs.advance(dt:1)
                XCTAssertEqual(jobs.stage,stage)
                XCTAssertEqual(jobs.carryingPayload,!stage.isMultiple(of:2))
                _ = jobs.advance(dt:jobs.serviceRemaining)
            }
        }
    }

    func testSpecialistScansReallyTakeFiveAndEightSeconds() {
        for contract in [CityContract.trafficSurvey,.deepScan] {
            var jobs = CoruscantJobs(); jobs.accept(contract)
            XCTAssertTrue(jobs.beginService(at:jobs.target!.position))
            XCTAssertEqual(jobs.advance(dt:3),.none)
            XCTAssertEqual(jobs.stage,0)
            XCTAssertEqual(jobs.serviceRemaining,contract.serviceSeconds-3)
            XCTAssertEqual(jobs.advance(dt:contract.serviceSeconds-3),.stopCompleted)
            XCTAssertEqual(jobs.stage,1)
        }
    }

    func testQualityIgnoresEmptyLegsMenusAndDockingAndPenalizesRoughPayloadFlight() {
        var jobs = CoruscantJobs(); jobs.accept(.spaceportLink)
        cruise(&jobs,seconds:20,bank:1.1,firing:true)
        XCTAssertEqual(jobs.quality.condition,100)
        XCTAssertEqual(jobs.quality.metres,0)
        XCTAssertEqual(stop(&jobs),.stopCompleted)
        cruise(&jobs,seconds:30,bank:1.1,firing:true)
        XCTAssertLessThan(jobs.quality.condition,75)
        let before = jobs.quality.condition
        var parked = FlightState(); parked.roll = 1.1; parked.airspeed = 100
        for _ in 0..<1200 { jobs.observeFlight(parked,flying:false,firing:true,dt:1/120) }
        XCTAssertEqual(jobs.quality.condition,before)
        XCTAssertTrue(jobs.beginService(at:jobs.target!.position))
        for _ in 0..<120 { jobs.observeFlight(parked,flying:true,firing:true,dt:1/120) }
        XCTAssertEqual(jobs.quality.condition,before)
    }

    func testRatingsAreStableAcrossFrameRatesAndMedicalLoadsAreMoreSensitive() {
        func condition(_ rate:Int,_ kind:CityJobKind) -> Float {
            var quality = CityRideQuality(), state = FlightState()
            state.roll = 0.9; state.airspeed = 100; state.velocity = [0,0,-100]
            for _ in 0..<(rate*20) { quality.observe(state:state,kind:kind,carrying:true,flying:true,firing:false,dt:1/Float(rate)) }
            return quality.condition
        }
        XCTAssertEqual(condition(60,.shuttle),condition(120,.shuttle),accuracy:0.03)
        XCTAssertLessThan(condition(120,.rescue),condition(120,.courier))
        XCTAssertLessThan(condition(120,.courier),condition(120,.shuttle))
    }

    func testSmoothSpecialistTripEarnsModestBonusButRoughTripKeepsBasePay() {
        for rough in [false,true] {
            var jobs = CoruscantJobs(); jobs.accept(.spaceportLink)
            _ = stop(&jobs)
            cruise(&jobs,seconds:30,bank:rough ? 1.1 : 0)
            guard case .completed(_,let credits) = stop(&jobs), let report = jobs.lastCompletion else { return XCTFail("No completion") }
            XCTAssertEqual(credits,CityContract.spaceportLink.baseCredits + (rough ? 0 : 10))
            XCTAssertEqual(report.bonusCredits,rough ? 0 : 10)
            XCTAssertEqual(report.stars,rough ? 3 : 5)
            XCTAssertGreaterThan(report.kilometres,2.9)
        }
    }

    func testSurveyBonusRequiresFlyingTheRouteAndCompletingAllScans() {
        var jobs = CoruscantJobs(); jobs.accept(.trafficSurvey)
        for _ in CityContract.trafficSurvey.stops {
            cruise(&jobs,seconds:30)
            _ = stop(&jobs)
        }
        XCTAssertEqual(jobs.lastCompletion?.bonusCredits,10)
        XCTAssertEqual(jobs.lastCompletion?.summary,"3 districts scanned")
    }

    func testAbandonedExpiredAndReplacedContractsNeverProduceDebriefs() {
        var jobs = CoruscantJobs(); jobs.accept(.fragileTechnology)
        cruise(&jobs,seconds:25)
        jobs.cancel()
        XCTAssertNil(jobs.lastCompletion)
        XCTAssertEqual(jobs.flightMetres,0)
        jobs.accept(.medicalSupplies)
        XCTAssertEqual(jobs.advance(dt:300),.expired)
        XCTAssertNil(jobs.lastCompletion)
        jobs.accept(.spaceportLink)
        XCTAssertEqual(jobs.quality.condition,100)
        XCTAssertEqual(jobs.stage,0)
    }

    func testTimedSpecialistRoutesAllowTheSlowestShipTimeToReachStops() {
        let arrival = SIMD3<Float>(0,320,8400)
        for contract in CityContract.allCases where contract != .courierRun && contract != .emergencyTransfer {
            guard let limit = contract.timeLimit else { continue }
            let distance = simd_distance(arrival,contract.stops[0].position)+contract.routeDistance
            let ideal = distance/(AircraftType.kestrel.cruiseSpeed*1.45)
            let approachAndService = Float(contract.stops.count)*(24+contract.serviceSeconds)
            XCTAssertGreaterThan(limit,ideal+approachAndService,contract.title)
        }
    }

    func testSavedCareerAndCreditsCommitTogetherAndRejectReplayAfterReload() throws {
        let suite = "CityCareerTests-"+UUID().uuidString
        let defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        var jobs = CoruscantJobs(); jobs.accept(.spaceportLink)
        _ = stop(&jobs); cruise(&jobs,seconds:30); _ = stop(&jobs)
        let report = try XCTUnwrap(jobs.lastCompletion)
        var wallet = FlightEconomy()
        wallet.earn(lowFlightPoints:7)
        XCTAssertTrue(wallet.claimCityJob(id:report.id,credits:report.credits,report:report))
        wallet.save(to:defaults)
        var loaded = FlightEconomy.load(from:defaults)
        XCTAssertEqual(loaded.cityCareer?.recent.first,report)
        XCTAssertEqual(loaded.cityCareer?.passengers,1)
        XCTAssertEqual(loaded.quarterCredits,7+report.credits*4)
        XCTAssertFalse(loaded.claimCityJob(id:report.id,credits:report.credits,report:report))
        XCTAssertEqual(loaded.cityCareer?.passengers,1)
    }

    func testLegacyReceiptsCountTowardLicencesWithoutInventingRatedTrips() throws {
        var wallet = FlightEconomy()
        for _ in 0..<8 { XCTAssertTrue(wallet.claimCityJob(id:UUID(),credits:80)) }
        let encoded = try JSONEncoder().encode(wallet)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with:encoded) as? [String:Any])
        json.removeValue(forKey:"cityCareer")
        let oldData = try JSONSerialization.data(withJSONObject:json)
        let restored = try JSONDecoder().decode(FlightEconomy.self,from:oldData)
        XCTAssertEqual(restored.completedCityJobs,8)
        XCTAssertEqual(restored.cityRank,"Senior City Pilot")
        XCTAssertNil(restored.cityCareer)
        XCTAssertEqual(restored.quarterCredits,wallet.quarterCredits)
        XCTAssertEqual(CityCareer.nextRank(completed:8)?.jobs,16)
    }

    func testCareerHistoryIsBoundedWhileTotalsKeepGrowing() {
        var wallet = FlightEconomy()
        for index in 0..<25 {
            let report = CityJobReport(id:UUID(),contract:.medicalSupplies,completedAt:Date(timeIntervalSince1970:Double(index)),seconds:100,kilometres:8,condition:100,stars:5,bonusCredits:10)
            XCTAssertTrue(wallet.claimCityJob(id:report.id,credits:report.credits,report:report))
        }
        XCTAssertEqual(wallet.completedCityJobs,25)
        XCTAssertEqual(wallet.cityCareer?.recent.count,20)
        XCTAssertEqual(wallet.cityCareer?.deliveries,50)
        XCTAssertEqual(wallet.cityCareer?.creditsEarned,2500)
        XCTAssertEqual(wallet.cityCareer?.averageCondition,100)
        XCTAssertEqual(wallet.cityCareer?.recent.first?.completedAt,Date(timeIntervalSince1970:24))
    }

    func testMismatchedReportCannotChangeWalletOrUnlockProgress() {
        var wallet = FlightEconomy()
        let report = CityJobReport(id:UUID(),contract:.spaceportLink,completedAt:Date(),seconds:30,kilometres:3,condition:100,stars:5,bonusCredits:10)
        XCTAssertFalse(wallet.claimCityJob(id:UUID(),credits:65,report:report))
        XCTAssertFalse(wallet.claimCityJob(id:report.id,credits:100,report:report))
        XCTAssertEqual(wallet.completedCityJobs,0)
        XCTAssertEqual(wallet.quarterCredits,0)
        XCTAssertNil(wallet.cityCareer)
    }

    func testCityChartIncludesAllSkyportsAndExtremePilotPositionsAtEqualScale() {
        for pilot in [SIMD3<Float>(12000,200,-12000),[-12000,300,12000],[0,180,0]] {
            let chart = CityChart(pilot:pilot)
            for point in CityStation.allCases.map(\.position)+[pilot] {
                let p = chart.point(point)
                XCTAssertTrue(p.x > 0 && p.x < 1 && p.y > 0 && p.y < 1)
            }
            let origin = chart.point(.zero)
            XCTAssertEqual(chart.point([1000,0,0]).x-origin.x,chart.point([0,0,1000]).y-origin.y,accuracy:0.0001)
            XCTAssertLessThan(chart.point([0,0,-1000]).y,origin.y)
        }
    }
}
