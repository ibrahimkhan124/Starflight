import XCTest
import RealityKit
import AVFoundation
import simd
@testable import AlpineFlight

final class ExpansionTests: XCTestCase {
    @MainActor
    func testSoundPreviewStartsAndMuteControlsStopItWithoutMicrophonePermission() throws {
        let audio = FlightAudio(); audio.setVolume(0.8)
        let status = audio.testSound(enabled:true)
        XCTAssertTrue(status.hasPrefix("Test sound playing"),status); XCTAssertTrue(audio.isPlaying)
#if canImport(UIKit)
        XCTAssertEqual(AVAudioSession.sharedInstance().category,.playback)
        let droid = DroidVoiceController(); droid.stop()
        XCTAssertEqual(AVAudioSession.sharedInstance().category,.playback)
#endif
        audio.suspend(); XCTAssertFalse(audio.isPlaying)
        XCTAssertTrue(audio.testSound(enabled:false).contains("Turn on")); XCTAssertFalse(audio.isPlaying)
        audio.setVolume(0); XCTAssertTrue(audio.testSound(enabled:true).contains("above 0%")); XCTAssertFalse(audio.isPlaying)
        audio.setVolume(0.8)
        for _ in 0..<60 { audio.update(throttle:0.7,enabled:true,flying:true,dt:1/60,weather:.rain,weatherActive:true) }
        XCTAssertTrue(audio.isPlaying); XCTAssertNil(audio.playbackIssue)
        audio.update(throttle:0,enabled:false,flying:true); XCTAssertFalse(audio.isPlaying)
    }

    @MainActor
    func testCometsUseBoundedPreparedMeshesAndMoveWithoutAllocatingEntities() {
        for reduced in [false,true] {
            let pool = SpaceScenery.makePlanetComets(reducedDetail:reduced)
            XCTAssertEqual(pool.children.count,reduced ? 2:3)
            let ids = pool.children.map(\.id)
            let comet = PlanetComet(id:0,position:[10,20,30],velocity:[0,0,-80],hazardous:false)
            SpaceScenery.updatePlanetComets(pool,comets:[comet])
            XCTAssertTrue(pool.children.first!.isEnabled)
            XCTAssertEqual(pool.children.first!.position,comet.position)
            SpaceScenery.updatePlanetComets(pool,comets:[])
            XCTAssertFalse(pool.children.first!.isEnabled)
            XCTAssertEqual(pool.children.map(\.id),ids)
        }
    }

    @MainActor
    func testSoundLibraryDecodesWithHeadroomAndCleanLoopSeams() throws {
        let audio = FlightAudio()
        XCTAssertTrue(audio.missingAssets.isEmpty,"Missing audio: \(audio.missingAssets)")
        let loops = Set(FlightAudio.EngineProfile.allCases.map(\.rawValue)+["wind","skid"]+FlightAudio.weatherLoops)
        for name in FlightAudio.assetNames {
            let url = try XCTUnwrap(FlightAudio.assetURL(name),name)
            let file = try AVAudioFile(forReading:url)
            XCTAssertEqual(file.processingFormat.channelCount,2,name)
            XCTAssertEqual(file.processingFormat.sampleRate,44100,name)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:AVAudioFrameCount(file.length)))
            try file.read(into:buffer)
            let channels = try XCTUnwrap(buffer.floatChannelData)
            for channel in 0..<2 {
                let count = Int(buffer.frameLength), values = channels[channel]
                var peak:Float = 0
                for index in 0..<count {
                    XCTAssertTrue(values[index].isFinite,name)
                    peak = max(peak,abs(values[index]))
                }
                XCTAssertGreaterThan(peak,0.2,name)
                XCTAssertLessThan(peak,0.8,name)
                if loops.contains(name) { XCTAssertEqual(values[0],values[count-1],accuracy:0.001,name) }
                else {
                    XCTAssertLessThan(abs(values[0]),0.002,name)
                    XCTAssertLessThan(abs(values[count-1]),0.002,name)
                }
            }
        }
    }

    @MainActor
    func testShipSoundFamiliesAndSmoothMixAcrossFrameRates() {
        XCTAssertEqual(FlightAudio.EngineProfile.profile(for:.tieDefender),.ion)
        XCTAssertEqual(FlightAudio.EngineProfile.profile(for:.imperialShuttle),.freighter)
        XCTAssertEqual(FlightAudio.EngineProfile.profile(for:.enterprise),.warp)
        XCTAssertEqual(FlightAudio.EngineProfile.profile(for:.xwing),.fighter)
        for ship in AircraftType.allCases where ship.isPodracer {
            XCTAssertEqual(FlightAudio.EngineProfile.profile(for:ship),.pod)
        }
        var slow = FlightSoundMix(), fast = FlightSoundMix()
        for _ in 0..<30 { slow.advance(throttle:1,speed:180,clearance:30,dt:1/30,inSpace:false,boosting:true,skidding:true,cockpit:false) }
        for _ in 0..<60 { fast.advance(throttle:1,speed:180,clearance:30,dt:1/60,inSpace:false,boosting:true,skidding:true,cockpit:false) }
        XCTAssertEqual(slow.engine,fast.engine,accuracy:0.0001)
        XCTAssertEqual(slow.rate,fast.rate,accuracy:0.0001)
        XCTAssertGreaterThan(fast.wind,0)
        XCTAssertGreaterThan(fast.skid,0)
        for _ in 0..<120 { fast.advance(throttle:0.5,speed:180,clearance:30,dt:1/60,inSpace:true,boosting:false,skidding:true,cockpit:false) }
        XCTAssertLessThan(fast.wind,0.0001)
        XCTAssertLessThan(fast.skid,0.0001)
        fast.advance(throttle:.nan,speed:.nan,clearance:.nan,dt:.nan,inSpace:false,boosting:false,skidding:false,cockpit:false)
        XCTAssertTrue(fast.engine.isFinite && fast.rate.isFinite && fast.wind.isFinite && fast.skid.isFinite)
    }

    func testGunSoundEventsOccurOnlyWhenAProjectileIsEmitted() {
        for ship in AircraftType.allCases {
            var weapons = WeaponSystem()
            let state = FlightState()
            var shots = 0
            for _ in 0..<120 {
                let before = weapons.bolts.count
                _ = weapons.update(state:state,aircraft:ship,firing:true,dt:1/120)
                XCTAssertEqual(weapons.firedThisStep,weapons.bolts.count>before,ship.name)
                if weapons.firedThisStep { shots += 1 }
            }
            XCTAssertGreaterThan(shots,1,ship.name)
            _ = weapons.update(state:state,aircraft:ship,firing:false,dt:1)
            XCTAssertFalse(weapons.firedThisStep)
            weapons.reset()
            XCTAssertFalse(weapons.firedThisStep)
        }
    }

    func testEffectsVolumePersistsAndClampsInvalidValues() {
        let (defaults,name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName:name) }
        XCTAssertEqual(GameSettings(defaults:defaults).soundVolume,0.8)
        var settings = GameSettings(defaults:defaults)
        settings.soundVolume = 0.35; settings.save(defaults:defaults)
        XCTAssertEqual(GameSettings(defaults:defaults).soundVolume,0.35)
        defaults.set(1.8,forKey:"soundVolume")
        XCTAssertEqual(GameSettings(defaults:defaults).soundVolume,1)
        defaults.set(-0.5,forKey:"soundVolume")
        XCTAssertEqual(GameSettings(defaults:defaults).soundVolume,0)
    }
    @MainActor
    func testLowFlightPointsExcludeUnsafeStationaryAndSpaceFlight() {
        var score = LowFlightScore()
        for _ in 0..<120 { score.advance(clearance: 50, speed: 60, eligible: true, dt: 1/120) }
        XCTAssertGreaterThan(score.total, 3)
        XCTAssertLessThan(score.total, 4) // Far below the former 50 FLP per second at this height.
        let before = score.points
        for (height, speed, allowed): (Float, Float, Bool) in [(4, 60, true), (60, 60, true), (100, 60, true), (50, 44, true), (50, 0, true), (50, 60, false)] {
            score.advance(clearance: height, speed: speed, eligible: allowed, dt: 0.1)
        }
        XCTAssertEqual(score.points, before)
        var closer = LowFlightScore()
        closer.advance(clearance: 20, speed: 60, eligible: true, dt: 0.1)
        var higher = LowFlightScore()
        higher.advance(clearance: 50, speed: 60, eligible: true, dt: 0.1)
        XCTAssertGreaterThan(closer.total, higher.total)
        var closest = LowFlightScore()
        for _ in 0..<120 { closest.advance(clearance:8,speed:60,eligible:true,dt:1/120) }
        XCTAssertLessThan(closest.total,18)
        let saved = closest.total
        closest.advance(clearance:.nan,speed:60,eligible:true,dt:0.1)
        closest.advance(clearance:10,speed:.infinity,eligible:true,dt:0.1)
        closest.advance(clearance:10,speed:60,eligible:true,dt:.infinity)
        XCTAssertEqual(closest.total,saved)
    }
    func testPlanetsRemainExplorableWithoutLoadingStoryLevels() {
        for planet in SpacePlanet.allCases {
            var space = HyperspaceManager(terrain: TerrainGenerator(level: .freeRoam))
            var state = FlightState()
            space.beginRelaxedSpace(state: &state, speed: 100)
            space.selectPlanet(planet)
            XCTAssertEqual(space.targetPortal(to: state.position), planet.position)
            XCTAssertTrue(space.targetName(to: state.position).contains(planet.name))
            state.position = planet.position + SIMD3<Float>(0, 0, planet.radius + 180)
            XCTAssertEqual(space.advance(state: &state, collisionRadius: 8, dt: 1/60), .enteredSpace)
            XCTAssertEqual(space.surfacePlanet, planet)
            XCTAssertEqual(space.zone, .asteroidField)
            XCTAssertTrue(space.relaxedSpace)
            XCTAssertGreaterThan(PlanetExploration(planet: planet).clearance(at: state.position), 200)
            XCTAssertFalse(PlanetExploration(planet: planet).hitsObstacle(at: state.position, radius: 30))
            state.position = [0, 0, 0]
            XCTAssertEqual(space.advance(state: &state, collisionRadius: 8, dt: 1/60), .planetImpact(planet))
        }
    }

    func testEveryPlanetCanReturnToOrbitAndReset() {
        for planet in SpacePlanet.allCases {
            var space = HyperspaceManager(terrain: TerrainGenerator(level: .freeRoam))
            var state = FlightState()
            space.beginRelaxedSpace(state: &state, speed: 100)
            space.enterPlanet(planet, state: &state)
            let obstacle = PlanetExploration(planet: planet).obstacles[0]
            XCTAssertTrue(PlanetExploration(planet: planet).hitsObstacle(at: obstacle.center, radius: 8))
            state.position.y = PlanetExploration(planet:planet).orbitAltitude + 50
            XCTAssertEqual(space.advance(state: &state, collisionRadius: 8, dt: 1/60), .enteredSpace)
            XCTAssertNil(space.surfacePlanet)
            XCTAssertGreaterThan(planet.clearance(at: state.position), 600)
            XCTAssertEqual(space.advance(state: &state, collisionRadius: 8, dt: 1/60), .none)
            space.enterPlanet(planet, state: &state)
            space.returnToOrbit(state: &state)
            XCTAssertNil(space.surfacePlanet)
            space.enterPlanet(planet, state: &state)
            space.reset()
            XCTAssertNil(space.surfacePlanet)
        }
    }

    func testExpandedSurfaceRoutesAreSafeForEveryAircraft() {
        XCTAssertEqual(PlanetExploration.extent * 2, 24000)
        for planet in SpacePlanet.allCases {
            let surface = PlanetExploration(planet:planet)
            XCTAssertEqual(surface.landmarks.count, 6)
            XCTAssertGreaterThan(surface.obstacles.count, 700)
            for aircraft in AircraftType.allCases {
                for p in [surface.arrival] + surface.landmarks.map(\.position) {
                    XCTAssertGreaterThan(surface.clearance(at:p), aircraft.bodyRadius, "\(planet.name) \(aircraft.name)")
                    XCTAssertFalse(surface.hitsObstacle(at:p,radius:aircraft.bodyRadius), "\(planet.name) \(aircraft.name)")
                }
            }
        }
    }

    func testSurfaceSpatialCollisionMatchesAllGeometry() {
        for planet in SpacePlanet.allCases {
            let surface = PlanetExploration(planet:planet)
            for obstacle in surface.obstacles.enumerated().filter({ $0.offset.isMultiple(of:31) }).map(\.element) {
                for point in [obstacle.center, obstacle.center + obstacle.size/2 + SIMD3<Float>(12,0,0), SIMD3<Float>(0,380,8400)] {
                    let brute = surface.obstacles.contains {
                        let d = point-$0.center
                        let p = SIMD3<Float>(cos($0.yaw)*d.x-sin($0.yaw)*d.z,d.y,sin($0.yaw)*d.x+cos($0.yaw)*d.z)
                        return simd_distance_squared(p,simd_clamp(p,-$0.size/2,$0.size/2)) <= 400
                    }
                    XCTAssertEqual(surface.hitsObstacle(at:point,radius:20), brute)
                }
            }
            let x:Float = 817, z:Float = -2519
            let ground = surface.groundHeight(x:x,z:z)
            XCTAssertEqual(surface.clearance(at:[x,ground,z]),0,accuracy:0.001)
        }
    }

    func testSurfaceScoutRunAwardsOnceInOrderAndResetsOnEntry() {
        for planet in SpacePlanet.allCases {
            var space = HyperspaceManager(terrain:TerrainGenerator(level:.freeRoam))
            var state = FlightState()
            space.beginRelaxedSpace(state:&state,speed:100)
            space.enterPlanet(planet,state:&state)
            let route = PlanetExploration(planet:planet).landmarks
            state.position = route.last!.position
            XCTAssertEqual(space.advance(state:&state,collisionRadius:8,dt:1/120),.none)
            XCTAssertEqual(space.surfaceBeacons,0)
            for (index,stop) in route.enumerated() {
                state.position = stop.position
                XCTAssertEqual(space.advance(state:&state,collisionRadius:8,dt:1/120),.surfaceBeacon)
                XCTAssertEqual(space.surfaceBeacons,index+1)
                XCTAssertEqual(space.advance(state:&state,collisionRadius:8,dt:1/120),.none)
            }
            XCTAssertEqual(space.surfacePoints,2000)
            XCTAssertTrue(space.targetName(to:state.position).contains("complete"))
            space.returnToOrbit(state:&state)
            space.enterPlanet(planet,state:&state)
            XCTAssertEqual(space.surfaceBeacons,0)
            XCTAssertEqual(space.surfacePoints,0)
        }
    }

    func testMountainPlanetsHaveLargeReliefAndRoomBelowOrbit() {
        for planet in [SpacePlanet.tatooine, .hoth, .endor] {
            let surface = PlanetExploration(planet:planet)
            var highest: Float = 0
            for x in stride(from: Float(-11000), through: 11000, by: 300) {
                for z in stride(from: Float(-11000), through: 11000, by: 300) {
                    highest = max(highest,surface.groundHeight(x:x,z:z))
                }
            }
            XCTAssertGreaterThan(highest,1300,planet.name)
            XCTAssertLessThan(highest + 600,surface.orbitAltitude,planet.name)
            XCTAssertLessThan(surface.groundHeight(x:0,z:8400),100)
            for landmark in surface.landmarks {
                XCTAssertLessThan(landmark.position.y + 100,surface.orbitAltitude)
            }
        }
    }

    func testCoruscantTunnelsHaveSolidWallsAndOpenFlightCorridors() {
        let city = PlanetExploration(planet:.coruscant)
        XCTAssertGreaterThanOrEqual(city.tunnels.count,30)
        XCTAssertLessThanOrEqual(city.tunnels.count,40)
        for tunnel in city.tunnels {
            XCTAssertEqual(tunnel.solids.count,PlanetExploration.CityTunnel.segments*4)
            XCTAssertGreaterThan(tunnel.routeLength,900)
            XCTAssertGreaterThan((tunnel.path.map(\.x).max() ?? 0)-(tunnel.path.map(\.x).min() ?? 0),170)
            for solid in tunnel.solids { XCTAssertTrue(city.hitsObstacle(at:solid.center,radius:1)) }
            for ship in AircraftType.allCases {
                for (a,b) in zip(tunnel.path,tunnel.path.dropFirst()) {
                    for t:Float in [0,0.5,1] {
                        XCTAssertFalse(city.hitsObstacle(at:a+(b-a)*t,radius:ship.wingspan/2+3),ship.name)
                    }
                }
            }
            let solid = tunnel.solids[2]
            XCTAssertTrue(city.hitsObstacle(at:solid.center,radius:2))
        }
        XCTAssertTrue(city.landmarks.contains { $0.name == "Neon tower tunnel" })
    }

    func testSpaceMapProjectsEveryPlanetAndDistantPilotWithinBounds() {
        for pilot:SIMD3<Float> in [[0,0,0],[25000,-500,-32000],[-10000,2000,8000]] {
            let portal = SIMD3<Float>(0,0,400)
            let chart = SpaceChart(pilot:pilot,portal:portal)
            for point in SpacePlanet.allCases.map(\.position)+[pilot,portal] {
                let p = chart.point(point)
                XCTAssertGreaterThan(p.x,0); XCTAssertLessThan(p.x,1)
                XCTAssertGreaterThan(p.y,0); XCTAssertLessThan(p.y,1)
            }
            let p = chart.point(pilot), north = chart.point(pilot+[0,0,-100]), east = chart.point(pilot+[100,0,0])
            XCTAssertLessThan(north.y,p.y)
            XCTAssertGreaterThan(east.x,p.x)
            XCTAssertEqual(p.y-north.y,east.x-p.x,accuracy:0.0001)
            XCTAssertEqual(chart.point(pilot+[0,900,0]),p)
        }
    }
    func testSpaceCourseUsesFlightHeadingsAndShortestTurn() {
        let bearings:[(SIMD3<Float>,Float)] = [([0,0,-100],0),([100,0,0],90),([0,0,100],180),([-100,0,0],270)]
        for (destination,degrees) in bearings {
            let course = SpaceCourse(from:.zero,to:destination,heading:0)
            XCTAssertEqual(course.headingDegrees!,degrees,accuracy:0.001)
            XCTAssertEqual(course.distance,100,accuracy:0.001)
        }
        let east = SpaceCourse(from:.zero,to:[100,0,0],heading:0)
        XCTAssertTrue(east.steering.contains("right")); XCTAssertTrue(east.steering.contains("90°"))
        let west = SpaceCourse(from:.zero,to:[-100,0,0],heading:0)
        XCTAssertTrue(west.steering.contains("left"))
        let wrapped = SpaceCourse(from:.zero,to:[0,0,-100],heading:350 * .pi/180)
        XCTAssertEqual(wrapped.turnDegrees!,10,accuracy:0.001)
        let reverseWrap = SpaceCourse(from:.zero,to:[0,0,-100],heading:10 * .pi/180)
        XCTAssertEqual(reverseWrap.turnDegrees!,-10,accuracy:0.001)
        let onCourse = SpaceCourse(from:[20,5,10],to:[20,5,-90],heading:0)
        XCTAssertTrue(onCourse.steering.contains("On course")); XCTAssertEqual(onCourse.altitude,"Altitude aligned")
        let above = SpaceCourse(from:.zero,to:[0,120,0],heading:2)
        XCTAssertNil(above.headingDegrees); XCTAssertNil(above.turnDegrees)
        XCTAssertEqual(above.altitude,"Climb 120 m"); XCTAssertEqual(above.steering,"Horizontal position aligned")
        let below = SpaceCourse(from:.zero,to:[0,-80,0],heading:0)
        XCTAssertEqual(below.altitude,"Descend 80 m")
    }

    @MainActor
    func testResidentsBelongToTheirPlanetsAndStayNearSafeCampGround() {
        for (planet,species) in [(SpacePlanet.endor,PlanetInhabitant.ewok),(.tatooine,.jawa),(.hoth,.wampa)] {
            XCTAssertEqual(PlanetInhabitant.resident(on:planet),species)
            let full = PlanetInhabitant.sites(on:planet,reduced:false)
            XCTAssertGreaterThanOrEqual(full.count,5)
            XCTAssertGreaterThan(full.count,PlanetInhabitant.sites(on:planet,reduced:true).count)
            let surface = PlanetExploration(planet:planet)
            for p in full {
                XCTAssertEqual(p.y,surface.groundHeight(x:p.x,z:p.z),accuracy:0.01)
                XCTAssertFalse(surface.hitsObstacle(at:p+[0,10,0],radius:20))
            }
            let renderer = PlanetSurfaceRenderer(planet:planet,reducedDetail:true)
            XCTAssertNotNil(renderer.root.findEntity(named:species.label+" camp 1"))
        }
        XCTAssertNil(PlanetInhabitant.resident(on:.coruscant))
    }

    @MainActor
    func testEngineExhaustIsBoundedAndRespondsSmoothlyWithoutNewEntities() {
        for ship in AircraftType.allCases {
            let root = Entity()
            let effect = EngineEffects(on:root,type:ship)
            let nozzles = effect.root.children.count
            XCTAssertGreaterThan(nozzles,0)
            XCTAssertLessThanOrEqual(nozzles,4)
            effect.update(throttle:1,boosting:false,dt:1/60)
            XCTAssertGreaterThan(effect.strength,0)
            XCTAssertLessThan(effect.strength,0.3)
            for _ in 0..<180 { effect.update(throttle:1,boosting:true,dt:1/60) }
            XCTAssertGreaterThan(effect.strength,0.99)
            XCTAssertEqual(effect.root.children.count,nozzles)
            effect.update(throttle:.nan,boosting:false,dt:.nan)
            XCTAssertTrue(effect.strength.isFinite)
            for nozzle in effect.root.children {
                for mesh in nozzle.children { XCTAssertTrue(mesh.scale.x.isFinite); XCTAssertGreaterThan(mesh.scale.z,0) }
            }
        }
    }

    func testCoruscantHasCitySurfaceAndSafeApproach() {
        XCTAssertTrue(SpacePlanet.allCases.contains(.coruscant))
        let planet = SpacePlanet.coruscant
        XCTAssertLessThan(planet.clearance(at: planet.position), 0)
        for i in 1..<64 {
            let direction = simd_normalize(SIMD3<Float>(Float(i), 20, -30))
            let safe = planet.position + direction * (planet.radius + 100)
            XCTAssertGreaterThan(planet.clearance(at: safe), 40)
            let inside = planet.position + direction * (planet.radius - 1)
            XCTAssertLessThan(planet.clearance(at: inside), 0)
        }
    }

    func testRelaxedSpaceStartsWithoutIncomingAsteroidsAndCanReturn() {
        var space = HyperspaceManager(terrain: TerrainGenerator(level: .freeRoam))
        var state = FlightState()
        space.beginRelaxedSpace(state: &state, speed: 100)
        XCTAssertEqual(space.zone, .asteroidField)
        XCTAssertTrue(space.relaxedSpace); XCTAssertTrue(space.asteroids.isEmpty)
        for _ in 0..<600 { XCTAssertEqual(space.advance(state: &state, collisionRadius: 8, dt: 1/60), .none) }
        XCTAssertTrue(space.asteroids.isEmpty)
        state.position = space.returnPortal
        XCTAssertEqual(space.advance(state: &state, collisionRadius: 8, dt: 1/60), .returnedToAtmosphere)
        XCTAssertEqual(space.zone, .atmosphere); XCTAssertFalse(space.relaxedSpace)
    }

    @MainActor
    func testSpaceFreeRoamRestoresFromSavedSelection() {
        let name = "SpaceFreeRoamTest.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("freeRoam", forKey: "level")
        defaults.set(true, forKey: "spaceFreeRoam")
        let engine = GameEngine(defaults: defaults)
        XCTAssertTrue(engine.hud.inSpace)
        XCTAssertEqual(engine.levelName, "Space Free Roam")
        XCTAssertEqual(engine.hud.lowFlightPoints, 0)
        engine.selectLevel(.freeRoam)
        XCTAssertFalse(engine.settings.spaceFreeRoam)
        XCTAssertFalse(engine.hud.inSpace)
    }

    @MainActor
    func testAlternateIconAssetsAreBundledForPhoneAndPad() {
        let info = Bundle.main.infoDictionary!
        for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
            let icons = info[key] as? [String: Any]
            let alternates = icons?["CFBundleAlternateIcons"] as? [String: Any]
            for name in ["GoldIcon", "HyperspaceIcon"] {
                let entry = alternates?[name] as? [String: Any]
                XCTAssertEqual(entry?["CFBundleIconName"] as? String, name, key)
            }
        }
        for name in ["standard", "hyperspace", "gold"] {
            XCTAssertNotNil(UIImage(named: "IconPreview_\(name)"))
        }
    }
    func testFreeRoamSectorsAndPortalPlacement() {
        let terrain = TerrainGenerator(level: .freeRoam)
        for sector in FreeRoamSector.allCases {
            XCTAssertEqual(FreeRoamSector.containing(sector.center), sector)
        }
        for portal in HyperspaceManager(terrain: terrain).portals {
            XCTAssertEqual(FreeRoamSector.containing(portal.position), .portals)
            XCTAssertGreaterThan(portal.position.y - terrain.surfaceHeight(x: portal.position.x, z: portal.position.z), 300)
        }
        for pad in FreeRoamActivities.pads {
            XCTAssertEqual(terrain.surfaceHeight(x: pad.x, z: pad.z), 190, accuracy: 0.01)
        }
    }
    func testLandingRejectsFastAndHardApproachesThenAllowsTakeoff() {
        for (speed, descent) in [(Float(50), Float(-2)), (Float(10), Float(-15))] {
            var activity = FreeRoamActivities()
            var old = FlightState(); old.position = [1500, 230, 1500]
            var next = old; next.position.y = 212; next.velocity = [0, descent, -speed]
            XCTAssertEqual(activity.contact(from: old, to: &next, bodyRadius: 3), .hardImpact)
            XCTAssertFalse(activity.landed)
        }
        var activity = FreeRoamActivities()
        var old = FlightState(); old.position = [1500, 230, 1500]
        var next = old; next.position.y = 212; next.velocity = [0, -2, -10]
        XCTAssertEqual(activity.contact(from: old, to: &next, bodyRadius: 3), .landed)
        XCTAssertEqual(next.position.y, 215)
        XCTAssertEqual(next.velocity, .zero)
        XCTAssertEqual(activity.landings, 1)
        activity.advanceApproach(&next, input: FlightInput(throttle: 1), dt: 1)
        XCTAssertEqual(next.velocity, .zero)
        activity.takeOff(&next, cruiseSpeed: 100)
        XCTAssertFalse(activity.landed)
        XCTAssertGreaterThan(next.position.y, 300)
        XCTAssertEqual(simd_length(next.velocity), 100, accuracy: 0.01)
    }
    func testMissionsRequireOutpostAndDeliveryLanding() {
        var activity = FreeRoamActivities()
        XCTAssertFalse(activity.start(.survey, at: .zero))
        XCTAssertTrue(activity.start(.survey, at: FreeRoamSector.missions.center))
        for point in FreeRoamMission.survey.waypoints {
            XCTAssertTrue(activity.advanceMission(from: point + SIMD3<Float>(0, 0, 250), to: point - SIMD3<Float>(0, 0, 250)))
        }
        XCTAssertNil(activity.mission)
        XCTAssertEqual(activity.completedMissions, 1)
        XCTAssertTrue(activity.start(.delivery, at: FreeRoamSector.missions.center))
        for point in FreeRoamMission.delivery.waypoints { _ = activity.advanceMission(from: point, to: point) }
        XCTAssertNotNil(activity.mission)
        XCTAssertEqual(activity.completedMissions, 1)
        var old = FlightState(); old.position = [1500, 230, 1500]
        var next = old; next.position.y = 212; next.velocity = [0, -2, -10]
        XCTAssertEqual(activity.contact(from: old, to: &next, bodyRadius: 3), .landed)
        XCTAssertEqual(activity.completedMissions, 2)
        XCTAssertNil(activity.mission)
        activity.cancelMission()
        XCTAssertNil(activity.missionTarget)
    }

    @MainActor
    func testHangarZoomIsSmoothBoundedAndResettable() {
        let orbit = HangarOrbitController()
        orbit.zoom(by: 0.8)
        XCTAssertEqual(orbit.distance, 34)
        orbit.advance(dt: 1.0 / 60)
        XCTAssertLessThan(orbit.distance, 34)
        XCTAssertGreaterThan(orbit.distance, 27.2)
        for _ in 0..<100 { orbit.zoom(by: 0.5); orbit.advance(dt: 0.05) }
        XCTAssertEqual(orbit.distance, 18, accuracy: 0.01)
        orbit.reduceMotion = true; orbit.zoom(by: 100)
        XCTAssertEqual(orbit.distance, 44)
        orbit.resetZoom(); XCTAssertEqual(orbit.distance, 34)
    }
    func testSectionTransferAndClearedRunwayForEveryAircraft() {
        let terrain = TerrainGenerator(level: .freeRoam)
        for aircraft in AircraftType.allCases {
            var activity = FreeRoamActivities(); var state = FlightState()
            let throttle = activity.transfer(to: .landing, state: &state, terrain: terrain, aircraft: aircraft)
            XCTAssertEqual(throttle, 0.28)
            XCTAssertTrue(activity.approachAssist)
            XCTAssertNil(CollisionSystem(terrain: terrain, aircraft: aircraft).impact(from: state, to: state), aircraft.name)
            // Descend the full approach at safe speed with the real collision checks interleaved.
            let collision = CollisionSystem(terrain: terrain, aircraft: aircraft)
            var landed = false
            for _ in 0..<6000 {
                let old = state
                activity.advanceApproach(&state, input: FlightInput(pitch: -0.25, throttle: 0.28), dt: FlightPhysics.step)
                let result = activity.contact(from: old, to: &state, bodyRadius: aircraft.bodyRadius, probes: aircraft.collisionProbes)
                if result == .landed { landed = true; break }
                XCTAssertNotEqual(result, .hardImpact, aircraft.name)
                XCTAssertNil(collision.impact(from: old, to: state), aircraft.name)
            }
            XCTAssertTrue(landed, aircraft.name)
        }
        for sector in FreeRoamSector.allCases {
            var activity = FreeRoamActivities(); var state = FlightState()
            _ = activity.transfer(to: sector, state: &state, terrain: terrain, aircraft: .enterprise)
            XCTAssertEqual(FreeRoamSector.containing(state.position), sector)
            XCTAssertNil(CollisionSystem(terrain: terrain, aircraft: .enterprise).impact(from: state, to: state))
        }
        for z: Float in [350, 650, 1500, 2350, 2650] {
            XCTAssertEqual(terrain.height(x: 1500, z: z), 190, accuracy: 0.01)
        }
    }
    func testCombatMissionUsesSweptShotsDamageAndCompletesOnce() {
        var activity = FreeRoamActivities()
        XCTAssertTrue(activity.start(.patrol, at: FreeRoamSector.missions.center))
        var ship = FlightState(); ship.position = [1500, 750, -1500]
        var consumedCount = 0
        for _ in 0..<3 {
            for _ in 0..<3 {
                guard let enemy = activity.enemies.first else { break }
                let velocity = SIMD3<Float>(0, 0, -12000)
                let bolt = PlayerBolt(position: enemy.position + [0, 0, -50], velocity: velocity, damage: 8)
                let result = activity.advanceCombat(ship: ship, bolts: [bolt], dt: 0.01)
                consumedCount += result.consumed.count
            }
        }
        XCTAssertEqual(consumedCount, 9)
        XCTAssertEqual(activity.fightersDestroyed, 3)
        XCTAssertNil(activity.mission)
        XCTAssertEqual(activity.completedMissions, 1)
        XCTAssertTrue(activity.enemyBolts.isEmpty)
        _ = activity.advanceCombat(ship: ship, bolts: [], dt: 1)
        XCTAssertEqual(activity.completedMissions, 1)
    }

    private func isolatedDefaults() -> (UserDefaults, String) {
        let name = "AlpineFlightTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    func testEveryAircraftHasStableCruiseAndThrottleAuthority() {
        for aircraft in AircraftType.allCases {
            var cruise = FlightState(), idle = FlightState(), full = FlightState()
            cruise.velocity = [0, 0, -aircraft.cruiseSpeed]
            cruise.airspeed = aircraft.cruiseSpeed
            idle = cruise; full = cruise
            let physics = FlightPhysics(aircraft: aircraft)
            for _ in 0..<3600 {
                physics.advance(&cruise, input: FlightInput(), wind: .zero, dt: FlightPhysics.step)
                physics.advance(&idle, input: FlightInput(throttle: 0), wind: .zero, dt: FlightPhysics.step)
                physics.advance(&full, input: FlightInput(throttle: 1), wind: .zero, dt: FlightPhysics.step)
            }
            XCTAssertTrue(cruise.position.y.isFinite, aircraft.name)
            XCTAssertFalse(cruise.stalled, aircraft.name)
            XCTAssertLessThan(abs(cruise.position.y - 430), 130, aircraft.name)
            XCTAssertGreaterThan(cruise.airspeed, aircraft.cruiseSpeed * 0.8, aircraft.name)
            XCTAssertLessThan(cruise.airspeed, aircraft.cruiseSpeed * 1.6, aircraft.name)
            XCTAssertGreaterThan(full.airspeed, idle.airspeed, aircraft.name)
            if aircraft.isPodracer {
                XCTAssertEqual(full.position.y, idle.position.y, accuracy: 0.001, aircraft.name)
            } else {
                XCTAssertGreaterThan(full.position.y, idle.position.y, aircraft.name)
            }
        }
    }

    func testFighterRollsFasterThanPassengerJet() {
        var fighter = FlightState(), airliner = FlightState()
        fighter.velocity = [0, 0, -AircraftType.falcon.cruiseSpeed]
        airliner.velocity = [0, 0, -AircraftType.meridian.cruiseSpeed]
        for _ in 0..<60 {
            FlightPhysics(aircraft: .falcon).advance(&fighter, input: FlightInput(roll: 0.7), wind: .zero, dt: FlightPhysics.step)
            FlightPhysics(aircraft: .meridian).advance(&airliner, input: FlightInput(roll: 0.7), wind: .zero, dt: FlightPhysics.step)
        }
        XCTAssertGreaterThan(fighter.roll, airliner.roll * 2)
        XCTAssertGreaterThan(AircraftType.meridian.chaseOffset.z, AircraftType.kestrel.chaseOffset.z)
    }

    func testLargerWingsCanCollideWhereTrainerFits() {
        let terrain = TerrainGenerator(seed: FlightLevel.canyon.seed, level: .canyon)
        var state = FlightState()
        state.position = [terrain.valleyCenter(at: 0), terrain.surfaceHeight(x: terrain.valleyCenter(at: 0), z: 0) + 9, 0]
        state.roll = .pi / 2
        XCTAssertNil(CollisionSystem(terrain: terrain, aircraft: .kestrel).impact(from: state, to: state))
        XCTAssertNotNil(CollisionSystem(terrain: terrain, aircraft: .atlas).impact(from: state, to: state))
    }

    func testGatesAllowForActualWingspan() {
        let terrain = TerrainGenerator()
        var trainer = CheckpointSystem(terrain: terrain, aircraft: .kestrel)
        var airliner = CheckpointSystem(terrain: terrain, aircraft: .meridian)
        let gate = trainer.next!
        let edge = gate.position + SIMD3<Float>(gate.radius - 10, 0, 0)
        XCTAssertTrue(trainer.advance(from: edge + [0, 0, 10], to: edge + [0, 0, -10]))
        XCTAssertFalse(airliner.advance(from: edge + [0, 0, 10], to: edge + [0, 0, -10]))
    }

    func testEveryRouteHasDistinctTerrainAndCompleteableGates() {
        var heights = Set<Float>()
        for level in FlightLevel.allCases {
            let terrain = TerrainGenerator(seed: level.seed, level: level)
            heights.insert(terrain.height(x: 900, z: -2400))
            var route = CheckpointSystem(terrain: terrain, aircraft: .atlas)
            XCTAssertEqual(route.checkpoints.count, level.gateCount)
            if level.isFreeRoam {
                XCTAssertNil(route.next)
                XCTAssertFalse(route.complete)
                XCTAssertFalse(route.advance(from: [0, 500, 0], to: [0, 500, -1000]))
                continue
            }
            for _ in 0..<route.laps {
            for gate in route.checkpoints {
                let clearance = gate.position.y - terrain.surfaceHeight(x: gate.position.x, z: gate.position.z)
                XCTAssertGreaterThan(clearance, level.isPodRaceTrack ? 100 : gate.radius + 60)
                XCTAssertTrue(route.advance(from: gate.position - gate.normal * 20, to: gate.position + gate.normal * 20), level.name)
            }
            }
            XCTAssertTrue(route.complete)
            route.reset()
            XCTAssertEqual(route.next?.id, 0)
        }
        XCTAssertEqual(Set(FlightLevel.allCases.map(\.seed)).count, FlightLevel.allCases.count)
        XCTAssertEqual(FlightLevel.storm.next, .deathStar)
        XCTAssertEqual(FlightLevel.deathStar.next, .boontaEve)
        XCTAssertEqual(FlightLevel.endor.next, .skylands)
        XCTAssertEqual(FlightLevel.volcano.next, .storm)
        XCTAssertEqual(FlightLevel.boontaEve.next, .sentinelOne)
        XCTAssertEqual(FlightLevel.sentinelOne.next, .ordIbanna)
        XCTAssertEqual(FlightLevel.ordIbanna.next, .andoPrime)
        XCTAssertEqual(FlightLevel.andoPrime.next, .lantaana)
        XCTAssertEqual(FlightLevel.lantaana.next, .ordMantell)
        XCTAssertEqual(FlightLevel.ordMantell.next, .corellia)
        XCTAssertEqual(FlightLevel.corellia.next, .narShaddaa)
        XCTAssertEqual(FlightLevel.narShaddaa.next, .freeRoam)
        XCTAssertEqual(FlightLevel.allCases.filter(\.isPodRace).count, 8)
        XCTAssertNil(FlightLevel.freeRoam.next)
        XCTAssertEqual(FlightLevel.alpine.next, .canyon)
    }

    func testPodRaceRoutesAreFlatterAndUseHighClearanceArchGates() {
        for level in FlightLevel.allCases where level.isPodRaceTrack {
            let terrain = TerrainGenerator(seed: level.seed, level: level)
            let circuit = RaceCircuit(level: level)
            for d in stride(from: Float(0), to: circuit.length, by: 80) {
                let p = circuit.point(at: d)
                XCTAssertLessThan(terrain.surfaceHeight(x: p.x, z: p.z), 96, level.name)
            }

            let gate = CheckpointSystem(terrain: terrain, aircraft: .anakinPodracer).next!
            XCTAssertGreaterThan(gate.radius, level.gateRadius)
            XCTAssertGreaterThan(gate.position.y - terrain.surfaceHeight(x: gate.position.x, z: gate.position.z), 100)
        }
    }

    func testPodRaceCircuitsCloseAndReverseDirectionThroughBothHairpins() {
        for level in FlightLevel.allCases where level.isPodRaceTrack {
            let circuit = RaceCircuit(level: level)
            XCTAssertLessThan(simd_distance(circuit.point(at: 0), circuit.point(at: circuit.length)), 0.01)
            XCTAssertGreaterThan(simd_dot(circuit.tangent(at: 0), circuit.tangent(at: circuit.length)), 0.99)
            let incoming = circuit.tangent(at: circuit.straight - 10)
            let outgoing = circuit.tangent(at: circuit.straight + .pi * circuit.radius + 10)
            XCTAssertLessThan(simd_dot(incoming, outgoing), -0.99, "A real 180-degree reversal")
            let bottomIncoming = outgoing
            let bottomOutgoing = circuit.tangent(at: circuit.length + 10)
            XCTAssertLessThan(simd_dot(bottomIncoming, bottomOutgoing), -0.99)
            for d in stride(from: Float(50), to: circuit.length - 50, by: 170) {
                XCTAssertEqual(circuit.projection(circuit.point(at: d)).distance, d, accuracy: 0.1)
            }
            let leftStraightXs = stride(from: circuit.straight * 0.05, through: circuit.straight * 0.95, by: circuit.straight * 0.015).map {
                circuit.point(at: $0).x
            }
            XCTAssertGreaterThan((leftStraightXs.max() ?? 0) - (leftStraightXs.min() ?? 0), circuit.chicaneAmplitude)
            var directionChanges = 0
            var previousSign: Float = 0
            for index in 1..<leftStraightXs.count {
                let sign: Float = leftStraightXs[index] - leftStraightXs[index - 1] >= 0 ? 1 : -1
                if previousSign != 0, sign != previousSign { directionChanges += 1 }
                previousSign = sign
            }
            XCTAssertGreaterThanOrEqual(directionChanges, circuit.chicaneCount * 2 - 2, level.name)
        }
    }

    func testRacePositionSkipsNonRacingLevels() {
        for level in FlightLevel.allCases where !level.isPodRace {
            let terrain = TerrainGenerator(seed: level.seed, level: level)
            let race = PodRaceManager(terrain: terrain, aircraft: .kestrel)
            XCTAssertEqual(race.position(for: [100, 500, -1000], passed: 0), 1, level.name)
        }
    }

    func testPerformanceModeDefaultsAndPersists() {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        var settings = GameSettings(defaults: defaults)
        XCTAssertTrue(settings.performanceMode)
        XCTAssertTrue(settings.terrainReducedDetail)
        XCTAssertEqual(settings.flightFramesPerSecond, 30)
        settings.performanceMode = false
        settings.reducedDetail = false
        settings.save(defaults: defaults)
        let restored = GameSettings(defaults: defaults)
        XCTAssertFalse(restored.performanceMode)
        XCTAssertFalse(restored.terrainReducedDetail)
        XCTAssertEqual(restored.flightFramesPerSecond, 60)
        settings.reducedDetail = true
        XCTAssertTrue(settings.terrainReducedDetail)
    }

    func testCircuitRequiresThreeOrderedLapsAndRejectsWrongWayCrossings() {
        let terrain = TerrainGenerator(level: .boontaEve)
        var checkpoints = CheckpointSystem(terrain: terrain, aircraft: .anakinPodracer)
        for lap in 1...3 {
            XCTAssertEqual(checkpoints.currentLap, lap)
            for gate in checkpoints.checkpoints {
                XCTAssertFalse(checkpoints.advance(from: gate.position + gate.normal * 20, to: gate.position - gate.normal * 20))
                XCTAssertTrue(checkpoints.advance(from: gate.position - gate.normal * 20, to: gate.position + gate.normal * 20))
            }
            XCTAssertEqual(checkpoints.complete, lap == 3)
        }
    }

    func testPodRacesProvideBoostPadsAndShootableRivals() {
        let terrain = TerrainGenerator(seed: FlightLevel.boontaEve.seed, level: .boontaEve)
        var race = PodRaceManager(terrain: terrain, aircraft: .anakinPodracer)
        XCTAssertTrue(FlightLevel.boontaEve.isPodRace)
        XCTAssertEqual(race.opponents.count, 6)
        XCTAssertEqual(race.pads.count, 3)
        _ = race.advance(position: [0, 500, 0], requestedBoost: true, dt: 1)
        XCTAssertLessThan(race.boostCharge, 100)
        let pickup = race.pads[0]
        _ = race.advance(position: pickup.position, requestedBoost: false, dt: 0.01)
        XCTAssertGreaterThan(race.boostCharge, 90)
        let rival = race.opponents[0]
        let bolt = PlayerBolt(position: rival.position, velocity: .zero, damage: 12)
        for _ in 0..<5 { XCTAssertEqual(race.resolvePlayerFire([bolt],dt:0.01),[0]) }
        XCTAssertFalse(race.opponents[0].active)
    }

    func testCollisionSurfaceMatchesAllLevelMeshes() {
        for level in FlightLevel.allCases {
            let terrain = TerrainGenerator(seed: level.seed, level: level)
            let mesh = terrain.mesh(key: TileKey(x: 0, z: -5), divisions: 24)
            for face in stride(from: 0, to: 24 * 24 * 2, by: 31) {
                let point = mesh.positions[face * 3] * 0.2 + mesh.positions[face * 3 + 1] * 0.3 + mesh.positions[face * 3 + 2] * 0.5
                XCTAssertEqual(terrain.surfaceHeight(x: point.x, z: point.z), point.y, accuracy: 0.01)
            }
        }
    }

    func testTerrainShadingHasContinuousFiniteNormalsAtTileEdges() {
        for level in FlightLevel.allCases {
            let terrain = TerrainGenerator(seed:level.seed,level:level)
            for divisions in [16,24] {
                let left = terrain.mesh(key:TileKey(x:0,z:-2),divisions:divisions)
                let right = terrain.mesh(key:TileKey(x:1,z:-2),divisions:divisions)
                let groundVertices = divisions*divisions*6
                var edge: [SIMD3<Float>:SIMD3<Float>] = [:]
                for i in 0..<groundVertices {
                    let normal = left.normals[i]
                    XCTAssertTrue(normal.x.isFinite && normal.y.isFinite && normal.z.isFinite)
                    XCTAssertEqual(simd_length(normal),1,accuracy:0.0001)
                    if left.positions[i].x == 600 { edge[left.positions[i]] = normal }
                }
                XCTAssertFalse(edge.isEmpty)
                for i in 0..<groundVertices where right.positions[i].x == 600 {
                    XCTAssertLessThan(simd_distance(edge[right.positions[i]] ?? .zero,right.normals[i]),0.0001,level.name)
                }
            }
        }
    }

    func testProgressIsStoredPerRouteAndMigratesOriginalBest() {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(3, forKey: "bestGates")
        let progress = FlightProgress(defaults: defaults)
        XCTAssertEqual(progress.best(for: .alpine), 3)
        XCTAssertEqual(progress.best(for: .storm), 0)
        progress.record(gates: 5, for: .canyon)
        progress.record(gates: 2, for: .canyon)
        progress.record(gates: 90, for: .storm)
        XCTAssertEqual(FlightProgress(defaults: defaults).best(for: .canyon), 5)
        XCTAssertEqual(progress.best(for: .alpine), 3)
        XCTAssertEqual(progress.best(for: .glacier), 0)
        XCTAssertEqual(progress.best(for: .storm), 7)
    }

    func testAircraftAndLevelPreferencesPersistAndInvalidIDsFallBack() {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        var settings = GameSettings(defaults: defaults)
        settings.aircraft = .meridian
        settings.level = .glacier
        settings.save(defaults: defaults)
        XCTAssertEqual(GameSettings(defaults: defaults).aircraft, .meridian)
        XCTAssertEqual(GameSettings(defaults: defaults).level, .glacier)
        defaults.set("retired-model", forKey: "aircraft")
        defaults.set("missing-level", forKey: "level")
        XCTAssertEqual(GameSettings(defaults: defaults).aircraft, .kestrel)
        XCTAssertEqual(GameSettings(defaults: defaults).level, .alpine)
    }

    @MainActor
    func testSelectionRebuildsRouteAndResetsFlight() {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let game = GameEngine(defaults: defaults)
        for level in FlightLevel.allCases {
            game.selectLevel(level)
            for aircraft in AircraftType.allCases.filter({ $0.blueprintRequirement == 0 }) {
                game.selectAircraft(aircraft)
                XCTAssertEqual(game.level, level)
                XCTAssertEqual(game.gateCount, level.gateCount * (level.isPodRaceTrack ? 3 : 1))
                XCTAssertEqual(game.hud.passed, 0)
                if level == .deathStar {
                    XCTAssertEqual(game.hud.timeRemaining, game.deathStarTimeLimit)
                    XCTAssertGreaterThan(game.deathStarTimeLimit, level.routeLength / aircraft.cruiseSpeed)
                    XCTAssertEqual(game.hud.pursuers, 0)
                } else {
                    XCTAssertNil(game.hud.timeRemaining)
                }
                XCTAssertEqual(game.state.airspeed, aircraft.cruiseSpeed)
                XCTAssertEqual(simd_length(game.state.velocity), aircraft.cruiseSpeed, accuracy: 0.01)
                XCTAssertGreaterThan(CollisionSystem(terrain: game.terrain, aircraft: aircraft).clearance(at: game.state.position), level.isPodRace ? 100 : 200)
                if level.isFreeRoam {
                    XCTAssertEqual(game.gateCount, 0)
                    XCTAssertTrue(SpaceChallenge.allCases.map(\.name).contains(game.hud.checkpointName))
                    XCTAssertFalse(game.hud.inSpace)
                    XCTAssertFalse(game.hud.inHyperspace)
                    XCTAssertGreaterThan(game.hud.checkpointDistance, 300)
                    XCTAssertFalse(CheckpointSystem(terrain: game.terrain, aircraft: aircraft).complete)
                }
                XCTAssertFalse(game.ready) // No renderer attached: never start over an unloaded world.
                game.start()
                XCTAssertEqual(game.phase, .title)
            }
        }
    }

    @MainActor
    func testAircraftModelsHaveDistinctDimensionsAndExpectedFeatures() {
        for type in AircraftType.allCases {
            let model = AircraftFactory.make(type: type, color: .white)
            let bounds = model.visualBounds(relativeTo: model)
            XCTAssertGreaterThan(bounds.extents.x, type.wingspan * 0.9, type.name)
            XCTAssertGreaterThan(bounds.extents.z, type.length * 0.8, type.name)
            XCTAssertNotNil(AircraftFactory.blenderAssetURL(for:type),type.name)
            XCTAssertNotNil(model.findEntity(named:"Blender model"),type.name)
            XCTAssertFalse(model.children.isEmpty, type.name)
            if type.isPodracer {
                let energy = model.findEntity(named: "podracer energy field")
                XCTAssertNotNil(energy, type.name)
            }
        }
    }

    @MainActor
    func testBlueprintBlenderModelsKeepDetailInABatchedRuntimeMesh() throws {
        for type in AircraftType.allCases {
            let ship = AircraftFactory.make(type:type,color:.white)
            XCTAssertNotNil(ship.findEntity(named:"DetailedHull"),type.name)
            var meshes = 0
            var materials: [any RealityKit.Material] = []
            func inspect(_ entity:Entity) {
                if let component = (entity as? ModelEntity)?.model {
                    meshes += 1
                    materials.append(contentsOf:component.materials)
                }
                for child in entity.children { inspect(child) }
            }
            inspect(ship)
            XCTAssertGreaterThan(meshes,0,type.name)
            XCTAssertLessThanOrEqual(meshes,12,"Static detailing should be batched: " + type.name)
            XCTAssertTrue(materials.contains { $0 is PhysicallyBasedMaterial },type.name)
            if [.tieInterceptor,.slaveI,.scimitar].contains(type) {
                let effect = EngineEffects(on:ship,type:type)
                XCTAssertEqual(effect.root.children.count,2)
                XCTAssertNotNil(ship.findEntity(named:"EngineNozzle_"+(type == .tieInterceptor ? "TwinIonDrive" : type == .slaveI ? "PatrolDrive" : "SithIonDrive")))
            }
            let front = try XCTUnwrap(ship.findEntity(named:"FlightForward"))
            let rear = try XCTUnwrap(ship.findEntity(named:"FlightRear"))
            XCTAssertLessThan(front.position(relativeTo:ship).z,rear.position(relativeTo:ship).z,type.name)
        }
    }

    func testSceneryKeepsCheckpointsRacingLinesAndPortalArrivalsClear() {
        for level in FlightLevel.allCases {
            let terrain = TerrainGenerator(seed:level.seed,level:level)
            let scenery = ScenicRegion(terrain:terrain)
            XCTAssertFalse(scenery.solids.isEmpty,level.name)
            let targets = level.isFreeRoam ? HyperspaceManager(terrain:terrain).portals.map(\.position) : CheckpointSystem(terrain:terrain).checkpoints.map(\.position)
            for target in targets {
                for type in AircraftType.allCases {
                    for probe in type.collisionProbes {
                        XCTAssertFalse(scenery.hits(target+probe),"\(level.name): scenery blocks \(type.name) arrival")
                    }
                }
            }
            if level.isPodRace {
                let circuit = RaceCircuit(level:level)
                for i in 0..<240 {
                    let point = circuit.point(at:Float(i)/240*circuit.length)
                    XCTAssertFalse(scenery.hits(point),level.name)
                }
            }
        }
    }

    @MainActor
    func testSceneryUsesTheVisibleSolidsForSweptCollisionAndBatches() throws {
        for level in FlightLevel.allCases {
            let terrain = TerrainGenerator(seed:level.seed,level:level)
            let layout = ScenicRegion(terrain:terrain)
            let collision = CollisionSystem(terrain:terrain)
            let root = try ScenicRegionRenderer.make(layout,level:level)
            XCTAssertLessThanOrEqual(root.children.count,7,level.name)
            for solid in layout.solids.filter(\.collidable).prefix(12) {
                XCTAssertTrue(layout.hits(solid.center),level.name)
                var before = FlightState(), after = FlightState()
                before.position = solid.center + [0,0,-solid.size.z]
                after.position = solid.center + [0,0,solid.size.z]
                XCTAssertNotNil(collision.impact(from:before,to:after),level.name)
            }
            // Compare the acceleration structure with direct geometry queries near narrow tops.
            for solid in layout.solids.filter(\.collidable).prefix(40) {
                for offset: SIMD3<Float> in [[0,0,0],[0,solid.size.y*0.45,0],[solid.size.x*0.49,solid.size.y*0.45,0]] {
                    let point = solid.center + offset
                    let expected = layout.solids.contains { $0.collidable && $0.contains(point) }
                    XCTAssertEqual(layout.hits(point),expected,level.name)
                }
            }
        }
    }

    @MainActor
    func testPlanetSceneryIsPreparedAndDetailModeBoundsItsCost() {
        for planet in SpacePlanet.allCases {
            var costs: [Int] = []
            for reduced in [true,false] {
                let renderer = PlanetSurfaceRenderer(planet:planet,reducedDetail:reduced)
                XCTAssertFalse(renderer.root.isEnabled)
                XCTAssertNotNil(renderer.root.findEntity(named:"Planet atmosphere"))
                XCTAssertNotNil(renderer.root.findEntity(named:"District 0"))
                var triangles = 0, entities = 0
                func inspect(_ entity:Entity) {
                    entities += 1
                    if let mesh = (entity as? ModelEntity)?.model?.mesh {
                        for model in mesh.contents.models {
                            for part in model.parts { triangles += (part.triangleIndices?.count ?? 0)/3 }
                        }
                    }
                    for child in entity.children { inspect(child) }
                }
                inspect(renderer.root)
                print("SCENIC_COST \(planet.rawValue) reduced=\(reduced) triangles=\(triangles) entities=\(entities)")
                XCTAssertLessThan(triangles,700000,planet.name)
                XCTAssertLessThan(entities,100,planet.name)
                costs.append(triangles)
            }
            XCTAssertLessThan(costs[0],costs[1],planet.name)
        }
    }

    @MainActor
    func testAsteroidDetailStaysInsideThePhysicsEnvelope() {
        var fingerprints = Set<String>()
        for variant in 0..<6 {
            let mesh = SpaceScenery.asteroidMesh(variant:variant)
            var positions: [SIMD3<Float>] = []
            for model in mesh.contents.models {
                for part in model.parts { positions += Array(part.positions) }
            }
            XCTAssertFalse(positions.isEmpty)
            for p in positions {
                XCTAssertTrue(p.x.isFinite && p.y.isFinite && p.z.isFinite)
                XCTAssertLessThanOrEqual(simd_length(p),1.00001)
                XCTAssertGreaterThan(simd_length(p),0.5)
            }
            fingerprints.insert(positions.prefix(12).map { String(describing:$0) }.joined())
        }
        XCTAssertEqual(fingerprints.count,6)
    }

    @MainActor
    func testVoltwingLoadsTheBlenderUSDZHierarchy() {
        let model = AircraftFactory.make(type: .voltwingPodracer, color: .white)
        XCTAssertNotNil(model.findEntity(named: "CockpitPod"))
        XCTAssertNotNil(model.findEntity(named: "LeftEngine"))
        XCTAssertNotNil(model.findEntity(named: "RightEngine"))
        XCTAssertNotNil(model.findEntity(named: "podracer energy field"))
    }

    func testArenaTimeLimitChoosesLessDamagedShipAndTiesDraw() {
        XCTAssertEqual(ArenaDuel.timeLimitOutcome(playerShield:70,enemyShield:40),.victory)
        XCTAssertEqual(ArenaDuel.timeLimitOutcome(playerShield:20,enemyShield:80),.defeat)
        XCTAssertEqual(ArenaDuel.timeLimitOutcome(playerShield:65,enemyShield:65),.draw)
    }

    func testArenaTimeoutUsesRemainingShieldsInSimulation() {
        var (duel,player) = readyArena()
        for step in 0..<1501 {
            // Stay opposite the rival so this test isolates the timer from combat.
            let direction = simd_length(duel.enemyPosition) > 1 ? simd_normalize(duel.enemyPosition) : SIMD3<Float>(0,0,1)
            player.position = -direction*1300
            player.velocity = .zero
            let shots = step == 1400 ? [PlayerBolt(position:duel.enemyPosition,velocity:.zero,age:0.1,damage:40)] : []
            _ = duel.advance(from:player,player:&player,shots:shots,dt:0.1)
        }
        XCTAssertTrue(duel.snapshot.endedOnTime)
        XCTAssertEqual(duel.snapshot.outcome,.victory)
        XCTAssertGreaterThan(duel.snapshot.playerShield,duel.snapshot.enemyShield)
    }

    func testArenaAimAssistCorrectsSmallMissesButRequiresManualAim() {
        var state = FlightState(); state.position = .zero; state.heading = 0; state.pitch = 0; state.roll = 0
        var assisted = WeaponSystem()
        let near = SIMD3<Float>(20,0,-300)
        let corrected = assisted.update(state:state,aircraft:.xwing,firing:true,dt:0.01,aimTarget:near)
        XCTAssertGreaterThan(corrected[0].velocity.x,0)
        var unassisted = WeaponSystem()
        let normal = unassisted.update(state:state,aircraft:.xwing,firing:true,dt:0.01)
        XCTAssertEqual(normal[0].velocity.x,0,accuracy:0.0001)
        for target: SIMD3<Float> in [[300,0,0],[0,0,300],[100,0,-1000]] {
            var weapons = WeaponSystem()
            let shot = weapons.update(state:state,aircraft:.xwing,firing:true,dt:0.01,aimTarget:target)
            XCTAssertEqual(shot[0].velocity.x,0,accuracy:0.0001)
            XCTAssertLessThan(shot[0].velocity.z,0)
        }
    }

    func testArenaRewardAmountsMatchEachFormatAndDifficulty() {
        XCTAssertEqual(ArenaDifficulty.allCases.map { ArenaFormat.duel.victoryReward(for:$0) },[350,700,1400])
        XCTAssertEqual(ArenaDifficulty.allCases.map { ArenaFormat.trio.victoryReward(for:$0) },[950,1300,2000])
    }

    private func readyArenaBattle(_ format:ArenaFormat) -> (ArenaBattle,FlightState) {
        var battle = ArenaBattle(difficulty:.rookie,format:format)
        var player = ArenaDuel.playerStart(speed:90)
        for _ in 0..<32 { _ = battle.advance(from:player,player:&player,shots:[],dt:0.1) }
        return (battle,player)
    }

    func testTrioRequiresBothRivalsAndConsumesEachShotOnce() {
        var (battle,player) = readyArenaBattle(.trio)
        XCTAssertEqual(battle.pursuers.count,2)
        XCTAssertEqual(battle.snapshot.rivals.count,2)
        for eliminated in 0..<2 {
            let position = battle.pursuers[0].position
            let shots = (0..<3).map { _ in PlayerBolt(position:position,velocity:.zero,age:0.1,damage:40) }
            let result = battle.advance(from:player,player:&player,shots:shots,dt:0.1)
            XCTAssertEqual(result.consumed,[0,1,2])
            XCTAssertEqual(battle.pursuers.count,1-eliminated)
            if eliminated == 0 { XCTAssertNil(battle.snapshot.outcome) }
        }
        XCTAssertEqual(battle.snapshot.outcome,.victory)
        XCTAssertEqual(battle.snapshot.hits,6)
        XCTAssertTrue(battle.bolts.isEmpty)
        let health = battle.snapshot.playerShield
        _ = battle.advance(from:player,player:&player,shots:[],dt:0.1)
        XCTAssertEqual(battle.snapshot.playerShield,health)
    }

    func testTrioTimerComparesStrongestSurvivingRival() {
        var (battle,player) = readyArenaBattle(.trio)
        let positions: [SIMD3<Float>] = [[1300,0,0],[-1300,0,0],[0,1300,0],[0,-1300,0],[0,0,1300],[0,0,-1300]]
        for step in 0..<1501 {
            player.position = positions.max { first,second in
                let rivals = battle.pursuers
                return (rivals.map { simd_distance(first,$0.position) }.min() ?? 0) < (rivals.map { simd_distance(second,$0.position) }.min() ?? 0)
            }!
            player.velocity = .zero
            let shots = step == 1400 ? [PlayerBolt(position:battle.pursuers[0].position,velocity:.zero,age:0.1,damage:40)] : []
            _ = battle.advance(from:player,player:&player,shots:shots,dt:0.1)
        }
        XCTAssertTrue(battle.snapshot.endedOnTime)
        XCTAssertEqual(battle.snapshot.outcome,.draw)
        XCTAssertEqual(battle.snapshot.playerShield,100)
        XCTAssertEqual(battle.snapshot.rivals.map(\.shield).max(),100)
        XCTAssertLessThan(battle.snapshot.rivals.map(\.shield).min() ?? 100,100)
    }

    func testArenaVictoryRewardsPersistAndCannotPayTwice() throws {
        let suite = "arena-prize-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName:suite))
        defer { defaults.removePersistentDomain(forName:suite) }
        for format in ArenaFormat.allCases {
            for difficulty in ArenaDifficulty.allCases {
                var wallet = FlightEconomy.load(from:defaults)
                let before = wallet.quarterCredits
                let match = UUID()
                let amount = format.victoryReward(for:difficulty)
                XCTAssertEqual(wallet.claimArena(id:match,format:format,difficulty:difficulty,outcome:.victory),amount)
                XCTAssertEqual(wallet.quarterCredits,before+amount*4)
                wallet.save(to:defaults)
                var reloaded = FlightEconomy.load(from:defaults)
                XCTAssertEqual(reloaded.claimArena(id:match,format:format,difficulty:difficulty,outcome:.victory),0)
                XCTAssertEqual(reloaded.quarterCredits,before+amount*4)
                for outcome: ArenaOutcome? in [.defeat,.draw,nil] {
                    XCTAssertEqual(reloaded.claimArena(id:UUID(),format:format,difficulty:difficulty,outcome:outcome),0)
                }
            }
        }
    }

    func testArenaOldWalletKeepsCreditsWhenPrizeReceiptsAreAbsent() throws {
        var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:1278)
        let data = try JSONEncoder().encode(wallet)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        json.removeValue(forKey:"arenaReceipts")
        var old = try JSONDecoder().decode(FlightEconomy.self,from:JSONSerialization.data(withJSONObject:json))
        XCTAssertEqual(old.quarterCredits,1278)
        XCTAssertEqual(old.claimArena(id:UUID(),format:.duel,difficulty:.rookie,outcome:.victory),350)
        XCTAssertEqual(old.quarterCredits,2678)
    }

    @MainActor
    func testPlayerSaveRoundTripKeepsCreditsReceiptsAndDeviceControls() throws {
        let a = "save-source-\(UUID().uuidString)", b = "save-dest-\(UUID().uuidString)"
        let source = try XCTUnwrap(UserDefaults(suiteName:a)), destination = try XCTUnwrap(UserDefaults(suiteName:b))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { source.removePersistentDomain(forName:a); destination.removePersistentDomain(forName:b); try? FileManager.default.removeItem(at:root) }
        var wallet = FlightEconomy(); let receipt = UUID()
        _ = wallet.claimArena(id:receipt,format:.trio,difficulty:.ace,outcome:.victory); wallet.save(to:source)
        source.set("xwing",forKey:"aircraft"); source.set(3,forKey:"bestGates.alpine")
        source.set("never-copy",forKey:"test-auth-token"); source.set(true,forKey:"handControl")
        destination.set(false,forKey:"handControl"); destination.set(true,forKey:"performanceMode")
        let archive = try PlayerSaveArchive.capture(defaults:source,creationsURL:root.appendingPathComponent("source"))
        XCTAssertFalse(archive.preferences.keys.contains("test-auth-token")); XCTAssertFalse(archive.preferences.keys.contains("handControl"))
        let decoded = try JSONDecoder().decode(PlayerSaveArchive.self,from:archive.encoded())
        try decoded.restore(defaults:destination,creationsURL:root.appendingPathComponent("destination"))
        var restored = FlightEconomy.load(from:destination)
        XCTAssertEqual(restored.quarterCredits,8000)
        XCTAssertEqual(restored.claimArena(id:receipt,format:.trio,difficulty:.ace,outcome:.victory),0)
        XCTAssertEqual(destination.string(forKey:"aircraft"),"xwing")
        XCTAssertEqual(destination.integer(forKey:"bestGates.alpine"),3)
        XCTAssertFalse(destination.bool(forKey:"handControl")); XCTAssertTrue(destination.bool(forKey:"performanceMode"))
        XCTAssertEqual(try archive.fingerprint(),try decoded.fingerprint())
    }

    func testInvalidCloudSaveCannotChangeDeviceProgress() throws {
        let name = "save-reject-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName:name)); defer { defaults.removePersistentDomain(forName:name) }
        var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:600); wallet.save(to:defaults)
        let before = defaults.data(forKey:FlightEconomy.key)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        var invalid = PlayerSaveArchive(); invalid.version = 9
        XCTAssertThrowsError(try invalid.restore(defaults:defaults,creationsURL:root))
        invalid.version = 1; invalid.creations["../escape.usdz"] = Data([1])
        XCTAssertThrowsError(try invalid.restore(defaults:defaults,creationsURL:root))
        invalid.creations = [:]; invalid.preferences[FlightEconomy.key] = .data(Data("broken".utf8))
        XCTAssertThrowsError(try invalid.restore(defaults:defaults,creationsURL:root))
        invalid.preferences = ["handControl":.flag(true)]
        XCTAssertThrowsError(try invalid.validated())
        XCTAssertEqual(defaults.data(forKey:FlightEconomy.key),before)
    }

    func testCloudSaveIncludesImportedModelsAndSelectedCreations() throws {
        let id = UUID(), level = CustomLevelDefinition()
        var archive = PlayerSaveArchive(); archive.customShipID = id; archive.customLevelID = level.id
        struct Library:Encodable { let ships:[CustomShip]; let levels:[CustomLevelDefinition] }
        archive.creations["library.json"] = try JSONEncoder().encode(Library(ships:[CustomShip(id:id,name:"My ship",handling:.xwing)],levels:[level]))
        archive.creations[id.uuidString+".usdz"] = Data([1,2,3])
        XCTAssertNoThrow(try archive.validated())
        archive.creations.removeValue(forKey:id.uuidString+".usdz")
        XCTAssertThrowsError(try archive.validated())
    }

    func testAccountConfigurationRejectsServiceRoleAndSecretKeys() {
        XCTAssertFalse(AccountConfiguration.isPublicKey("sb_secret_do_not_embed_123456789"))
        func key(_ role:String) -> String {
            let data = Data("{\"role\":\"\(role)\"}".utf8).base64EncodedString().replacingOccurrences(of:"=",with:"")
            return "header."+data+".signature"
        }
        XCTAssertFalse(AccountConfiguration.isPublicKey(key("service_role")))
        XCTAssertTrue(AccountConfiguration.isPublicKey(key("anon")))
        XCTAssertTrue(AccountConfiguration.isPublicKey("sb_publishable_public_test_configuration"))
    }

    @MainActor
    func testEmailVerificationSupportsDefaultLinksAndRejectsUntrustedActions() throws {
        let service = URL(string: "https://starflight-test.invalid")!
        let token = String(repeating: "a", count: 64)
        let link = "https://starflight-test.invalid/auth/v1/verify?token=\(token)&type=recovery&redirect_to=https://example.invalid"
        let body = try StarflightAccount.verificationBody(email: "pilot@example.invalid", input: link, type: "recovery", serviceURL: service)
        XCTAssertEqual(body["token_hash"], token)
        XCTAssertEqual(body["type"], "recovery")
        XCTAssertNil(body["email"])
        XCTAssertThrowsError(try StarflightAccount.verificationBody(email: "pilot@example.invalid", input: link.replacingOccurrences(of: "type=recovery", with: "type=signup"), type: "recovery", serviceURL: service))
        XCTAssertThrowsError(try StarflightAccount.verificationBody(email: "pilot@example.invalid", input: link.replacingOccurrences(of: "starflight-test.invalid", with: "untrusted.invalid"), type: "recovery", serviceURL: service))
        let code = try StarflightAccount.verificationBody(email: "pilot@example.invalid", input: "12345678", type: "recovery", serviceURL: service)
        XCTAssertEqual(code["token"], "12345678")
    }

    @MainActor
    func testDefaultRecoveryLinkVerifiesSessionAndUpdatesPassword() async throws {
        let sessionConfig = URLSessionConfiguration.ephemeral; sessionConfig.protocolClasses = [AccountTestHTTP.self]
        let transport = URLSession(configuration: sessionConfig)
        defer { transport.invalidateAndCancel(); AccountTestHTTP.handler = nil }
        let user = UUID(), store = AccountTestSessionStore()
        var requests: [String] = []
        AccountTestHTTP.handler = { request in
            let path = request.url!.path; requests.append(request.httpMethod! + " " + path)
            if path.hasSuffix("/recover") { return (200, Data("{}".utf8)) }
            if path.hasSuffix("/verify") {
                return (200, try JSONSerialization.data(withJSONObject: ["access_token":"test-access", "refresh_token":"test-refresh", "expires_in":3600, "user":["id":user.uuidString, "email":"pilot@example.invalid"]]))
            }
            if path.hasSuffix("/user") {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access")
                return (200, Data("{}".utf8))
            }
            throw AccountError.message("Unexpected test endpoint")
        }
        let service = URL(string: "https://starflight-test.invalid")!
        let account = StarflightAccount(configuration: AccountConfiguration(url: service, publicKey: "sb_publishable_public_test_configuration"), transport: transport, restoreSession: false, credentialStore: store)
        await account.requestReset(email: "pilot@example.invalid")
        XCTAssertTrue(account.message.contains("without opening"))
        let link = service.absoluteString + "/auth/v1/verify?token=" + String(repeating: "b", count: 64) + "&type=recovery"
        await account.resetPassword(email: "pilot@example.invalid", code: link, password: "dummy-test-password")
        XCTAssertEqual(requests, ["POST /auth/v1/recover", "POST /auth/v1/verify", "PUT /auth/v1/user"])
        XCTAssertTrue(account.signedIn)
        XCTAssertTrue(account.message.hasPrefix("Password updated"))
        XCTAssertNotNil(store.data)
    }

    @MainActor
    func testRejectedRecoveryPasswordDoesNotReportSignedInOrStoreSession() async throws {
        let sessionConfig = URLSessionConfiguration.ephemeral; sessionConfig.protocolClasses = [AccountTestHTTP.self]
        let transport = URLSession(configuration: sessionConfig)
        defer { transport.invalidateAndCancel(); AccountTestHTTP.handler = nil }
        let user = UUID(), store = AccountTestSessionStore()
        AccountTestHTTP.handler = { request in
            if request.url!.path.hasSuffix("/verify") {
                return (200, try JSONSerialization.data(withJSONObject: ["access_token":"test-access", "refresh_token":"test-refresh", "expires_in":3600, "user":["id":user.uuidString, "email":"pilot@example.invalid"]]))
            }
            return (422, Data("{\"code\":422,\"error_code\":\"weak_password\",\"msg\":\"Password is too common\"}".utf8))
        }
        let service = URL(string: "https://starflight-test.invalid")!
        let account = StarflightAccount(configuration: AccountConfiguration(url: service, publicKey: "sb_publishable_public_test_configuration"), transport: transport, restoreSession: false, credentialStore: store)
        await account.resetPassword(email: "pilot@example.invalid", code: "12345678", password: "dummy-test-password")
        XCTAssertFalse(account.signedIn)
        XCTAssertNil(store.data)
        XCTAssertTrue(account.message.contains("fresh reset email"))
        XCTAssertFalse(account.message.hasPrefix("Password updated"))
    }

    @MainActor
    func testNumericServerErrorCodeKeepsUsefulLoginMessage() async throws {
        let sessionConfig = URLSessionConfiguration.ephemeral; sessionConfig.protocolClasses = [AccountTestHTTP.self]
        let transport = URLSession(configuration: sessionConfig)
        defer { transport.invalidateAndCancel(); AccountTestHTTP.handler = nil }
        AccountTestHTTP.handler = { _ in (400, Data("{\"code\":400,\"error_code\":\"invalid_credentials\",\"msg\":\"Invalid login credentials\"}".utf8)) }
        let config = AccountConfiguration(url: URL(string: "https://starflight-test.invalid")!, publicKey: "sb_publishable_public_test_configuration")
        let account = StarflightAccount(configuration: config, transport: transport, restoreSession: false, credentialStore: AccountTestSessionStore())
        await account.signIn(email: "pilot@example.invalid", password: "dummy-test-password")
        XCTAssertFalse(account.signedIn)
        XCTAssertTrue(account.message.contains("Forgot password"))
        XCTAssertFalse(account.message.contains("failed (400)"))
    }

    @MainActor
    func testGuidedAccountSignupSupportsEmailLinksAndResend() async throws {
        let sessionConfig = URLSessionConfiguration.ephemeral; sessionConfig.protocolClasses = [AccountTestHTTP.self]
        let transport = URLSession(configuration: sessionConfig)
        defer { transport.invalidateAndCancel(); AccountTestHTTP.handler = nil }
        let store = AccountTestSessionStore(), user = UUID()
        var paths: [String] = []
        AccountTestHTTP.handler = { request in
            let path = request.url!.path; paths.append(path)
            let body = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] }
            // URLProtocol may expose the body as a stream, so endpoint assertions remain primary.
            if path.hasSuffix("/signup") { return (200, Data("{\"id\":\"pending\"}".utf8)) }
            if path.hasSuffix("/resend") { if let body { XCTAssertEqual(body["type"], "signup") }; return (200, Data("{}".utf8)) }
            if path.hasSuffix("/token") { return (200, try JSONSerialization.data(withJSONObject: ["access_token":"test-access", "refresh_token":"test-refresh", "expires_in":3600, "user":["id":user.uuidString, "email":"pilot@example.invalid"]])) }
            throw AccountError.message("Unexpected test endpoint")
        }
        let config = AccountConfiguration(url: URL(string: "https://starflight-test.invalid")!, publicKey: "sb_publishable_public_test_configuration")
        let account = StarflightAccount(configuration: config, transport: transport, restoreSession: false, credentialStore: store)
        await account.signUp(email: "bad email", password: "long-test-password")
        XCTAssertTrue(paths.isEmpty)
        await account.signUp(email: "pilot@example.invalid", password: "long-test-password")
        XCTAssertTrue(account.awaitingEmailConfirmation); XCTAssertFalse(account.signedIn)
        XCTAssertTrue(account.message.contains("tap Confirm")); XCTAssertFalse(account.message.contains("enter it below"))
        await account.resendConfirmation(email: "pilot@example.invalid")
        XCTAssertEqual(paths.last, "/auth/v1/resend")
        await account.signIn(email: "pilot@example.invalid", password: "long-test-password")
        XCTAssertTrue(account.signedIn); XCTAssertFalse(account.awaitingEmailConfirmation); XCTAssertNotNil(store.data)
    }

    @MainActor
    func testUnconfiguredEmailSenderExplainsRegistrationBlocker() async throws {
        let sessionConfig = URLSessionConfiguration.ephemeral; sessionConfig.protocolClasses = [AccountTestHTTP.self]
        let transport = URLSession(configuration: sessionConfig)
        defer { transport.invalidateAndCancel(); AccountTestHTTP.handler = nil }
        AccountTestHTTP.handler = { _ in (403, Data("{\"error_code\":\"email_address_not_authorized\",\"msg\":\"Email address not authorized\"}".utf8)) }
        let config = AccountConfiguration(url: URL(string: "https://starflight-test.invalid")!, publicKey: "sb_publishable_public_test_configuration")
        let account = StarflightAccount(configuration: config, transport: transport, restoreSession: false, credentialStore: AccountTestSessionStore())
        await account.signUp(email: "pilot@example.invalid", password: "long-test-password")
        XCTAssertFalse(account.signedIn); XCTAssertFalse(account.busy)
        XCTAssertTrue(account.message.contains("connect an email provider"))
    }

    func testIntroChoicePersistsAndOldSettingsDefaultToCanva() throws {
        let suite = "intro-choice-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        var settings = GameSettings(defaults: defaults)
        XCTAssertEqual(settings.introStyle, .canva)
        settings.introStyle = .starWars; settings.save(defaults: defaults)
        XCTAssertEqual(GameSettings(defaults: defaults).introStyle, .starWars)
    }

    @MainActor
    func testAccountLoginUsesSecureStoreAndSaveConflictRequiresChoice() async throws {
        let suite = "account-http-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName:suite)); defer { defaults.removePersistentDomain(forName:suite) }
        let user = UUID(), revision = UUID()
        let store = AccountTestSessionStore()
        let sessionConfig = URLSessionConfiguration.ephemeral; sessionConfig.protocolClasses = [AccountTestHTTP.self]
        let transport = URLSession(configuration:sessionConfig); defer { transport.invalidateAndCancel(); AccountTestHTTP.handler = nil }
        var requests = 0
        AccountTestHTTP.handler = { request in
            requests += 1
            XCTAssertEqual(request.url?.host,"starflight-test.invalid")
            let path = request.url!.path
            if path.hasSuffix("/token") {
                return (200,try JSONSerialization.data(withJSONObject:["access_token":"test-access","refresh_token":"test-refresh","expires_in":3600,"user":["id":user.uuidString,"email":"pilot@example.invalid"]]))
            }
            XCTAssertEqual(request.value(forHTTPHeaderField:"Authorization"),"Bearer test-access")
            if path.hasSuffix("/player_saves") {
                return (200,try JSONSerialization.data(withJSONObject:[["revision":revision.uuidString,"object_path":user.uuidString.lowercased()+"/"+UUID().uuidString.lowercased()+".json","updated_at":"2026-10-25T12:00:00Z"]]))
            }
            if path.contains("/storage/v1/object/") { return (200,Data("{}".utf8)) }
            if path.hasSuffix("/commit_player_save") { return (200,Data("[]".utf8)) }
            throw AccountError.message("Unexpected mock request")
        }
        let config = AccountConfiguration(url:URL(string:"https://starflight-test.invalid")!,publicKey:"sb_publishable_public_test_configuration")
        let account = StarflightAccount(defaults:defaults,configuration:config,transport:transport,restoreSession:false,credentialStore:store)
        await account.signIn(email:"pilot@example.invalid",password:"test-password-do-not-use")
        XCTAssertTrue(account.signedIn); XCTAssertNotNil(store.data)
        XCTAssertFalse(defaults.dictionaryRepresentation().values.contains { ($0 as? String)?.contains("test-password") == true })
        await account.checkOnlineSave()
        XCTAssertTrue(account.needsSaveChoice)
        let archive = PlayerSaveArchive()
        let before = requests
        await account.autoSave(archive)
        XCTAssertEqual(requests,before)
        await account.upload(archive)
        XCTAssertFalse(account.hasCheckedSave)
        XCTAssertTrue(account.needsSaveChoice)
        XCTAssertTrue(account.message.contains("Another device"))
        XCTAssertNil(defaults.string(forKey:"starflight.account.last-save"))
        account.signOut()
        XCTAssertFalse(account.signedIn); XCTAssertNil(store.data)
    }

    @MainActor
    func testUnconfiguredAccountsNeverContactNetwork() async {
        let account = StarflightAccount(configuration:nil,restoreSession:false)
        await account.signIn(email:"nobody@example.invalid",password:"not-a-real-password")
        XCTAssertFalse(account.configured); XCTAssertFalse(account.signedIn)
        XCTAssertTrue(account.message.contains("aren’t available"))
    }

    private func readyArena(_ difficulty: ArenaDifficulty = .pilot) -> (ArenaDuel, FlightState) {
        var duel = ArenaDuel(difficulty:difficulty)
        var player = ArenaDuel.playerStart(speed:90)
        for _ in 0..<32 { _ = duel.advance(from:player,player:&player,shots:[],dt:0.1) }
        return (duel,player)
    }

    func testArenaCountdownDoesNotFireOrSpendMatchTime() {
        var duel = ArenaDuel()
        var player = ArenaDuel.playerStart(speed:90)
        for _ in 0..<20 { _ = duel.advance(from:player,player:&player,shots:[],dt:0.1) }
        XCTAssertGreaterThan(duel.snapshot.countdown,0)
        XCTAssertEqual(duel.snapshot.remaining,150)
        XCTAssertTrue(duel.bolts.isEmpty)
        XCTAssertEqual(duel.snapshot.playerShield,100)
    }

    func testArenaSweptFireHitsAndEndsOnceWithoutFurtherDamage() {
        var (duel,player) = readyArena()
        let shot = PlayerBolt(position:duel.enemyPosition+[120,0,0],velocity:[2400,0,0],age:0.1,damage:40)
        let hit = duel.advance(from:player,player:&player,shots:[shot],dt:0.1)
        XCTAssertEqual(hit.consumed,[0])
        XCTAssertEqual(duel.snapshot.enemyShield,60,accuracy:0.01)
        for _ in 0..<2 {
            let shot = PlayerBolt(position:duel.enemyPosition,velocity:.zero,age:0.1,damage:40)
            _ = duel.advance(from:player,player:&player,shots:[shot],dt:0.1)
        }
        XCTAssertEqual(duel.snapshot.outcome,.victory)
        let health = duel.snapshot.playerShield
        _ = duel.advance(from:player,player:&player,shots:[],dt:0.1)
        XCTAssertEqual(duel.snapshot.playerShield,health)
        XCTAssertTrue(duel.bolts.isEmpty)
    }

    func testArenaThreatTriggersDefensiveBreak() {
        var (duel,player) = readyArena()
        // A bolt closing on the rival within its prediction horizon.
        for _ in 0..<4 {
            let shot = PlayerBolt(position:duel.enemyPosition+[100,0,0],velocity:[-300,0,0],age:0.1,damage:8)
            _ = duel.advance(from:player,player:&player,shots:[shot],dt:0.1)
        }
        XCTAssertEqual(duel.snapshot.tactic,.evade)
    }

    func testArenaRecoversWhenDamagedThenReturnsToAttack() {
        var (duel,player) = readyArena()
        let shot = PlayerBolt(position:duel.enemyPosition,velocity:.zero,age:0.1,damage:40)
        _ = duel.advance(from:player,player:&player,shots:[shot,shot],dt:0.1)
        XCTAssertEqual(duel.snapshot.enemyShield,20,accuracy:0.01)
        for _ in 0..<10 { _ = duel.advance(from:player,player:&player,shots:[],dt:0.1) }
        XCTAssertEqual(duel.snapshot.tactic,.recover)
        for _ in 0..<45 { _ = duel.advance(from:player,player:&player,shots:[],dt:0.1) }
        XCTAssertGreaterThan(duel.snapshot.enemyShield,20)
        XCTAssertNotEqual(duel.snapshot.tactic,.recover)
    }

    func testArenaBoundaryReflectsOutwardFlightAndKeepsPlayerInside() {
        var (duel,player) = readyArena()
        player.position = [ArenaDuel.radius+40,0,0]; player.velocity = [120,0,0]
        _ = duel.advance(from:player,player:&player,shots:[],dt:0.1)
        XCTAssertTrue(duel.snapshot.boundary)
        XCTAssertLessThan(simd_length(player.position),ArenaDuel.radius)
        XCTAssertLessThan(player.velocity.x,0)
        XCTAssertLessThan(player.forward.x,0)
    }

    func testArenaAIIsDeterministicAndCanDamageAnIdlePilot() {
        var (first,p1) = readyArena(.ace)
        var (second,p2) = readyArena(.ace)
        var fired = false
        for _ in 0..<300 {
            fired = first.advance(from:p1,player:&p1,shots:[],dt:0.1).fired || fired
            _ = second.advance(from:p2,player:&p2,shots:[],dt:0.1)
        }
        XCTAssertTrue(fired)
        XCTAssertLessThan(first.snapshot.playerShield,100)
        XCTAssertEqual(first.enemyPosition,second.enemyPosition)
        XCTAssertEqual(first.snapshot.playerShield,second.snapshot.playerShield)
        XCTAssertLessThanOrEqual(simd_length(first.enemyPosition),ArenaDuel.radius+0.01)
    }

    func testArenaRematchStartsFresh() {
        var (duel,player) = readyArena()
        let shot = PlayerBolt(position:duel.enemyPosition,velocity:.zero,age:0.1,damage:40)
        _ = duel.advance(from:player,player:&player,shots:[shot],dt:0.1)
        duel = ArenaDuel(difficulty:.rookie)
        XCTAssertEqual(duel.snapshot.playerShield,100)
        XCTAssertEqual(duel.snapshot.enemyShield,100)
        XCTAssertEqual(duel.snapshot.countdown,3)
        XCTAssertNil(duel.snapshot.outcome)
        XCTAssertTrue(duel.bolts.isEmpty)
    }

    @MainActor
    func testArenaSelectionClearsForOrdinaryFlights() throws {
        let suite = "arena-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName:suite))
        defer { defaults.removePersistentDomain(forName:suite) }
        let engine = GameEngine(defaults:defaults)
        engine.selectArena(.rookie)
        XCTAssertTrue(engine.arenaSelected)
        XCTAssertEqual(engine.levelName,"Arena duel")
        engine.selectLevel(.alpine)
        XCTAssertFalse(engine.arenaSelected)
        engine.selectArena(.ace)
        engine.selectSpaceFreeRoam()
        XCTAssertFalse(engine.arenaSelected)
        engine.selectArena(.pilot)
        engine.selectCustomLevel(CustomLevelDefinition())
        XCTAssertFalse(engine.arenaSelected)
    }

    func testCustomTerrainRecipeChangesGroundAndKeepsGatesAboveIt() throws {
        var recipe = CustomLevelDefinition()
        recipe.seed = 42
        recipe.mountainScale = 1.8
        recipe.valleyWidth = 0.75
        recipe.bends = 1.6
        recipe.saddles = 1.3
        let custom = TerrainGenerator(seed: recipe.seed, level: .alpine, customLevel: try recipe.validated())
        XCTAssertNotEqual(custom.height(x: 700, z: -2300), TerrainGenerator().height(x: 700, z: -2300))
        let copy = try JSONDecoder().decode(CustomLevelDefinition.self, from: JSONEncoder().encode(recipe))
        XCTAssertEqual(copy, recipe)
        for gate in CheckpointSystem(terrain: custom).checkpoints {
            XCTAssertEqual(gate.position.x, custom.valleyCenter(at: gate.position.z), accuracy: 0.01)
            XCTAssertEqual(gate.position.y - custom.surfaceHeight(x: gate.position.x, z: gate.position.z), FlightLevel.alpine.gateClearance, accuracy: 0.01)
        }
    }

    func testEveryEditorTerrainLimitIsAccepted() throws {
        for upper in [false, true] {
            var recipe = CustomLevelDefinition()
            recipe.mountainScale = upper ? CustomLevelDefinition.mountainRange.upperBound : CustomLevelDefinition.mountainRange.lowerBound
            recipe.valleyWidth = upper ? CustomLevelDefinition.valleyRange.upperBound : CustomLevelDefinition.valleyRange.lowerBound
            recipe.bends = upper ? CustomLevelDefinition.bendRange.upperBound : CustomLevelDefinition.bendRange.lowerBound
            recipe.saddles = upper ? CustomLevelDefinition.saddleRange.upperBound : CustomLevelDefinition.saddleRange.lowerBound
            XCTAssertNoThrow(try recipe.validated())
        }
    }

    func testCustomTerrainRejectsUnsupportedOrUnsafeValues() throws {
        var invalid = CustomLevelDefinition()
        invalid.mountainScale = .nan
        XCTAssertThrowsError(try invalid.validated())
        invalid.mountainScale = 1
        invalid.valleyWidth = 0
        XCTAssertThrowsError(try invalid.validated())
        invalid.valleyWidth = 1
        invalid.formatVersion = 2
        XCTAssertThrowsError(try invalid.validated())
        let compact = Data(#"{"name":"My route","seed":123}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(CustomLevelDefinition.self, from: compact).validated().bends, 1)
    }

    @MainActor
    func testCreationsPersistAndImportedModelsStayInsideCollisionEnvelope() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = CustomContentStore(directory: directory)
        let level = try library.addLevel(CustomLevelDefinition())
        let url = try XCTUnwrap(AircraftFactory.blenderAssetURL(for: .xwing))
        let ship = try await library.importShip(from: url, handling: .xwing)
        let reloaded = CustomContentStore(directory: directory)
        XCTAssertNil(reloaded.loadError)
        XCTAssertEqual(reloaded.levels, [level])
        XCTAssertEqual(reloaded.ships, [ship])
        let model = AircraftFactory.make(type: .xwing, color: .white, customURL: reloaded.shipURL(ship))
        let bounds = model.visualBounds(relativeTo: model)
        XCTAssertLessThanOrEqual(bounds.extents.x, AircraftType.xwing.wingspan + 0.01)
        XCTAssertLessThanOrEqual(bounds.extents.y, AircraftType.xwing.bodyRadius * 2 + 0.01)
        XCTAssertLessThanOrEqual(bounds.extents.z, AircraftType.xwing.length + 0.01)
        XCTAssertLessThan(simd_length(bounds.center), 0.01)
    }

    @MainActor
    func testBuiltInSelectionClearsCustomContentEvenForSamePreset() throws {
        let suite = "custom-selection-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let engine = GameEngine(defaults: defaults)
        engine.selectCustomLevel(CustomLevelDefinition())
        XCTAssertNotNil(engine.customLevel)
        XCTAssertNil(engine.nextLevel)
        engine.selectLevel(.alpine)
        XCTAssertNil(engine.customLevel)
        let ship = CustomShip(id: UUID(), name: "Test craft", handling: .xwing)
        engine.selectCustomShip(ship)
        XCTAssertEqual(engine.aircraftName, "Test craft")
        engine.selectAircraft(.xwing)
        XCTAssertNil(engine.customShip)
    }

    @MainActor
    func testHangarDragRespondsWithinOneFrameAndGlideSettles() {
        let orbit = HangarOrbitController()
        let originalYaw = orbit.yaw
        orbit.begin(at: .zero, time: 1)
        orbit.drag(to: CGPoint(x: 100, y: 300), time: 1.05)
        // Input must not snap the displayed camera between render ticks.
        XCTAssertEqual(orbit.yaw, originalYaw, accuracy: 0.001)
        orbit.advance(dt: 1 / 60)
        XCTAssertLessThan(orbit.yaw, originalYaw - 0.2)
        XCTAssertGreaterThan(orbit.yaw, originalYaw - 1.1)
        XCTAssertGreaterThan(orbit.pitch, 0.23)
        orbit.end(time: 1.06)
        for _ in 0..<180 { orbit.advance(dt: 1 / 60) }
        let settled = orbit.yaw
        for _ in 0..<60 { orbit.advance(dt: 1 / 60) }
        XCTAssertEqual(orbit.yaw, settled, accuracy: 0.001)
        XCTAssertLessThanOrEqual(orbit.pitch, 0.65)
        XCTAssertEqual(simd_distance(orbit.cameraPosition, [0, 4, 0]), 34, accuracy: 0.01)
    }

    @MainActor
    func testHangarSmoothingConvergesEquallyAtDifferentFrameRates() {
        var angles: [Float] = []
        for fps in [30, 60, 120] {
            let orbit = HangarOrbitController()
            let initial = orbit.yaw
            orbit.begin(at: .zero, time: 1)
            orbit.drag(to: CGPoint(x: 100, y: 0), time: 1.05)
            var previous = initial
            for _ in 0..<(fps / 5) {
                orbit.advance(dt: 1 / Float(fps))
                XCTAssertLessThan(orbit.yaw, previous)
                XCTAssertGreaterThan(orbit.yaw, initial - 1.1)
                previous = orbit.yaw
            }
            XCTAssertEqual(orbit.yaw, initial - 1.1, accuracy: 0.02)
            angles.append(orbit.yaw)
        }
        XCTAssertEqual(angles[0], angles[2], accuracy: 0.001)
    }

    @MainActor
    func testHangarReduceMotionDisablesAutoRotationAndGlide() {
        let orbit = HangarOrbitController()
        orbit.reduceMotion = true
        let original = orbit.yaw
        orbit.advance(dt: 1)
        XCTAssertEqual(orbit.yaw, original)
        orbit.begin(at: .zero, time: 1)
        orbit.drag(to: CGPoint(x: 40, y: 0), time: 1.1)
        orbit.advance(dt: 1 / 60)
        let dragged = orbit.yaw
        orbit.end(time: 1.11)
        for _ in 0..<60 { orbit.advance(dt: 1 / 60) }
        XCTAssertEqual(orbit.yaw, dragged)
    }

    @MainActor
    func testReleaseTerrainIsProceduralAndDoesNotRequireBundledLevelKits() {
        for level in FlightLevel.allCases {
            XCTAssertNil(TerrainRenderer.assetURL(level: level, key: TileKey(x: 0, z: -1), divisions: 24), level.name)
            let terrain = TerrainGenerator(seed: level.seed, level: level)
            XCTAssertFalse(terrain.mesh(key: TileKey(x: 0, z: -1), divisions: 8).positions.isEmpty, level.name)
        }
    }

    @MainActor
    func testBlenderShipsFaceFlightDirectionAndRetainDetailAfterReset() throws {
        for type in AircraftType.allCases {
            let model = AircraftFactory.make(type: type, color: .white)
            let front = try XCTUnwrap(model.findEntity(named: "FlightForward"), type.name)
            let rear = try XCTUnwrap(model.findEntity(named: "FlightRear"), type.name)
            XCTAssertLessThan(front.position(relativeTo: model).z, 0, type.name)
            XCTAssertGreaterThan(rear.position(relativeTo: model).z, 0, type.name)
            let before = model.visualBounds(relativeTo: model).extents
            model.scale = .one
            XCTAssertEqual(model.visualBounds(relativeTo: model).extents, before)
        }
        let falcon = AircraftFactory.make(type: .millenniumFalcon, color: .white)
        let cockpit = try XCTUnwrap(falcon.findEntity(named: "OffsetCockpit"))
        XCTAssertLessThan(cockpit.position(relativeTo: falcon).z, 0)
    }

    func testProceduralFreeRoamTerrainRepeatsSeamlessly() {
        let terrain = TerrainGenerator(seed: FlightLevel.freeRoam.seed, level: .freeRoam)
        for x: Float in [-2300, -120, 0, 1700] {
            XCTAssertEqual(terrain.height(x: x, z: -700), terrain.height(x: x + 4800, z: 4100), accuracy: 0.01)
        }
    }

    @MainActor
    func testPreparedRegionsContainEveryRouteGateAndFreeRoamPortal() {
        for level in FlightLevel.allCases {
            let keys = Set(TerrainRenderer.regionKeys(for: level))
            let terrain = TerrainGenerator(seed: level.seed, level: level)
            let positions = level.isFreeRoam
                ? HyperspaceManager(terrain: terrain).portals.map(\.position)
                : CheckpointSystem(terrain: terrain, aircraft: .kestrel).checkpoints.map(\.position)
            XCTAssertFalse(keys.isEmpty, level.name)
            for position in positions {
                let key = TileKey(x: Int(floor(position.x / TerrainGenerator.tileSize)), z: Int(floor(position.z / TerrainGenerator.tileSize)))
                XCTAssertTrue(keys.contains(key), "\(level.name) misses prepared tile \(key)")
            }
        }
    }

    func testDroidVoiceCommandsRequireWakePhraseAndClampThrottle() {
        XCTAssertEqual(DroidCommandParser.parse("Hey droid, set throttle speed to 75 percent"), .throttle(75))
        XCTAssertEqual(DroidCommandParser.parse("hey droid full throttle"), .throttle(100))
        XCTAssertEqual(DroidCommandParser.parse("hey droid throttle 140 percent"), .throttle(100))
        XCTAssertEqual(DroidCommandParser.parse("hey droid status report"), .status)
        XCTAssertEqual(DroidCommandParser.parse("hey droid switch camera"), .camera)
        XCTAssertEqual(DroidCommandParser.parse("set throttle to 20"), .unknown)
        XCTAssertEqual(DroidCommandParser.parse("Hey, droid, set throttle to seventy-five percent"), .throttle(75))
        XCTAssertEqual(DroidCommandParser.latestUtterance("Hey, droid! Set throttle to seventy-five percent."), "hey droid set throttle to seventy five percent")
        XCTAssertEqual(DroidCommandParser.latestUtterance("hey droid status. Hey, droid, throttle 25%"), "hey droid throttle 25")
        XCTAssertNil(DroidCommandParser.latestUtterance("set throttle to 75 percent"))
        XCTAssertEqual(DroidCommandParser.parse("hey droid throttle thirty seven percent"), .throttle(37))
        XCTAssertEqual(DroidCommandParser.parse("hey droid throttle one hundred percent"), .throttle(100))
        XCTAssertEqual(DroidCommandParser.parse("hey droid throttle 75 percent hey droid throttle 25 percent"), .throttle(25))
        XCTAssertEqual(DroidCommandParser.parse("hey droid status hey droid switch camera"), .camera)
    }

    func testDroidExpandedCommandsAndStopPrecedence() {
        let phrases: [(String, DroidCommand)] = [
            ("turn left", .turnLeft), ("bank right", .turnRight), ("pull up", .climb),
            ("descend", .descend), ("fire weapons", .fire), ("shoot", .fire),
            ("stop firing", .ceaseFire), ("cease fire", .ceaseFire), ("hold fire", .ceaseFire),
            ("boost", .boost), ("repair shields", .repair), ("recharge shields", .repair),
            ("shield status", .status), ("scan for enemies", .scan), ("next checkpoint", .navigate),
            ("where next", .navigate), ("pause", .pause), ("cancel assist", .cancelAssist),
            ("manual control", .cancelAssist), ("help", .help)
        ]
        for (phrase, expected) in phrases {
            XCTAssertEqual(DroidCommandParser.parse("Hey, droid! \(phrase)."), expected, phrase)
            XCTAssertEqual(DroidCommandParser.parse(phrase), .unknown, "Wake phrase required: \(phrase)")
        }
        XCTAssertEqual(DroidCommandParser.parse("hey droid fire weapons hey droid cease fire"), .ceaseFire)
        XCTAssertEqual(DroidCommandParser.parse("hey droid help with throttle"), .help)
    }

    @MainActor
    func testEveryDroidHasAVisibleModelAndSelectionPersists() {
        let suite = "DroidSettings-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        for type in DroidType.allCases {
            let model = DroidFactory.make(type)
            XCTAssertFalse(model.children.isEmpty, type.name)
            var settings = GameSettings(defaults: defaults)
            settings.droid = type
            settings.save(defaults: defaults)
            XCTAssertEqual(GameSettings(defaults: defaults).droid, type)
        }
    }
}


private final class AccountTestSessionStore:AccountSessionStore {
    var data:Data?
    func load() -> Data? { data }
    func store(_ data:Data?) throws { self.data = data }
}
private final class AccountTestHTTP:URLProtocol {
    static var handler:((URLRequest) throws -> (Int,Data))?
    override class func canInit(with request:URLRequest) -> Bool { true }
    override class func canonicalRequest(for request:URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw AccountError.message("Missing mock handler") }
            let (status,data) = try handler(request)
            let response = HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:["Content-Type":"application/json"])!
            client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
            client?.urlProtocol(self,didLoad:data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self,didFailWithError:error) }
    }
    override func stopLoading() { }
}

final class ScenicExpeditionIntegrationTests: XCTestCase {
    func testScenicSolidsCatchFastPassesAndLeaveClearSpace() throws {
        for name in ["Earth", "Venus", "Mars"] {
            let body = try XCTUnwrap(SolarBody.all.first { $0.name == name })
            let field = SolarLandscape(body: body)
            XCTAssertFalse(field.scenerySolids.isEmpty, name)
            for solid in field.scenerySolids {
                let center = solid.base + SIMD3<Float>(0, solid.height / 2, 0)
                XCTAssertTrue(solid.hits(from: center - [solid.radius * 4, 0, 0], to: center + [solid.radius * 4, 0, 0], radius: 1), name)
                XCTAssertFalse(solid.hits(from: center + [solid.radius + 10, 0, 0], to: center + [solid.radius + 10, 10, 0], radius: 1), name)
                XCTAssertFalse(solid.hits(from: solid.base + [0, solid.height + 10, 0], to: solid.base + [0, solid.height + 20, 0], radius: 1), name)
            }
        }
    }
    @MainActor
    func testPreparedSolarTerrainMatchesGroundContactAndStaysBatched() throws {
        let renderer = UniverseRenderer(), camera = PerspectiveCamera()
        for name in ["Mercury", "Venus", "Earth", "Mars", "Jupiter"] {
            let body = try XCTUnwrap(SolarBody.all.first { $0.name == name })
            var flight = UniverseFlight(), state = FlightState()
            XCTAssertTrue(flight.begin(.solarSystem, state: state))
            for _ in 0..<601 { _ = flight.advanceJump(state: &state, dt: 1/120) }
            XCTAssertTrue(flight.begin(.surface(name), state: state))
            for _ in 0..<601 { _ = flight.advanceJump(state: &state, dt: 1/120) }
            renderer.update(flight: flight, active: true, camera: camera, state: state, dt: 0.12, reduced: false, target: nil)
            let scene = try XCTUnwrap(renderer.root.findEntity(named: name + " scenic expedition"), name)
            var triangles = 0, entities = 0, terrainSamples = 0
            func inspect(_ entity: Entity) {
                entities += 1
                if let mesh = (entity as? ModelEntity)?.model?.mesh {
                    for model in mesh.contents.models { for part in model.parts {
                        triangles += (part.triangleIndices?.count ?? 0) / 3
                        if entity.name.hasPrefix(name + " terrain band") {
                            for (index, point) in part.positions.enumerated() where index.isMultiple(of: 79) {
                                XCTAssertEqual(point.y, SolarLandscape(body: body).height(x: point.x, z: point.z), accuracy: 0.02, name)
                                terrainSamples += 1
                            }
                        }
                    } }
                }
                for child in entity.children { inspect(child) }
            }
            inspect(scene)
            XCTAssertLessThan(entities, 50, name)
            XCTAssertLessThan(triangles, 180000, name)
            if !body.isCloudWorld { XCTAssertGreaterThan(terrainSamples, 100, name) }
            let ids = scene.children.map(\.id)
            renderer.update(flight: flight, active: true, camera: camera, state: state, dt: 0.12, reduced: false, target: nil)
            XCTAssertEqual(scene.children.map(\.id), ids, "Flight ticks must reuse the prepared scenery")
            XCTAssertFalse(SolarLandscape(body: body).impact(from: state.position, to: state.position, radius: 30), name)
            print("EXPEDITION_COST \(name) entities=\(entities) triangles=\(triangles)")
        }
    }
}

extension ScenicExpeditionIntegrationTests {
    /// These four destinations were explicitly excluded from the scenery redesign.
    /// Freeze their terrain contact and verify that they still use the legacy scene.
    @MainActor
    func testRejectedPlanetRedesignsKeepLegacyTerrainAndRendering() throws {
        let renderer = UniverseRenderer(), camera = PerspectiveCamera()
        for name in ["Saturn", "Uranus", "Neptune", "Moon"] {
            let body = try XCTUnwrap(SolarBody.all.first { $0.name == name })
            let field = SolarLandscape(body: body)
            XCTAssertFalse(field.usesScenicTerrain, name)
            XCTAssertTrue(field.scenerySolids.isEmpty, name)
            if body.isCloudWorld {
                for point: SIMD2<Float> in [[0, 0], [817, -2519], [-6240, 7800]] {
                    XCTAssertEqual(field.height(x: point.x, z: point.y), -600, name)
                }
                XCTAssertFalse(field.impact(from: [0, 800, 1200], to: [0, -399, 1200], radius: 3), name)
                XCTAssertTrue(field.impact(from: [0, 800, 1200], to: [0, -401, 1200], radius: 3), name)
            } else {
                // Existing lunar crater-field samples, before the expedition pass.
                let fixtures: [(SIMD2<Float>, Float)] = [([0, 0], 840), ([817, -2519], 662.08905), ([-6240, 7800], 298.28354)]
                for (point, expected) in fixtures {
                    XCTAssertEqual(field.height(x: point.x, z: point.y), expected, accuracy: 0.2, name)
                }
            }
            var flight = UniverseFlight(), state = FlightState()
            XCTAssertTrue(flight.begin(.solarSystem, state: state))
            for _ in 0..<601 { _ = flight.advanceJump(state: &state, dt: 1/120) }
            XCTAssertTrue(flight.begin(.surface(name), state: state))
            for _ in 0..<601 { _ = flight.advanceJump(state: &state, dt: 1/120) }
            renderer.update(flight: flight, active: true, camera: camera, state: state, dt: 0.12, reduced: false, target: nil)
            XCTAssertNil(renderer.root.findEntity(named: name + " scenic expedition"), name)
            XCTAssertNil(renderer.root.findEntity(named: "Expedition atmosphere"), name)
            XCTAssertNil(renderer.root.findEntity(named: "Giant cloud belt 0"), name)
        }
    }
}

extension ScenicExpeditionIntegrationTests {
    @MainActor
    func testScenicMetalLibraryBindsEveryExpeditionMaterialFamily() throws {
        // A silent fallback to plain materials would make this build look like
        // the old renderer even though the Swift code still compiled.
        XCTAssertTrue(ScenicMaterials.shadersAvailable, "The app bundle must contain the ScenicShaders Metal library")
        let families: [(String, any RealityKit.Material)] = [
            ("ground", ScenicMaterials.terrain(color:.white,kind:"sand",planet:"Tatooine",continuous:true)),
            ("water", ScenicMaterials.water(color:.cyan,planet:"Earth")),
            ("cloud", ScenicMaterials.cloud(color:.white,planet:"Jupiter")),
            ("atmosphere", ScenicMaterials.atmosphere(planet:"Earth",color:.cyan)),
            ("globe", ScenicMaterials.globe(UnlitMaterial(color:.white),planet:"Mars"))
        ]
        for (name, material) in families {
            let custom = try XCTUnwrap(material as? CustomMaterial, "Missing or rejected Metal entry point for \(name)")
            let values = custom.custom.value
            XCTAssertTrue(values.x.isFinite && values.y.isFinite && values.z.isFinite && values.w.isFinite, name)
            let entity = ModelEntity(mesh:.generateSphere(radius:1),materials:[custom])
            XCTAssertTrue(entity.model?.materials.first is CustomMaterial, "\(name) must remain a custom material when bound to geometry")
        }
        let detailed = try XCTUnwrap(ScenicMaterials.terrain(color:.white,kind:"snow",planet:"Hoth",continuous:true,reducedDetail:false) as? CustomMaterial)
        let reduced = try XCTUnwrap(ScenicMaterials.terrain(color:.white,kind:"snow",planet:"Hoth",continuous:true,reducedDetail:true) as? CustomMaterial)
        XCTAssertNotEqual(detailed.custom.value, reduced.custom.value, "Reduced detail must reach the shader rather than changing only UI state")
    }

    @MainActor
    func testPlanetOrbitDetailUsesHysteresisAndReusesPreparedMeshes() throws {
        let entity = ModelEntity(mesh:.generateSphere(radius:100),materials:[UnlitMaterial(color:.white)])
        let parent = Entity(); parent.position = [500,50,-800]; parent.addChild(entity)
        let detail = PlanetOrbitDetail(entity:entity,name:"Mercury",radius:100)
        let center = entity.position(relativeTo:nil)
        func approach(_ angularSize:Float, reduced:Bool = false) {
            detail.update(camera:center+[0,0,100/angularSize],reduced:reduced)
        }
        approach(0.01)
        XCTAssertEqual(detail.selectedLevel,0)
        let far = try XCTUnwrap(entity.model?.mesh)
        // A camera wobbling inside the far/medium dead band must not swap meshes.
        for frame in 0..<120 { approach(0.026+sin(Float(frame)*0.3)*0.003) }
        XCTAssertEqual(detail.selectedLevel,0)
        XCTAssertTrue(entity.model?.mesh === far)
        approach(0.05)
        XCTAssertEqual(detail.selectedLevel,1)
        let medium = try XCTUnwrap(entity.model?.mesh)
        approach(0.15)
        XCTAssertEqual(detail.selectedLevel,2)
        let near = try XCTUnwrap(entity.model?.mesh)
        for frame in 0..<120 { approach(0.085+sin(Float(frame)*0.3)*0.010) }
        XCTAssertEqual(detail.selectedLevel,2)
        XCTAssertTrue(entity.model?.mesh === near)
        approach(0.05); XCTAssertTrue(entity.model?.mesh === medium)
        approach(0.01); XCTAssertTrue(entity.model?.mesh === far)
        approach(0.05); approach(0.15); XCTAssertTrue(entity.model?.mesh === near)
        approach(0.9,reduced:true)
        XCTAssertEqual(detail.selectedLevel,1,"Reduced mode must cap near-planet geometry")
        XCTAssertTrue(entity.model?.mesh === medium)
        for _ in 0..<60 { approach(0.9,reduced:true) }
        XCTAssertEqual(detail.selectedLevel,1)
        detail.update(camera:[.nan,0,0],reduced:true)
        XCTAssertEqual(detail.selectedLevel,1,"Invalid camera input must not disturb a valid prepared mesh")
        XCTAssertTrue(entity.model?.mesh === medium)

        XCTAssertEqual(detail.triangleCounts.count,3)
        XCTAssertLessThan(detail.triangleCounts[0],detail.triangleCounts[1])
        XCTAssertLessThan(detail.triangleCounts[1],detail.triangleCounts[2])
        for (level,mesh) in [far,medium,near].enumerated() {
            var triangles = 0, vertices = 0
            for model in mesh.contents.models { for part in model.parts {
                triangles += (part.triangleIndices?.count ?? 0)/3
                vertices += part.positions.count
                for position in part.positions {
                    XCTAssertTrue(position.x.isFinite && position.y.isFinite && position.z.isFinite)
                    XCTAssertGreaterThan(simd_length(position),97)
                    XCTAssertLessThan(simd_length(position),103)
                }
                let uv = try XCTUnwrap(part.textureCoordinates,"Prepared planet meshes require valid globe UVs")
                XCTAssertEqual(uv.count,part.positions.count)
                for coordinate in uv {
                    XCTAssertTrue(coordinate.x.isFinite && coordinate.y.isFinite)
                    XCTAssertTrue((0...1).contains(coordinate.x) && (0...1).contains(coordinate.y))
                }
            } }
            XCTAssertGreaterThan(vertices,0)
            XCTAssertEqual(triangles,detail.triangleCounts[level],"A fallback sphere would hide a failed prepared mesh")
            XCTAssertLessThan(triangles,20000)
        }
    }

    @MainActor
    func testHomeExpeditionBindsShadersAndKeepsTerrainStableDuringFlight() throws {
        let defaults=UserDefaults.standard,old=defaults.object(forKey:"aetherTatooineTerrainEnabled")
        defaults.set(false,forKey:"aetherTatooineTerrainEnabled")
        defer { if let old { defaults.set(old,forKey:"aetherTatooineTerrainEnabled") } else { defaults.removeObject(forKey:"aetherTatooineTerrainEnabled") } }
        let renderer = PlanetSurfaceRenderer(planet:.tatooine,reducedDetail:true)
        let terrain = renderer.root.children.compactMap { $0 as? ModelEntity }.filter { $0.name.hasPrefix("Terrain stratum") }
        XCTAssertFalse(terrain.isEmpty)
        let meshes = try terrain.map { try XCTUnwrap($0.model?.mesh) }
        var sampledVertices = 0
        for entity in terrain {
            XCTAssertTrue(entity.model?.materials.first is CustomMaterial,"Terrain must use the procedural shader in the actual scene")
            guard let mesh = entity.model?.mesh else { continue }
            for model in mesh.contents.models { for part in model.parts {
                for (index,point) in part.positions.enumerated() where index.isMultiple(of:67) {
                    XCTAssertTrue(point.x.isFinite && point.y.isFinite && point.z.isFinite)
                    XCTAssertEqual(point.y,PlanetExploration(planet:.tatooine).groundHeight(x:point.x,z:point.z),accuracy:0.02)
                    sampledVertices += 1
                }
            } }
        }
        XCTAssertGreaterThan(sampledVertices,100)
        let clouds = try XCTUnwrap(renderer.root.findEntity(named:"Prepared atmospheric cloud layer") as? ModelEntity)
        XCTAssertTrue(clouds.model?.materials.first is CustomMaterial,"Cloud geometry must bind the density shader")
        let cloudMesh = try XCTUnwrap(clouds.model?.mesh)
        let entityIDs = renderer.root.children.map(\.id)
        for frame in 0..<180 {
            renderer.update(camera:[Float(frame)*20,500,8400-Float(frame)*30],dt:1/60,passed:0)
        }
        XCTAssertEqual(renderer.root.children.map(\.id),entityIDs,"Flight must not create or stream scenery entities")
        for (index,entity) in terrain.enumerated() { XCTAssertTrue(entity.model?.mesh === meshes[index]) }
        XCTAssertTrue(clouds.model?.mesh === cloudMesh)
        XCTAssertTrue(clouds.position.x.isFinite && clouds.position.y.isFinite && clouds.position.z.isFinite)
        XCTAssertLessThanOrEqual(abs(clouds.position.x),180)
        XCTAssertLessThanOrEqual(abs(clouds.position.z),120)
    }
}


final class AetherPlanetIntegrationTests: XCTestCase {
    func testPreparedGridMatchesContactAndHasBoundedCost() throws {
        let asset = try AetherPlanet.prepared.get()
        XCTAssertEqual(asset.grid.mesh.positions.count,193*193)
        XCTAssertEqual(asset.grid.mesh.indices.count,192*192*6)
        XCTAssertEqual(asset.pixels.count,512*512*4)
        for (index,p) in asset.grid.mesh.positions.enumerated() where index.isMultiple(of:37) {
            XCTAssertEqual(AetherPlanet.height(x:p.x,z:p.z),p.y,accuracy:0.02)
            XCTAssertEqual(simd_length(asset.grid.mesh.normals[index]),1,accuracy:0.001)
        }
        let field = SolarLandscape(body:AetherPlanet.body)
        let y = field.height(x:0,z:1200)
        XCTAssertFalse(field.impact(from:[0,y+400,1200],to:[0,y+350,1200],radius:3))
        XCTAssertTrue(field.impact(from:[0,y+100,1200],to:[0,y-20,1200],radius:3))
        let center = AetherPlanet.archPosition(asset)
        XCTAssertTrue(AetherPlanet.hitsArch(from:center+[0,300,200],to:center+[0,300,-200],radius:3))
        XCTAssertFalse(AetherPlanet.hitsArch(from:center+[0,140,200],to:center+[0,140,-200],radius:3))
    }
    func testFlagControlsNewTravelWithoutChangingExistingWorlds() {
        let defaults = UserDefaults.standard, old = defaults.object(forKey:"aetherPlanetEnabled")
        defer { if let old { defaults.set(old,forKey:"aetherPlanetEnabled") } else { defaults.removeObject(forKey:"aetherPlanetEnabled") } }
        defaults.set(false,forKey:"aetherPlanetEnabled")
        var flight = UniverseFlight(), state = FlightState()
        XCTAssertFalse(flight.begin(.surface(AetherPlanet.name),state:state))
        XCTAssertTrue(flight.begin(.solarSystem,state:state))
        for _ in 0..<601 { _ = flight.advanceJump(state:&state,dt:1/120) }
        XCTAssertTrue(flight.begin(.surface("Earth"),state:state))
        flight.cancel(state:&state)
        defaults.set(true,forKey:"aetherPlanetEnabled")
        XCTAssertTrue(flight.begin(.surface(AetherPlanet.name),state:state))
        for _ in 0..<601 { _ = flight.advanceJump(state:&state,dt:1/120) }
        XCTAssertEqual(flight.surfaceBody?.name,AetherPlanet.name)
        XCTAssertGreaterThan(state.position.y-AetherPlanet.height(x:state.position.x,z:state.position.z),399)
        XCTAssertTrue(flight.begin(.solarSystem,state:state))
        for _ in 0..<601 { _ = flight.advanceJump(state:&state,dt:1/120) }
        XCTAssertNil(flight.surfaceBody)
        XCTAssertEqual(SolarBody.all.count,10,"Real Solar System list stays unchanged")
    }
    @MainActor
    func testRealityKitBridgeKeepsBaselineGeometryAndUVs() throws {
        let asset = try AetherPlanet.prepared.get()
        for enhanced in [false,true] {
            let root = try AetherPlanetRenderer.make(asset,enhanced:enhanced)
            let ground = try XCTUnwrap(root.findEntity(named:"Aether triangle-aligned ground") as? ModelEntity)
            let mesh = try XCTUnwrap(ground.model?.mesh)
            var count = 0
            for model in mesh.contents.models { for part in model.parts {
                count += (part.triangleIndices?.count ?? 0)/3
                XCTAssertEqual(part.positions.count,part.normals?.count)
                XCTAssertEqual(part.positions.count,part.textureCoordinates?.count)
            } }
            XCTAssertEqual(count,192*192*2)
            XCTAssertNotNil(root.findEntity(named:"Aether rock arch"))
            XCTAssertEqual(root.children.count,AetherWorldDetails.enabled ? 4:3)
        }
    }
}


final class AetherHothPilotTests:XCTestCase {
    func testGridMatchesOriginalHothTrianglesAcrossInteriorAndEdges() throws {
        let asset = try AetherHothTerrain.prepared.get(), original = PlanetExploration(planet:.hoth)
        for z in stride(from:Float(-12000),through:12000,by:173) {
            for x in stride(from:Float(-12000),through:12000,by:197) {
                XCTAssertEqual(try XCTUnwrap(asset.height(x:x,z:z)),original.groundHeight(x:x,z:z),accuracy:0.02)
            }
        }
        for x:Float in [-12000,0,12000] { for z:Float in [-12000,0,12000] {
            XCTAssertEqual(try XCTUnwrap(asset.height(x:x,z:z)),original.groundHeight(x:x,z:z),accuracy:0.02)
        } }
    }
    func testTileEdgesHaveIdenticalHeightsAndNormalsAndBoundedSkirts() throws {
        let asset = try AetherHothTerrain.prepared.get()
        XCTAssertEqual(asset.tiles.count,16)
        var seen:[SIMD2<Float>:(Float,SIMD3<Float>)] = [:], duplicates = 0, triangles = 0
        for tile in asset.tiles {
            XCTAssertEqual(tile.mesh.positions.count,41*41)
            triangles += tile.mesh.indices.count/3+tile.skirt.indices.count/3
            for (i,p) in tile.mesh.positions.enumerated() {
                let key = SIMD2(p.x,p.z), n = tile.mesh.normals[i]
                if let other = seen[key] {
                    duplicates += 1; XCTAssertEqual(p.y,other.0); XCTAssertEqual(n,other.1)
                } else { seen[key] = (p.y,n) }
                XCTAssertEqual(simd_length(n),1,accuracy:0.001)
            }
            for i in stride(from:0,to:tile.mesh.indices.count,by:3) {
                let ids = tile.mesh.indices[i..<i+3].map(Int.init)
                let a = tile.mesh.positions[ids[0]], b = tile.mesh.positions[ids[1]], c = tile.mesh.positions[ids[2]]
                XCTAssertGreaterThan(simd_cross(b-a,c-a).y,0)
            }
            for i in stride(from:0,to:tile.skirt.positions.count,by:4) {
                XCTAssertEqual(tile.skirt.positions[i].y-tile.skirt.positions[i+3].y,140,accuracy:0.001)
            }
        }
        XCTAssertGreaterThan(duplicates,900)
        XCTAssertEqual(seen.count,161*161)
        XCTAssertLessThan(triangles,60000)
    }
    @MainActor
    func testPilotSwitchKeepsOtherSceneryAndTerrainStableDuringFlight() throws {
        let defaults = UserDefaults.standard, old = defaults.object(forKey:"aetherHothTerrainEnabled")
        defer { if let old { defaults.set(old,forKey:"aetherHothTerrainEnabled") } else { defaults.removeObject(forKey:"aetherHothTerrainEnabled") } }
        for enabled in [false,true] {
            defaults.set(enabled,forKey:"aetherHothTerrainEnabled")
            let renderer = PlanetSurfaceRenderer(planet:.hoth,reducedDetail:true)
            XCTAssertEqual(renderer.root.children.filter { $0.name.hasPrefix("Hoth Aether ground") }.count,enabled ? 16:0)
            XCTAssertEqual(renderer.root.children.filter { $0.name.hasPrefix("Terrain stratum") }.isEmpty,enabled)
            XCTAssertNotNil(renderer.root.findEntity(named:"Scout beacon 1"))
            let ids = renderer.root.children.map(\.id)
            for i in 0..<180 { renderer.update(camera:[Float(i)*30,800,8400-Float(i)*30],dt:1/60,passed:0) }
            XCTAssertEqual(renderer.root.children.map(\.id),ids)
        }
    }
}

final class AetherWorldDetailTests:XCTestCase {
    func testComparisonFlagsAcceptLaunchArgumentStrings() {
        let defaults=UserDefaults(suiteName:UUID().uuidString)!
        defaults.setVolatileDomain(["aetherSurfaceEnabled":"NO"],forName:UserDefaults.argumentDomain)
        XCTAssertFalse(AetherPlanet.flag("aetherSurfaceEnabled",defaults:defaults))
        defaults.setVolatileDomain(["aetherSurfaceEnabled":"YES"],forName:UserDefaults.argumentDomain)
        XCTAssertTrue(AetherPlanet.flag("aetherSurfaceEnabled",defaults:defaults))
    }
    func testScatterIsRepeatableGroundedAndProtectsFlightSpace() throws {
        let asset=try AetherPlanet.prepared.get(), repeated=try AetherWorldDetails.scatter(on:asset.grid)
        XCTAssertEqual(asset.scatter.placements,repeated.placements)
        XCTAssertGreaterThan(asset.scatter.placements.count,300)
        XCTAssertLessThanOrEqual(asset.scatter.attempts,9000)
        let surface=AetherWorldDetails.ProtectedSurface(grid:asset.grid)
        for item in asset.scatter.placements {
            XCTAssertTrue(surface.isClear([item.position.x,item.position.z]))
            XCTAssertEqual(item.position.y,try XCTUnwrap(asset.grid.sample(at:[item.position.x,item.position.z])).position.y,accuracy:0.01)
        }
        let item=try XCTUnwrap(asset.scatter.placements.first), center=item.position+SIMD3<Float>(0,25,0)
        XCTAssertTrue(AetherWorldDetails.hits(from:center-[200,0,0],to:center+[200,0,0],radius:4,placements:[item]))
        XCTAssertFalse(AetherWorldDetails.hits(from:center+[0,300,0],to:center+[200,300,0],radius:4,placements:[item]))
    }
    @MainActor
    func testCustomSurfaceBindsAndSceneryStaysBatched() throws {
        let asset=try AetherPlanet.prepared.get(),root=try AetherPlanetRenderer.make(asset)
        let ground=try XCTUnwrap(root.findEntity(named:"Aether triangle-aligned ground") as? ModelEntity)
        XCTAssertTrue(ground.model?.materials.first is CustomMaterial)
        let baseline=try AetherPlanetRenderer.make(asset,enhanced:false)
        XCTAssertTrue((baseline.findEntity(named:"Aether triangle-aligned ground") as? ModelEntity)?.model?.materials.first is PhysicallyBasedMaterial)
        let rocks=try XCTUnwrap(root.findEntity(named:"Aether protected scatter") as? ModelEntity)
        let mesh=try XCTUnwrap(rocks.model?.mesh)
        var triangles=0
        for model in mesh.contents.models { for part in model.parts {
            let indices=Array(try XCTUnwrap(part.triangleIndices)),normals=Array(try XCTUnwrap(part.normals)),positions=Array(part.positions)
            triangles += indices.count/3
            for i in stride(from:0,to:indices.count,by:3) {
                let a=Int(indices[i]),b=Int(indices[i+1]),c=Int(indices[i+2])
                XCTAssertGreaterThan(simd_dot(simd_cross(positions[b]-positions[a],positions[c]-positions[a]),normals[a]+normals[b]+normals[c]),0)
            }
        } }
        XCTAssertLessThan(triangles,60000)
        XCTAssertEqual(root.children.count,4)
    }
}

final class AetherReleaseValidationTests:XCTestCase {
    @MainActor
    func testAbandonedUniverseOwnerCannotPublishPreparedAetherScene() async {
        let oldReady = AetherPlanetRenderer.ready, oldFailure = AetherPlanetRenderer.failure
        defer { AetherPlanetRenderer.ready = oldReady; AetherPlanetRenderer.failure = oldFailure }
        var owner:UniverseRenderer? = UniverseRenderer()
        weak var abandoned = owner
        // Let asynchronous CPU preparation begin, then abandon its scene owner.
        await Task.yield()
        owner = nil
        XCTAssertNil(abandoned,"Preparation must not keep an abandoned scene alive")
        AetherPlanetRenderer.ready = false; AetherPlanetRenderer.failure = nil
        try? await Task.sleep(for:.milliseconds(200))
        XCTAssertFalse(AetherPlanetRenderer.ready,"An abandoned owner cannot publish stale readiness")
        XCTAssertNil(AetherPlanetRenderer.failure)
    }
    func testDiagnosticsRequireBothExplicitArgumentsAndKnownVariant() {
        typealias Config = AetherReleaseValidation.Configuration
        XCTAssertNil(Config.read(environment:[:],arguments:["--aether-release-check"]))
        XCTAssertNil(Config.read(environment:["STARFLIGHT_AETHER_VALIDATION":"candidate"],arguments:[]))
        XCTAssertNil(Config.read(environment:["STARFLIGHT_AETHER_VALIDATION":"invalid"],arguments:["--aether-release-check"]))
        let config = Config.read(environment:["STARFLIGHT_AETHER_VALIDATION":"baseline","STARFLIGHT_AETHER_SECONDS":"nan","STARFLIGHT_AETHER_PASSES":"999"],arguments:["--aether-release-check"])
        XCTAssertEqual(config?.seconds,45);XCTAssertEqual(config?.passes,5);XCTAssertEqual(config?.name,"baseline-30")
        let paired = Config.read(environment:["STARFLIGHT_AETHER_VALIDATION":"comparison"],arguments:["--aether-release-check"])
        XCTAssertEqual(paired?.comparison,true);XCTAssertEqual(paired?.candidate,false,"A paired check must start with the original terrain")
    }
    func testBoundedSamplingRetainsLargeStallsAndRejectsInvalidIntervals() {
        var samples = AetherReleaseValidation.Histogram()
        for _ in 0..<100_000 { samples.add(milliseconds:33.333) }
        samples.add(milliseconds:2500);samples.add(milliseconds:.nan);samples.add(milliseconds:-1)
        XCTAssertEqual(samples.count,100_001)
        XCTAssertEqual(samples.bins.count,2001)
        XCTAssertEqual(samples.maximum,2500)
        XCTAssertEqual(samples.percentile(0.95),34)
        XCTAssertEqual(samples.percentile(1),2000,"Overflow bucket must keep the long stall, not drop it")
    }
}

final class AetherSelectiveMigrationTests:XCTestCase {
    func testEachWorldRetainsItsOwnTriangleContactAndPreparationCache() throws {
        for planet:SpacePlanet in [.tatooine,.endor] {
            let asset=try AetherHomeTerrain.prepared(for:planet).get(),surface=PlanetExploration(planet:planet)
            XCTAssertEqual(asset.tiles.count,16)
            for z in stride(from:Float(-12000),through:12000,by:311) { for x in stride(from:Float(-12000),through:12000,by:277) {
                XCTAssertEqual(try XCTUnwrap(asset.height(x:x,z:z)),surface.groundHeight(x:x,z:z),accuracy:0.02)
            } }
            XCTAssertEqual(asset.grid.mesh.positions,try AetherHomeTerrain.prepared(for:planet).get().grid.mesh.positions)
            for landmark in surface.landmarks { XCTAssertEqual(try XCTUnwrap(asset.height(x:landmark.position.x,z:landmark.position.z)),surface.groundHeight(x:landmark.position.x,z:landmark.position.z),accuracy:0.02) }
        }
        XCTAssertThrowsError(try AetherHomeTerrain.prepared(for:.coruscant).get())
    }
    @MainActor
    func testIndependentWorldSwitchesPreserveSceneryAndFlightEntities() throws {
        let defaults=UserDefaults.standard,keys=["aetherTatooineTerrainEnabled","aetherEndorTerrainEnabled"]
        let old=keys.map { defaults.object(forKey:$0) }
        defer { for (i,key) in keys.enumerated() { if let value=old[i] { defaults.set(value,forKey:key) } else { defaults.removeObject(forKey:key) } } }
        for enabled in [false,true] {
            defaults.set(enabled,forKey:keys[0]);defaults.set(!enabled,forKey:keys[1])
            for planet:SpacePlanet in [.tatooine,.endor] {
                let pilot=planet == .tatooine ? enabled:!enabled
                let renderer=PlanetSurfaceRenderer(planet:planet,reducedDetail:true)
                XCTAssertEqual(renderer.root.children.filter { $0.name.hasPrefix(planet.name+" Aether ground") }.count,pilot ? 16:0)
                XCTAssertNotNil(renderer.root.findEntity(named:"Scout beacon 1"))
                XCTAssertNotNil(renderer.root.findEntity(named:"District 0"))
                let ids=renderer.root.children.map(\.id)
                for i in 0..<120 { renderer.update(camera:[Float(i)*50,900,8400-Float(i)*40],dt:1/60,passed:0) }
                XCTAssertEqual(renderer.root.children.map(\.id),ids)
            }
        }
    }
}
