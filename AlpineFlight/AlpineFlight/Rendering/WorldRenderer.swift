import RealityKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor
final class WorldRenderer {
    let anchor = AnchorEntity(world: .zero)
    let terrain: TerrainRenderer
    let camera = CameraController()
    private(set) var aircraft: Entity
    private var droid: Entity
    private var clouds: [ModelEntity] = []
    private var stationDetails: [Entity] = []
    private var laserBolts: [ModelEntity] = []
    private var playerBolts: [ModelEntity] = []
    private var muzzleFlash: ModelEntity?
    private var pursuerEntities: [Entity] = []
    private var racerEntities: [Entity] = []
    private var hyperspacePortals: [Entity] = []
    private let activityScenery = Entity()
    private let arenaBoundary = ArenaScenery.make()
    private var missionBeacon: ModelEntity?
    private let hyperspaceLights = Entity()
    private var hyperspaceStreaks: [ModelEntity] = []
    private var planetEntities: [Entity] = []
    private let spaceBackdrop = Entity()
    private var cometScenery = Entity()
    private var bountyMarker:ModelEntity?
    private let residences = CityResidenceRenderer()
    private var surfaceScenes: [SpacePlanet: PlanetSurfaceRenderer] = [:]
    func wildlifeLookoutPoint(on planet:SpacePlanet) -> SIMD3<Float>? { surfaceScenes[planet]?.wildlifeLookoutPoint }
    private var asteroidEntities: [ModelEntity] = []
    private var boostPadEntities: [Entity] = []
    private var raceSparks: [ModelEntity] = []
    private var raceEffectTime: Float = 0
    private var explosion: ModelEntity?
    private var gates: [Entity] = []
    private let sky: ModelEntity
    private let impact = Entity()
    private let shipLighting=ShipLighting()
    private let adventures = FlightAdventureRenderer()
    private let universeScenery = UniverseRenderer()
    private let sun = DirectionalLight()
    private let planetaryReflectionLight = Entity()
    private var baseSunIntensity: Float = 2400
    private var baseSunOrientation = simd_quatf()
    private var sunProfileKey = ""
    private var reflectionProfileWorld:String?
    private var installedReflectionWorld:String?
    private var universeGalaxy:Galaxy?
    private var debris: [(ModelEntity, SIMD3<Float>)] = []
    private var crashOrigin = SIMD3<Float>.zero
    private var crashRotation = simd_quatf()
    private var propellerAngle: Float = 0
    private var rotors: [Entity] = []
    private var engineEffects: EngineEffects?
    private var jetGlow: Entity?
    private var podEnergyField: Entity?
    private var aircraftType: AircraftType
    private var paintColor: AircraftColor
    private var droidType: DroidType
    private var performanceMode = false
    private var crashScenery: ScenicRegion?
    private var surfaceReducedDetail = false
    private var customShipURL: URL?

    func updateBountyTarget(_ target:SIMD3<Float>?) {
        bountyMarker?.isEnabled = target != nil
        if let target { bountyMarker?.position = target }
    }

    func updateResidences(_ housing:CityHousing?) { residences.update(housing) }

    func updateCityJobs(target:CityStation?,servicing:Bool) {
        surfaceScenes[.coruscant]?.updateJobs(target:target,servicing:servicing)
    }

    func setPerformanceMode(_ enabled: Bool, reducedDetail: Bool) {
        performanceMode = enabled
        guard surfaceReducedDetail != reducedDetail else { return }
        surfaceReducedDetail = reducedDetail
        for (planet, scene) in surfaceScenes {
            let visible = scene.root.isEnabled
            scene.root.removeFromParent()
            let replacement = PlanetSurfaceRenderer(planet:planet,reducedDetail:reducedDetail)
            replacement.root.isEnabled = visible
            anchor.addChild(replacement.root)
            surfaceScenes[planet] = replacement
        }
    }

    init(view: ARView, generator: TerrainGenerator, checkpoints: [Checkpoint], racePads: [RaceBoostPad] = [], color: AircraftColor, type: AircraftType = .kestrel, droidType: DroidType = .r2d2, customURL: URL? = nil, reducedDetail: Bool = false, arenaOnly: Bool = false) {
        terrain = TerrainRenderer(generator: generator,emptyRegion:arenaOnly)
        aircraftType = type
        paintColor = color
        self.droidType = droidType
        customShipURL = customURL
        surfaceReducedDetail = reducedDetail
        aircraft = AircraftFactory.make(type: type, color: UIColor(color.color), customURL: customURL)
        droid = DroidFactory.make(droidType)
        let fogColor = UIColor(rgb: generator.level.fogColor)
        var skyMaterial = UnlitMaterial(color: fogColor)
        skyMaterial.faceCulling = .front
        sky = ModelEntity(mesh: .generateSphere(radius: 6500), materials: [skyMaterial])
        if let texture = Self.skyTexture(level: generator.level) {
            skyMaterial.color = .init(tint: .white, texture: .init(texture))
            sky.model?.materials = [skyMaterial]
        }
        anchor.addChild(sky)
        anchor.addChild(terrain.root)
        anchor.addChild(aircraft)
        installDroid(droid, on: aircraft, aircraftType: type)
        anchor.addChild(camera.entity)
        anchor.addChild(impact)
        anchor.addChild(shipLighting.root)
        anchor.addChild(adventures.root)
        sky.components.set(DynamicLightShadowComponent(castsShadow:false))
        sun.name = "Expedition sunlight"
        sun.light.color = UIColor(red: 1, green: 0.93, blue: 0.79, alpha: 1)
        sun.light.intensity = generator.level == .deathStar ? 1050 : generator.level == .storm ? 1700 : 2400
        sun.look(at: [-300, 0, -200], from: [500, 1200, 700], relativeTo: nil)
        baseSunIntensity = sun.light.intensity
        baseSunOrientation = sun.orientation
        anchor.addChild(sun)
        planetaryReflectionLight.name = "Cached planetary reflection light"
        anchor.addChild(planetaryReflectionLight)
        PlanetLighting.prewarm()
        view.environment.background = .color(fogColor)
        view.environment.lighting.intensityExponent = 0.6
        view.scene.addAnchor(anchor)
        makeClouds()
        makeTurretsAndBolts()
        makePursuers()
        makePodRacers()
        makeBoostPads(racePads)
        makeRaceEffects()
        makeGates(checkpoints)
        makeHyperspaceScene(reducedDetail: reducedDetail)
        anchor.addChild(arenaBoundary)
        // Surface activity areas have been retired.
        camera.aircraft = type
        collectRotors()
    }

    func setReplayVisible(_ enabled:Bool) {
        impact.isEnabled = !enabled
        adventures.root.isEnabled = !enabled
        if enabled { aircraft.isEnabled = true }
    }
    func updateAdventures(ghost:FlightState?,platform:SIMD3<Float>?,weather:FlightWeather,weatherActive:Bool,state:FlightState,dt:Float) {
        adventures.update(ghostState:ghost,template:aircraft,target:platform,weather:weather,active:weatherActive,
                          camera:camera.entity.position,cameraOrientation:camera.entity.orientation,dt:dt,reducedDetail:performanceMode)
    }

    /// One real sun, with a bounded shadow map. World artwork and collision stay
    /// fixed; changing a lighting profile never swaps geometry during flight.
    private func updateSunlight(surface:SpacePlanet?,solar:SolarBody?) {
        let selectedSolar = solar.flatMap { ["Mercury","Venus","Earth","Mars","Jupiter"].contains($0.name) ? $0.name : nil }
        let selectedSurface = solar == nil ? surface : nil
        let reflectionWorld = selectedSolar ?? selectedSurface?.rawValue
        if reflectionProfileWorld != reflectionWorld {
            reflectionProfileWorld = reflectionWorld; installedReflectionWorld = nil
            anchor.components.remove(ImageBasedLightReceiverComponent.self)
            planetaryReflectionLight.components.remove(ImageBasedLightComponent.self)
        }
        if let world = reflectionWorld, installedReflectionWorld != world,
           let environment = PlanetLighting.environment(for:world) {
            planetaryReflectionLight.components.set(ImageBasedLightComponent(source:.single(environment),intensityExponent:-0.4))
            anchor.components.set(ImageBasedLightReceiverComponent(imageBasedLight:planetaryReflectionLight))
            installedReflectionWorld = world
        }
        let key = (selectedSolar ?? selectedSurface?.rawValue ?? "default") + (performanceMode ? "/reduced" : "/full")
        guard key != sunProfileKey else { return }
        sunProfileKey = key
        var color = UIColor(red:1,green:0.93,blue:0.79,alpha:1)
        var intensity = baseSunIntensity
        var shadowRange:Float = 0
        if let selectedSolar {
            switch selectedSolar {
            case "Mercury": color = .init(red:1,green:0.97,blue:0.90,alpha:1); intensity = 3300; shadowRange = 1300
            case "Venus": color = .init(red:1,green:0.78,blue:0.48,alpha:1); intensity = 2200; shadowRange = 900
            case "Earth": color = .init(red:1,green:0.96,blue:0.86,alpha:1); intensity = 3000; shadowRange = 1400
            case "Mars": color = .init(red:1,green:0.85,blue:0.68,alpha:1); intensity = 2900; shadowRange = 1400
            default: color = .init(red:1,green:0.89,blue:0.73,alpha:1); intensity = 2400; shadowRange = 1200
            }
        } else if let surface = selectedSurface {
            switch surface {
            case .coruscant: color = .init(red:0.65,green:0.75,blue:1,alpha:1); intensity = 1050; shadowRange = 1000
            case .tatooine: color = .init(red:1,green:0.85,blue:0.64,alpha:1); intensity = 3100; shadowRange = 1400
            case .hoth: color = .init(red:0.84,green:0.93,blue:1,alpha:1); intensity = 2900; shadowRange = 1400
            case .endor: color = .init(red:1,green:0.90,blue:0.71,alpha:1); intensity = 2200; shadowRange = 1200
            }
        }
        sun.light.color = color; sun.light.intensity = intensity
        // Atmosphere shaders use this same fixed sun direction.
        sun.orientation = baseSunOrientation
        sun.shadow = !performanceMode && shadowRange > 0 ? .init(shadowProjection:.automatic(maximumDistance:shadowRange),depthBias:0.75) : nil
    }

    func prepareAetherPlanet() { universeScenery.prepareAetherPlanet() }

    func updateUniverse(_ flight:UniverseFlight,active:Bool,state:FlightState,dt:Float,target:SIMD3<Float>?) {
        universeScenery.update(flight:flight,active:active,camera:camera.entity,state:state,dt:dt,reduced:performanceMode || surfaceReducedDetail,target:target)
        for group in spaceBackdrop.children { for child in group.children where child.name.hasPrefix("Batched stars") { child.isEnabled = !active } }
        guard active else { return }
        if flight.surfaceBody != nil {
            spaceBackdrop.isEnabled = false
            for planet in planetEntities { planet.isEnabled = false }
            for portal in hyperspacePortals { portal.isEnabled = false }
            for rock in asteroidEntities { rock.isEnabled = false }
        }
        if let body = flight.surfaceBody, camera.mode == .chase {
            camera.entity.position.y = max(camera.entity.position.y, SolarLandscape(body:body).height(x:camera.entity.position.x,z:camera.entity.position.z)+12)
        }
        if flight.jumping && !UIAccessibility.isReduceMotionEnabled {
            let t = (UniverseFlight.jumpDuration-flight.remaining)/UniverseFlight.jumpDuration
            camera.entity.camera.fieldOfViewInDegrees = 64+18*sin(min(1,t*3)*Float.pi/2)
        }
        if !flight.homePlanets {
            for planet in planetEntities { planet.isEnabled = false }
            for portal in hyperspacePortals { portal.isEnabled = false }
        }
        if universeGalaxy != flight.galaxy {
            if let shell = spaceBackdrop.children.first?.children.first as? ModelEntity,var material = shell.model?.materials.first as? UnlitMaterial {
                let tint = flight.galaxy.tint
                material.color.tint = flight.galaxy == .milkyWay ? .white:UIColor(red:CGFloat(tint.x),green:CGFloat(tint.y),blue:CGFloat(tint.z),alpha:1)
                shell.model?.materials = [material]
            }
            universeGalaxy = flight.galaxy
        }
    }

    private func makeFreeRoamActivities() {
        guard terrain.generator.level.isFreeRoam else { return }
        anchor.addChild(activityScenery)
        let padMaterial = SimpleMaterial(color: UIColor.darkGray, roughness: 0.9, isMetallic: false)
        let lightMaterial = UnlitMaterial(color: UIColor.cyan)
        for pad in FreeRoamActivities.pads {
            let platform = ModelEntity(mesh: .generateBox(size: [FreeRoamActivities.padHalfWidth * 2, 20, FreeRoamActivities.padHalfLength * 2]), materials: [padMaterial])
            platform.position = pad - SIMD3<Float>(0, 10, 0)
            activityScenery.addChild(platform)
            for x: Float in [-210, 210] {
                for z: Float in [-800, -600, -400, -200, 0, 200, 400, 600, 800] {
                    let light = ModelEntity(mesh: .generateBox(size: [5, 2, 9]), materials: [lightMaterial])
                    light.position = pad + SIMD3<Float>(x, 1, z)
                    activityScenery.addChild(light)
                }
            }
            for x: Float in [-18, 18] {
                let marking = ModelEntity(mesh: .generateBox(size: [5, 1, 60]), materials: [lightMaterial])
                marking.position = pad + SIMD3<Float>(x, 1, 0)
                activityScenery.addChild(marking)
            }
            let crossbar = ModelEntity(mesh: .generateBox(size: [36, 1, 5]), materials: [lightMaterial])
            crossbar.position = pad + SIMD3<Float>(0, 1, 0)
            activityScenery.addChild(crossbar)
        }
        for sector in FreeRoamSector.allCases {
            let sign = ModelEntity(mesh: .generateText(sector.name, extrusionDepth: 0.1,
                font: .systemFont(ofSize: 10), containerFrame: .zero, alignment: .center, lineBreakMode: .byWordWrapping), materials: [lightMaterial])
            sign.position = sector.center + SIMD3<Float>(-100, 130, 0)
            activityScenery.addChild(sign)
        }
        let beacon = ModelEntity(mesh: .generateSphere(radius: 35), materials: [UnlitMaterial(color: UIColor.orange)])
        beacon.isEnabled = false
        activityScenery.addChild(beacon); missionBeacon = beacon
    }
    func updateFreeRoamActivities(_ activity: FreeRoamActivities, inAtmosphere: Bool) {
        activityScenery.isEnabled = terrain.generator.level.isFreeRoam && inAtmosphere
        missionBeacon?.isEnabled = inAtmosphere && activity.missionTarget != nil
        if let target = activity.missionTarget { missionBeacon?.position = target }
    }

    func setAircraft(_ type: AircraftType, color: AircraftColor, customURL: URL? = nil) {
        guard type != aircraftType || color != paintColor || customURL != customShipURL else { return }
        customShipURL = customURL
        aircraftType = type
        paintColor = color
        let transform = aircraft.transform
        aircraft.removeFromParent()
        aircraft = AircraftFactory.make(type: type, color: UIColor(color.color), customURL: customURL)
        aircraft.transform = transform
        anchor.addChild(aircraft)
        installDroid(droid, on: aircraft, aircraftType: type)
        camera.aircraft = type
        camera.reset()
        collectRotors()
    }

    func setDroid(_ type: DroidType) {
        guard type != droidType else { return }
        droidType = type
        droid.removeFromParent()
        droid = DroidFactory.make(type)
        installDroid(droid, on: aircraft, aircraftType: aircraftType)
    }

    private func installDroid(_ droid: Entity, on aircraft: Entity, aircraftType: AircraftType) {
        droid.position = [min(aircraftType.wingspan * 0.12, 3.8), max(aircraftType.bodyRadius * 0.45, 0.7), aircraftType.length * 0.05]
        let scale = clamp(min(aircraftType.length, aircraftType.wingspan) / 16, 0.42, 1.15)
        // Derive from the factory's base scale each time; aircraft changes must
        // not repeatedly multiply the droid down to an invisible size.
        droid.scale = SIMD3<Float>(repeating: 0.7 * scale)
        aircraft.addChild(droid)
    }

    private func collectRotors() {
        engineEffects?.root.removeFromParent()
        engineEffects = EngineEffects(on:aircraft,type:aircraftType)
        rotors = aircraft.children.filter { $0.name == "rotor" || $0.name == "propeller" }
        // Resolve these only when the aircraft is installed or replaced.
        jetGlow = aircraft.findEntity(named: "jet glow")
        podEnergyField = aircraft.findEntity(named: "podracer energy field")
    }

    func reset() {
        for (entity, _) in debris { entity.removeFromParent() }
        debris.removeAll()
        aircraft.scale = .one
        aircraft.isEnabled = true
        camera.reset()
        crashScenery = nil
        for bolt in laserBolts { bolt.isEnabled = false }
        for bolt in playerBolts { bolt.isEnabled = false }
        muzzleFlash?.isEnabled = false
        for pursuer in pursuerEntities { pursuer.isEnabled = false }
        for racer in racerEntities { racer.isEnabled = true }
        for pad in boostPadEntities { pad.isEnabled = true }
        for spark in raceSparks { spark.isEnabled = false }
        for asteroid in asteroidEntities { asteroid.isEnabled = false }
        for portal in hyperspacePortals { portal.isEnabled = terrain.generator.level.isFreeRoam }
        hyperspaceLights.isEnabled = false
        spaceBackdrop.isEnabled = false
        for scene in surfaceScenes.values { scene.root.isEnabled = false }
        terrain.root.isEnabled = terrain.ready
        sky.isEnabled = true
        for cloud in clouds { cloud.isEnabled = true }
        raceEffectTime = 0
        explosion?.removeFromParent()
        explosion = nil
    }

    func update(state: FlightState, throttle: Float, dt: Float, nextCheckpoint: Int, crashTime: Float?, bolts: [TurretBolt], pursuers: [Pursuer], playerBolts: [PlayerBolt], racers: [RaceOpponent], collectedBoostPads: Set<Int>, boosting: Bool = false, skidding: Bool = false, impactEnergy: Float = 0, freeRoamZone: FreeRoamZone = .atmosphere, portals: [FreeRoamPortal] = [], returnPortalPosition: SIMD3<Float> = .zero, asteroids: [SpaceAsteroid] = [], surfacePlanet: SpacePlanet? = nil, surfaceBeacons: Int = 0, comets:[PlanetComet] = [], arenaMode: Bool = false, relaxedSpace: Bool = false, solarSurface: SolarBody? = nil, surfaceTime:Float=0,shipLightsEnabled:Bool=false) {
        shipLighting.update(state:state,aircraft:aircraftType,enabled:shipLightsEnabled && crashTime == nil,reduced:performanceMode || surfaceReducedDetail,showLenses:camera.mode == .chase,beamVisibility:surfacePlanet == .coruscant || (freeRoamZone != .atmosphere && solarSurface == nil) ? 0.4:0.08)
        arenaBoundary.isEnabled = arenaMode
        let awayFromAtmosphere = freeRoamZone != .atmosphere
        let inSpace = freeRoamZone == .asteroidField
        let jumping = freeRoamZone == .hyperspace
        updateSunlight(surface:surfacePlanet,solar:solarSurface)
        if let elapsed = crashTime {
            let surface = surfacePlanet.map { PlanetExploration(planet: $0) }
            camera.updateCrash(state: state, elapsed: elapsed, groundHeight: { x, z in
                if let body = solarSurface { return max(body.name == "Earth" ? 0 : -10000,SolarLandscape(body:body).height(x:x,z:z)) }
                if let surface {
                    let ground=surface.groundHeight(x:x,z:z)
                    if surfacePlanet == .tatooine,MirageBasin.enabled,let top=MirageBasin.height(x:x,z:z,time:surfaceTime) { return max(ground,top) }
                    return ground
                }
                return awayFromAtmosphere ? -100000 : self.terrain.generator.surfaceHeight(x: x, z: z)
            }, isObstructed: { point in
                if let surface { return surface.hitsObstacle(at: point, radius: 8,time:surfaceTime) }
                if inSpace && !arenaMode {
                    if SpacePlanet.allCases.contains(where: { simd_distance(point, $0.position) < $0.radius + 60 }) { return true }
                    if asteroids.contains(where: { simd_distance(point, $0.position) < $0.radius + 8 }) { return true }
                }
                return !awayFromAtmosphere && (self.crashScenery?.hits(point) ?? false)
            })
        } else {
            if surfacePlanet == .coruscant,camera.inspectionTarget != nil,let point=wildlifeLookoutPoint(on:.coruscant) {
                camera.inspectionTarget=point
            }
            camera.update(state: state, terrain: terrain.generator, dt: dt, inSpace: awayFromAtmosphere)
        }
        sky.position = camera.entity.position
        spaceBackdrop.position = camera.entity.position
        terrain.root.isEnabled = terrain.ready && !awayFromAtmosphere
        sky.isEnabled = !awayFromAtmosphere
        spaceBackdrop.isEnabled = awayFromAtmosphere && surfacePlanet == nil
        cometScenery.isEnabled = surfacePlanet != nil
        residences.root.isEnabled = surfacePlanet == .coruscant
        SpaceScenery.updatePlanetComets(cometScenery,comets:comets)
        for planet in planetEntities { planet.isEnabled = !arenaMode && inSpace && (relaxedSpace || asteroids.isEmpty) && surfacePlanet == nil }
        for (planet, scene) in surfaceScenes {
            scene.root.isEnabled = planet == surfacePlanet
            if planet == surfacePlanet { scene.update(camera:camera.entity.position,dt:dt,passed:surfaceBeacons,surfaceTime:surfaceTime,aircraftPosition:crashTime == nil ? state.position:nil) }
        }
        let cloudLimit = performanceMode ? (terrain.generator.level == .storm ? 16 : 12) : clouds.count
        for (index, cloud) in clouds.enumerated() {
            cloud.isEnabled = !awayFromAtmosphere && index < cloudLimit
        }
        for (index, portal) in hyperspacePortals.enumerated() {
            portal.isEnabled = arenaMode || surfacePlanet != nil ? false : freeRoamZone == .atmosphere ? index < portals.count : inSpace && index == 0
            if freeRoamZone == .atmosphere, index < portals.count { portal.position = portals[index].position }
            else if inSpace && index == 0 { portal.position = returnPortalPosition }
            portal.orientation *= simd_quatf(angle: dt * (index.isMultiple(of: 2) ? 0.45 : -0.55), axis: [0, 0, 1])
        }
        hyperspaceLights.isEnabled = jumping
        hyperspaceLights.position = camera.entity.position
        hyperspaceLights.orientation = state.orientation
        if jumping {
            for (index, streak) in hyperspaceStreaks.enumerated() {
                streak.position.z += dt * Float(1_250 + index % 7 * 65)
                if streak.position.z > 420 { streak.position.z = Float(-1_800 - (index % 9) * 110) }
            }
        }
        for (index, entity) in asteroidEntities.enumerated() {
            entity.isEnabled = inSpace && surfacePlanet == nil && index < asteroids.count && crashTime == nil
            if index < asteroids.count {
                let rock = asteroids[index]
                entity.position = rock.position
                entity.scale = SIMD3<Float>(repeating: rock.radius)
                entity.orientation *= simd_quatf(angle: dt * simd_length(rock.spin), axis: simd_normalize(rock.spin))
            }
        }
        aircraft.isEnabled = camera.mode == .chase || crashTime != nil
        aircraft.position = state.position
        aircraft.orientation = state.orientation
        muzzleFlash?.isEnabled = crashTime == nil && playerBolts.contains { $0.age < 0.10 }
        muzzleFlash?.position = state.position + state.forward * (aircraftType.length*0.6)
        muzzleFlash?.orientation = state.orientation
        raceEffectTime += dt
        updatePodEnergy(strength: boosting ? 1 : 0.35)
        propellerAngle += dt * (25 + throttle * 100)
        for rotor in rotors { rotor.orientation = simd_quatf(angle: propellerAngle, axis: [0, 0, 1]) }
        engineEffects?.update(throttle:crashTime == nil ? throttle : 0,boosting:boosting,dt:dt)
        jetGlow?.scale = [0.46, 0.43, 0.15 + throttle * 0.7]
        for (index, gate) in gates.enumerated() { gate.isEnabled = index == nextCheckpoint }
        for (index, entity) in laserBolts.enumerated() {
            entity.isEnabled = index < bolts.count
            if index < bolts.count { entity.position = bolts[index].position }
        }
        for (index, entity) in self.playerBolts.enumerated() {
            entity.isEnabled = index < playerBolts.count
            if index < playerBolts.count {
                entity.position = playerBolts[index].position
                let velocity = playerBolts[index].velocity
                if simd_length_squared(velocity) > 0.01 { entity.orientation = simd_quatf(from:[0,0,-1],to:simd_normalize(velocity)) }
            }
        }
        for (index, entity) in pursuerEntities.enumerated() {
            entity.isEnabled = index < pursuers.count && crashTime == nil
            if index < pursuers.count {
                entity.position = pursuers[index].position
                let velocity = pursuers[index].velocity
                entity.orientation = simd_length_squared(velocity) > 0.01 ? simd_quatf(from:[0,0,-1],to:simd_normalize(velocity)) : simd_quatf()
            }
        }
        for (index, entity) in racerEntities.enumerated() {
            entity.isEnabled = index < racers.count && racers[index].active && !racers[index].finished && crashTime == nil
            if index < racers.count {
                let racer = racers[index]
                entity.position = racer.position
                entity.orientation = simd_quatf(angle: -racer.heading, axis: [0, 1, 0])
            }
        }
        updateRaceSparks(state: state, boosting: boosting, skidding: skidding, impactEnergy: impactEnergy)
        for (index, pad) in boostPadEntities.enumerated() { pad.isEnabled = !collectedBoostPads.contains(index) }
        for (index, cloud) in clouds.enumerated() where cloud.isEnabled {
            // Recycle a bounded pool of clouds around the flight path.
            if abs(cloud.position.z - state.position.z) > 2700 {
                cloud.position.z = state.position.z - 2400 + Float(index % 7) * 420
                cloud.position.x = terrain.generator.valleyCenter(at: cloud.position.z) + Float(index % 5 - 2) * 620
            }
            cloud.position.x += dt * 3 * terrain.generator.level.windStrength
        }
        if let t = crashTime {
            if let explosion { explosion.scale = SIMD3<Float>(repeating: max(0.01, t * 550)) }
            aircraft.position = crashOrigin + SIMD3<Float>(0, -min(t, 1) * 1.5, 0)
            aircraft.orientation = crashRotation * simd_quatf(angle: min(t, 1) * 0.9, axis: [0, 0, 1])
            for (index, piece) in debris.enumerated() {
                let (entity, velocity) = piece
                var p = crashOrigin + velocity * t + SIMD3<Float>(0, -4.9 * t * t, 0)
                if !awayFromAtmosphere { p.y = max(p.y, terrain.generator.surfaceHeight(x: p.x, z: p.z) + 0.5) }
                entity.position = p
                entity.orientation = simd_quatf(angle: t * Float(index + 1), axis: simd_normalize(SIMD3<Float>(1, 0.5, 0.3)))
                entity.scale = SIMD3<Float>(repeating: max(0.01, 1 - max(0, t - 1.4) * 0.5))
            }
        }
    }

    private func makeHyperspaceScene(reducedDetail: Bool) {
        guard terrain.generator.level.isFreeRoam else { return }
        let portalColors: [(UIColor, UIColor)] = [
            (.systemCyan, .systemBlue), (.systemPurple, .systemPink),
            (.systemOrange, .systemRed), (.systemGreen, .systemYellow)
        ]
        for portalIndex in SpaceChallenge.allCases.indices {
            let portal = Entity()
            let colors = portalColors[portalIndex]
            let primary = UnlitMaterial(color: colors.0.withAlphaComponent(0.95))
            let secondary = UnlitMaterial(color: colors.1.withAlphaComponent(0.84))
            for index in 0..<32 {
                let angle = Float(index) / 32 * 2 * .pi
                let segment = ModelEntity(mesh: .generateBox(size: [8, 31, 10]), materials: [index.isMultiple(of: 2) ? primary : secondary])
                segment.position = [cos(angle) * 116, sin(angle) * 116, 0]
                segment.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
                portal.addChild(segment)
            }
            let coreMaterial = UnlitMaterial(color: colors.0.withAlphaComponent(0.22))
            portal.addChild(ModelEntity(mesh: .generateBox(size: [205, 205, 2]), materials: [coreMaterial]))
            anchor.addChild(portal)
            hyperspacePortals.append(portal)
        }

        let streakColors: [UIColor] = [.white, .systemCyan, .systemBlue, .systemPurple]
        for index in 0..<48 {
            let material = UnlitMaterial(color: streakColors[index % streakColors.count].withAlphaComponent(0.92))
            let streak = ModelEntity(mesh: .generateBox(size: [Float(1 + index % 3), Float(1 + index % 2), Float(95 + index % 5 * 28)]), materials: [material])
            let angle = Float(index) * 2.39996
            let radius = Float(45 + index % 8 * 34)
            streak.position = [cos(angle) * radius, sin(angle) * radius, Float(-250 - index * 43)]
            hyperspaceLights.addChild(streak)
            hyperspaceStreaks.append(streak)
        }
        hyperspaceLights.isEnabled = false
        anchor.addChild(hyperspaceLights)

        spaceBackdrop.addChild(SpaceScenery.makeBackdrop())
        anchor.addChild(universeScenery.root)
        cometScenery = SpaceScenery.makePlanetComets(reducedDetail:reducedDetail)
        anchor.addChild(cometScenery)
        anchor.addChild(residences.root)
        let marker = ModelEntity(mesh:.generateSphere(radius:32),materials:[{
            var material = UnlitMaterial(color:UIColor.systemOrange)
            material.blending = .transparent(opacity:.init(floatLiteral:0.12))
            return material
        }()])
        marker.name = "Marked bounty shield"; marker.isEnabled = false
        anchor.addChild(marker); bountyMarker = marker
        for destination in SpacePlanet.allCases {
            let tint: UIColor = destination == .tatooine ? .systemOrange : destination == .hoth ? .lightGray : destination == .coruscant ? UIColor(red: 0.34, green: 0.38, blue: 0.48, alpha: 1) : .systemGreen
            let planet = ModelEntity(mesh: PlanetSurfaceMesh.make(destination), materials: [ScenicMaterials.globe(UnlitMaterial(color:tint),planet:destination.name)])
            SpaceScenery.decoratePlanet(destination, root:planet)
            PlanetOrbitAtmosphere.add(to:planet,name:destination.name,radius:destination.radius+45,tint:tint)
            planet.position = destination.position
            planet.isEnabled = false; anchor.addChild(planet); planetEntities.append(planet)
            let surface = PlanetSurfaceRenderer(planet:destination,reducedDetail:reducedDetail)
            anchor.addChild(surface.root); surfaceScenes[destination] = surface
        }
        spaceBackdrop.isEnabled = false
        anchor.addChild(spaceBackdrop)

        let rockMaterial = SimpleMaterial(color: UIColor(red: 0.28, green: 0.25, blue: 0.25, alpha: 1), roughness: 1, isMetallic: false)
        for index in 0..<48 {
            let asteroid = ModelEntity(mesh: SpaceScenery.asteroidMesh(variant:index), materials: [rockMaterial])
            asteroid.name = "incoming asteroid \(index + 1)"
            asteroid.isEnabled = false
            anchor.addChild(asteroid)
            asteroidEntities.append(asteroid)
        }
    }

    private func updatePodEnergy(strength: Float) {
        guard let field = podEnergyField else { return }
        let flicker = 0.82 + sin(raceEffectTime * 31) * 0.13 + sin(raceEffectTime * 53) * 0.05
        field.scale = [1, max(0.35, flicker * (0.7 + strength * 0.65)), 0.8 + strength * 0.5]
        field.isEnabled = strength > 0.05
    }

    private func makeRaceEffects() {
        guard terrain.generator.level.isPodRaceTrack else { return }
        let blue = UnlitMaterial(color: UIColor(red: 0.25, green: 0.78, blue: 1, alpha: 0.95))
        let orange = UnlitMaterial(color: UIColor(red: 1, green: 0.48, blue: 0.08, alpha: 0.95))
        for index in 0..<32 {
            let spark = ModelEntity(mesh: .generateBox(size: index.isMultiple(of: 3) ? [0.3, 0.3, 5.5] : [0.2, 0.2, 2.8]),
                                    materials: [index.isMultiple(of: 3) ? orange : blue])
            spark.name = "podrace electric spark \(index)"
            spark.isEnabled = false
            anchor.addChild(spark)
            raceSparks.append(spark)
        }
    }

    private func updateRaceSparks(state: FlightState, boosting: Bool, skidding: Bool, impactEnergy: Float) {
        guard !raceSparks.isEmpty else { return }
        #if canImport(UIKit)
        let reducedMotion = UIAccessibility.isReduceMotionEnabled
        #else
        let reducedMotion = false
        #endif
        let pace = clamp((state.airspeed / max(aircraftType.cruiseSpeed, 1) - 1.2) / 2, 0, 1)
        let speedCount = 5 + Int(pace * 23)
        let requestedCount = max(speedCount, boosting ? 32 : skidding ? 20 : impactEnergy > 0.05 ? 28 : 5)
        let effectLimit = reducedMotion ? 8 : performanceMode || surfaceReducedDetail ? 24 : raceSparks.count
        let activeCount = min(effectLimit, requestedCount)
        let right = state.orientation.act(SIMD3<Float>(1, 0, 0))
        let behind = -state.forward
        for (index, spark) in raceSparks.enumerated() {
            spark.isEnabled = index < activeCount
            guard index < activeCount else { continue }
            let phase = raceEffectTime * Float(18 + index % 7) + Float(index) * 2.17
            if index >= 16 && !reducedMotion {
                // Reuse the same tiny pool for speed lines, kept clear of the racing line.
                let travel = raceEffectTime * (2.5 + pace * 3 + Float(index % 5) * 0.2) + Float(index) * 0.37
                let cycle = travel - floor(travel)
                let side = Float(index.isMultiple(of: 2) ? -1 : 1) * Float(28 + index % 4 * 8)
                let forward = 85 - cycle * 180
                spark.position = state.position + right * side + state.forward * forward + SIMD3<Float>(0, Float(4 + index % 5 * 3), 0)
                spark.orientation = state.orientation
                spark.scale = [0.65, 0.65, 1.2 + pace * 2 + (boosting ? 0.8 : 0)]
                continue
            }
            let side = sin(phase) * (skidding ? 15 : 7) + Float(index % 2 == 0 ? -1 : 1) * 7
            let trail = Float(index % 8) * (boosting ? 5.5 : 2.2 + pace * 1.5)
            let lift = cos(phase * 1.37) * 2 - (skidding ? 4 : 1)
            spark.position = state.position + right * side + behind * (12 + trail) + SIMD3<Float>(0, lift, 0)
            spark.orientation = state.orientation * simd_quatf(angle: sin(phase) * 0.35, axis: [0, 1, 0])
            let violentScale: Float = 0.65 + impactEnergy * 1.8 + (boosting ? 0.6 : 0)
            let width = violentScale * (0.75 + 0.25 * abs(sin(phase)))
            spark.scale = [width, width, width * (1 + pace * 0.8)]
        }
    }

    func beginCrash(state: FlightState) {
        crashScenery = ScenicRegion(terrain: terrain.generator)
        camera.reset()
        crashOrigin = state.position
        crashRotation = state.orientation
        camera.mode = .chase
        for i in 0..<18 {
            let angle = Float(i) * 2.39996
            let material = SimpleMaterial(color: i % 3 == 0 ? .orange : .darkGray, roughness: 1, isMetallic: false)
            let piece = ModelEntity(mesh: .generateBox(size: [0.4, 0.3, Float(i % 3 + 1)]), materials: [material])
            piece.position = crashOrigin
            impact.addChild(piece)
            debris.append((piece, [cos(angle) * 12, Float(i % 5 + 5), sin(angle) * 12]))
        }
    }

    func beginDeathStarExplosion(state: FlightState) {
        let fire = UnlitMaterial(color: UIColor(red: 1, green: 0.38, blue: 0.04, alpha: 0.75))
        let sphere = ModelEntity(mesh: .generateSphere(radius: 1), materials: [fire])
        let z = state.position.z - 430
        sphere.position = [terrain.generator.valleyCenter(at: z), 275, z]
        sphere.scale = SIMD3<Float>(repeating: 0.01)
        anchor.addChild(sphere)
        explosion = sphere
    }

    private func makeGates(_ checkpoints: [Checkpoint]) {
        let material = UnlitMaterial(color: UIColor(red: 1, green: 0.7, blue: 0.27, alpha: 1))
        for checkpoint in checkpoints {
            // One mesh per gate, shared material: 48 bars batched into one entity.
            var positions: [SIMD3<Float>] = []
            var indices: [UInt32] = []
            let isRace = terrain.generator.level.isPodRaceTrack
            let r = checkpoint.radius
            let segments = isRace ? 0 : 64
            for i in 0..<segments {
                let a = Float(i) / Float(segments) * 2 * .pi
                let b = Float(i + 1) / Float(segments) * 2 * .pi
                let base = UInt32(positions.count)
                positions.append([cos(a) * r, sin(a) * r, 0])
                positions.append([cos(b) * r, sin(b) * r, 0])
                positions.append([cos(a) * (r + 3), sin(a) * (r + 3), 0])
                positions.append([cos(b) * (r + 3), sin(b) * (r + 3), 0])
                indices += [base, base + 1, base + 2, base + 1, base + 3, base + 2]
            }
            if isRace {
                // Freestanding pylons flank the route as non-circular turn markers.
                let halfWidth = r * 0.9
                for side: Float in [-1, 1] {
                    let x = side * halfWidth
                    let base = UInt32(positions.count)
                    positions.append(SIMD3<Float>(x - 6, -112, 0))
                    positions.append(SIMD3<Float>(x + 6, -112, 0))
                    positions.append(SIMD3<Float>(x - 6, 82, 0))
                    positions.append(SIMD3<Float>(x + 6, 82, 0))
                    indices += [base, base + 1, base + 2, base + 1, base + 3, base + 2]
                    positions.append(SIMD3<Float>(x - 6, 76, 0))
                    positions.append(SIMD3<Float>(x + 6, 76, 0))
                    positions.append(SIMD3<Float>(x - 6, 88, 0))
                    positions.append(SIMD3<Float>(x + 6, 88, 0))
                    let crown = base + 4
                    indices += [crown, crown + 1, crown + 2, crown + 1, crown + 3, crown + 2]
                }
            }
            var descriptor = MeshDescriptor(name: checkpoint.name)
            descriptor.positions = MeshBuffers.Positions(positions)
            descriptor.primitives = .triangles(indices)
            if let mesh = try? MeshResource.generate(from: [descriptor]) {
                var twoSided = material
                twoSided.faceCulling = .none
                let gate = ModelEntity(mesh: mesh, materials: [twoSided])
                gate.position = checkpoint.position
                if isRace { gate.orientation = simd_quatf(angle: -atan2(checkpoint.normal.x, -checkpoint.normal.z), axis: [0, 1, 0]) }
                anchor.addChild(gate)
                if !isRace { gates.append(gate) }
            }
        }
    }

    private func makeClouds() {
        guard terrain.generator.level != .deathStar && !terrain.generator.level.isPodRace else { return }
        let mesh = MeshResource.generateSphere(radius: 1)
        var material = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.37))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.37))
        for i in 0..<(terrain.generator.level == .storm ? 50 : 35) {
            let cloud = ModelEntity(mesh: mesh, materials: [material])
            cloud.position = [Float(i % 5 - 2) * 610, Float((terrain.generator.level == .storm ? 820 : 1020) + (i % 4) * 120), Float(i / 5) * -670 + 700]
            cloud.scale = [Float(180 + i % 3 * 70), Float(32 + i % 4 * 12), 125]
            anchor.addChild(cloud)
            clouds.append(cloud)
        }
    }

    private func makeTurretsAndBolts() {
        let flash = ModelEntity(mesh:.generateSphere(radius:2.4),materials:[UnlitMaterial(color:.white)])
        flash.scale = [1,1,2]; flash.isEnabled = false; anchor.addChild(flash); muzzleFlash = flash
        let playerMaterial = UnlitMaterial(color: UIColor(red: 0.25, green: 0.9, blue: 1, alpha: 1))
        for _ in 0..<24 {
            let bolt = ModelEntity(mesh: .generateBox(size: [2.4, 2.4, 22]), materials: [playerMaterial])
            bolt.isEnabled = false
            anchor.addChild(bolt)
            playerBolts.append(bolt)
        }
        let positions = DeathStarDefenses(terrain: terrain.generator).turrets
        guard !positions.isEmpty || terrain.generator.level.isFreeRoam else { return }
        let armour = SimpleMaterial(color: UIColor(red: 0.24, green: 0.26, blue: 0.29, alpha: 1),
                                    roughness: 0.45, isMetallic: true)
        let emitter = UnlitMaterial(color: UIColor(red: 1, green: 0.13, blue: 0.06, alpha: 1))
        let baseMesh = MeshResource.generateBox(size: [17, 12, 20])
        let barrelMesh = MeshResource.generateBox(size: [4, 4, 18])
        for position in positions {
            let turret = Entity()
            turret.position = position
            turret.addChild(ModelEntity(mesh: baseMesh, materials: [armour]))
            let barrel = ModelEntity(mesh: barrelMesh, materials: [armour])
            barrel.position = [0, 5, -12]
            turret.addChild(barrel)
            let muzzle = ModelEntity(mesh: .generateSphere(radius: 3), materials: [emitter])
            muzzle.position = [0, 5, -22]
            turret.addChild(muzzle)
            anchor.addChild(turret)
            stationDetails.append(turret)
        }
        let boltMesh = MeshResource.generateSphere(radius: 4)
        for _ in 0..<30 {
            let bolt = ModelEntity(mesh: boltMesh, materials: [emitter])
            bolt.isEnabled = false
            anchor.addChild(bolt)
            laserBolts.append(bolt)
        }
    }

    private func makePursuers() {
        guard terrain.generator.level == .deathStar || terrain.generator.level.isFreeRoam else { return }
        for _ in 0..<3 {
            let fighter = AircraftFactory.make(type: .tieFighter, color: .lightGray)
            fighter.scale = SIMD3<Float>(repeating: 1.3)
            fighter.isEnabled = false
            anchor.addChild(fighter)
            pursuerEntities.append(fighter)
        }
    }

    private func makePodRacers() {
        guard terrain.generator.level.isPodRace else { return }
        let models = PodRaceManager.rivalTypes
        let paints: [UIColor] = [.systemOrange, .systemRed, .systemTeal, .systemYellow, .systemBlue, .systemCyan]
        for index in models.indices {
            let racer = AircraftFactory.make(type: models[index], color: paints[index])
            racer.scale = SIMD3<Float>(repeating: 0.62)
            anchor.addChild(racer)
            racerEntities.append(racer)
        }
    }

    private func makeBoostPads(_ pads: [RaceBoostPad]) {
        guard terrain.generator.level.isPodRace else { return }
        let glow = UnlitMaterial(color: UIColor(red: 0.15, green: 0.86, blue: 1, alpha: 0.95))
        let circuit = RaceCircuit(level: terrain.generator.level)
        if circuit.hasShortcut {
            let a = circuit.shortcutPoint(0), b = circuit.shortcutPoint(1)
            let direction = simd_normalize(b - a)
            for fraction: Float in [0,0.2,0.4,0.6,0.8,1] {
                let arch = Entity(); arch.name = "Cyan shortcut entrance / exit"
                arch.position = circuit.shortcutPoint(fraction)
                arch.orientation = simd_quatf(angle: atan2(-direction.x,-direction.z), axis: [0,1,0])
                for side: Float in [-1,1] {
                    let post = ModelEntity(mesh: .generateBox(size: [5,120,5]), materials: [glow])
                    post.position = [side * 50,0,0]; arch.addChild(post)
                }
                let top = ModelEntity(mesh: .generateBox(size: [105,5,5]), materials: [glow]); top.position.y = 60
                arch.addChild(top); anchor.addChild(arch)
            }
        }
        let base = SimpleMaterial(color: UIColor(red: 0.12, green: 0.22, blue: 0.28, alpha: 1), roughness: 0.42, isMetallic: true)
        for pad in pads {
            let platform = Entity()
            platform.name = "Repulsor boost pad \(pad.id + 1)"
            platform.position = pad.position
            let deck = ModelEntity(mesh: .generateBox(size: [pad.radius * 1.8, 5, 42]), materials: [base])
            platform.addChild(deck)
            for side: Float in [-1, 1] {
                let strip = ModelEntity(mesh: .generateBox(size: [8, 2, 36]), materials: [glow])
                strip.position = [side * pad.radius * 0.55, 4, 0]
                platform.addChild(strip)
            }
            anchor.addChild(platform)
            boostPadEntities.append(platform)
        }
    }

    private static func skyTexture(level: FlightLevel) -> TextureResource? {
        let width = 1024
        let height = 512
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let colors = [UIColor(rgb: level.skyColor).cgColor,
                      UIColor(rgb: level.fogColor).cgColor, UIColor(rgb: level.fogColor).cgColor]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.5, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
        }
        if level != .deathStar {
            // Painted atmospheric layers cost a single texture lookup, without cloud lights.
            let warm = [.canyon,.glacier,.boontaEve,.ordIbanna,.skylands].contains(level)
            let origin = CGPoint(x:CGFloat(width)*0.72,y:CGFloat(height)*0.37)
            let halo = [UIColor(red:1,green:warm ? 0.67:0.88,blue:warm ? 0.35:1,alpha:0.45).cgColor,
                        UIColor.white.withAlphaComponent(0).cgColor]
            if let gradient = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:halo as CFArray,locations:[0,1]) {
                context.drawRadialGradient(gradient,startCenter:origin,startRadius:0,endCenter:origin,endRadius:210,options:[])
            }
            if level != .storm && level != .narShaddaa {
                context.setFillColor(UIColor(red:1,green:0.92,blue:0.72,alpha:0.95).cgColor)
                context.fillEllipse(in:CGRect(x:origin.x-13,y:origin.y-13,width:26,height:26))
                if [.canyon,.boontaEve,.ordIbanna].contains(level) {
                    context.setFillColor(UIColor(red:1,green:0.6,blue:0.31,alpha:0.9).cgColor)
                    context.fillEllipse(in:CGRect(x:origin.x+48,y:origin.y-6,width:16,height:16))
                }
            }
            for band in 0..<8 {
                let base = CGFloat(height)*(0.22+CGFloat(band)*0.032)
                let path = CGMutablePath()
                for step in 0...96 {
                    let x = CGFloat(step)*CGFloat(width)/96
                    let wave = sin(x*0.012+CGFloat(band)*1.7)*4 + sin(x*0.031+CGFloat(band))*2
                    let point = CGPoint(x:x,y:base+wave)
                    if step == 0 { path.move(to:point) } else { path.addLine(to:point) }
                }
                for step in stride(from:96,through:0,by:-1) {
                    let x = CGFloat(step)*CGFloat(width)/96
                    let wave = sin(x*0.012+CGFloat(band)*1.7)*4 + sin(x*0.031+CGFloat(band))*2
                    path.addLine(to:CGPoint(x:x,y:base+wave+CGFloat(3+band%3*2)))
                }
                path.closeSubpath()
                context.setFillColor(UIColor.white.withAlphaComponent(level == .storm ? 0.035:0.075).cgColor)
                context.addPath(path); context.fillPath()
            }
        }
        if level == .deathStar {
            var seed: UInt32 = 1977
            context.setFillColor(UIColor.white.cgColor)
            for _ in 0..<170 {
                seed = seed &* 1664525 &+ 1013904223
                let x = CGFloat(seed % UInt32(width))
                seed = seed &* 1664525 &+ 1013904223
                let y = CGFloat(seed % 356)
                let radius = CGFloat((seed >> 8) % 3 + 1) * 0.45
                context.fillEllipse(in: CGRect(x: x, y: y, width: radius, height: radius))
            }
        }
        guard let cgImage = context.makeImage() else { return nil }
        return try? TextureResource(image: cgImage, options: .init(semantic: .color))
    }
}

/// One mesh per world, prepared once. Coruscant uses stepped blocks rather than smooth hills.
@MainActor
private enum PlanetSurfaceMesh {
    static func make(_ planet: SpacePlanet) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        func direction(_ i: Int, _ j: Int) -> SIMD3<Float> {
            let lat = Float(i) * .pi / Float(SpacePlanet.latitudeSegments)
            let lon = Float(j) * 2 * .pi / Float(SpacePlanet.longitudeSegments)
            return [sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon)]
        }
        func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
            func triangle(_ p: SIMD3<Float>, _ q: SIMD3<Float>, _ r: SIMD3<Float>) {
                let cross = simd_cross(q - p, r - p)
                guard simd_length_squared(cross) > 0.000001 else { return }
                let start = UInt32(positions.count)
                positions += [p, q, r]
                normals += Array(repeating: simd_normalize(cross), count: 3)
                indices += [start, start + 1, start + 2]
            }
            triangle(a, b, c); triangle(a, c, d)
        }

        for i in 0..<SpacePlanet.latitudeSegments {
            for j in 0..<SpacePlanet.longitudeSegments {
                let a = direction(i, j), b = direction(i, j + 1)
                let c = direction(i + 1, j + 1), d = direction(i + 1, j)
                if planet == .coruscant {
                    let height = planet.height(latitude: i, longitude: j)
                    let r = planet.radius + height
                    quad(a * r, b * r, c * r, d * r)
                    quad(a * planet.radius, b * planet.radius, b * r, a * r)
                    quad(b * planet.radius, c * planet.radius, c * r, b * r)
                    quad(c * planet.radius, d * planet.radius, d * r, c * r)
                    quad(d * planet.radius, a * planet.radius, a * r, d * r)
                } else {
                    quad(a * (planet.radius + planet.height(latitude: i, longitude: j)),
                         b * (planet.radius + planet.height(latitude: i, longitude: j + 1)),
                         c * (planet.radius + planet.height(latitude: i + 1, longitude: j + 1)),
                         d * (planet.radius + planet.height(latitude: i + 1, longitude: j)))
                }
            }
        }
        var descriptor = MeshDescriptor(name: planet.name + " explorable surface")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return (try? MeshResource.generate(from: [descriptor])) ?? .generateSphere(radius: planet.radius)
    }
}


/// Outward headlamps stay active when the cockpit hides the aircraft model.
@MainActor
final class ShipLighting {
    let root=Entity()
    private let lamp=Entity(),starboard=Entity()
    private let lenses:[ModelEntity]
    private var beams:[ModelEntity]=[]
    private var configuredReduced:Bool?
    init() {
        root.name="Pilot controlled ship lights";lamp.name="Forward ship spotlight";starboard.name="Starboard ship spotlight"
        let mesh=MeshResource.generateSphere(radius:1),paint=UnlitMaterial(color:.init(red:0.78,green:0.90,blue:1,alpha:1))
        lenses=(0..<2).map { i in let lens=ModelEntity(mesh:mesh,materials:[paint]);lens.name="Ship lamp lens \(i+1)";return lens }
        root.addChild(lamp);root.addChild(starboard);for lens in lenses { root.addChild(lens) }
        if let resource=Self.beamResource {
            for i in 0..<2 { let beam=ModelEntity(mesh:resource.0,materials:[resource.1]);beam.name="Outward headlight beam \(i+1)";beam.components.set(DynamicLightShadowComponent(castsShadow:false));root.addChild(beam);beams.append(beam) }
        }
        root.isEnabled=false
    }
    private static let beamResource:(MeshResource,UnlitMaterial)? = {
        var positions:[SIMD3<Float>]=[],normals:[SIMD3<Float>]=[],uv:[SIMD2<Float>]=[],indices:[UInt32]=[]
        for ring in 0...1 { for i in 0...24 {
            let a=Float(i)*2 * .pi/24,r:Float=ring == 0 ? 0.0005:0.07
            positions.append([cos(a)*r,sin(a)*r,-Float(ring)])
            normals.append(simd_normalize(SIMD3<Float>(cos(a),sin(a),0.07)));uv.append([Float(i)/24,Float(ring)])
        } }
        for i in 0..<24 { let a=UInt32(i),b=a+25;indices += [a,b,a+1,a+1,b,b+1] }
        var descriptor=MeshDescriptor(name:"Shared fading headlight cone")
        descriptor.positions = .init(positions);descriptor.normals = .init(normals);descriptor.textureCoordinates = .init(uv);descriptor.primitives = .triangles(indices)
        guard let mesh=try? MeshResource.generate(from:[descriptor]) else { return nil }
        let format=UIGraphicsImageRendererFormat();format.scale=1
        let image=UIGraphicsImageRenderer(size:CGSize(width:8,height:64),format:format).image { context in
            for row in 0..<64 {
                let t=Float(row)/63,fade=min(1,t/0.08)*pow(1-t,1.6)*0.35
                context.cgContext.setFillColor(UIColor(white:1,alpha:CGFloat(fade)).cgColor)
                context.cgContext.fill(CGRect(x:0,y:row,width:8,height:1))
            }
        }
        var material=UnlitMaterial(color:UIColor(red:0.70,green:0.84,blue:1,alpha:1));material.faceCulling = .none
        material.blending = .transparent(opacity:.init(floatLiteral:0.08))
        if let cg=image.cgImage,let texture=try? TextureResource.generate(from:cg,options:.init(semantic:.color)) { material.color = .init(tint:UIColor(red:0.70,green:0.84,blue:1,alpha:1),texture:.init(texture)) }
        return (mesh,material)
    }()
    func update(state:FlightState,aircraft:AircraftType,enabled:Bool,reduced:Bool,showLenses:Bool=true,beamVisibility:Float=0.4) {
        root.isEnabled=enabled
        guard enabled else { return }
        root.position=state.position;root.orientation=state.orientation
        let height=max(0.6,aircraft.bodyRadius*0.25),nose = -aircraft.length*0.48,spread=min(aircraft.wingspan*0.16,12)
        let range:Float=reduced ? 350:650
        if configuredReduced != reduced {
            for light in [lamp,starboard] {
                light.components.set(SpotLightComponent(color:.init(red:0.82,green:0.91,blue:1,alpha:1),intensity:reduced ? 5_000_000:3_000_000,innerAngleInDegrees:24,outerAngleInDegrees:reduced ? 65:55,attenuationRadius:range))
            }
            configuredReduced=reduced
        }
        starboard.isEnabled = !reduced
        for i in 0..<2 {
            let side:Float=i == 0 ? -1:1
            let position=SIMD3<Float>(side*spread,height,nose)
            let outward=simd_quatf(angle:-side*0.12,axis:[0,1,0])*simd_quatf(angle:-0.06,axis:[1,0,0])
            let light=i == 0 ? lamp:starboard
            light.position=reduced && i == 0 ? [0,height,nose]:position
            light.orientation=reduced && i == 0 ? simd_quatf(angle:-0.06,axis:[1,0,0]):outward
            lenses[i].isEnabled=showLenses;lenses[i].position=position
            lenses[i].scale=SIMD3(repeating:max(0.18,min(0.7,aircraft.bodyRadius*0.04)))
            if beams.indices.contains(i) {
                beams[i].position=position;beams[i].orientation=outward;beams[i].scale=SIMD3(repeating:range*0.45)
                beams[i].components.set(OpacityComponent(opacity:beamVisibility))
            }
        }
    }
}
