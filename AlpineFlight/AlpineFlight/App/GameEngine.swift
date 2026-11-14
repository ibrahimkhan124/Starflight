import SwiftUI
import RealityKit
import QuartzCore

enum GamePhase { case title, flying, paused, crashed, completed }

struct PortalHUD: Identifiable {
    let id: Int
    let name: String
    let distance: Float
}

struct HUDSnapshot {
    var checkpointDistanceLabel: String { celestialDistanceLabel ?? Self.distanceLabel(checkpointDistance) }
    static func distanceLabel(_ checkpointDistance: Float) -> String {
        guard checkpointDistance.isFinite else { return "—" }
        let metres = max(0, checkpointDistance)
        return metres < 1000 ? "\(Int(metres.rounded())) m" : String(format: "%.1f km", metres / 1000)
    }
    var shieldNeedsAttention: Bool { shield < 100 }
    var fuelPercent: Float = 100
    var lowFlightPoints = 0
    var altitude = 430
    var clearance = 0
    var airspeed = 101
    var heading = 0
    var checkpointDistance: Float = 0
    var checkpointBearing: Float = 0
    var checkpointName = "Pine Saddle"
    var passed = 0
    var warning: String?
    var elapsed: Float = 0
    var distance: Float = 0
    var difficulty: Float = 0
    var pitch: Float = 0
    var roll: Float = 0
    var timeRemaining: Float?
    var pursuers = 0
    var scannerDistance: Float?
    var shield = 100
    var boostCharge = 100
    var racePosition = 1
    var raceFieldSize = 5
    var lap = 1
    var nearPlanetSurface = false
    var inSpace = false
    var inHyperspace = false
    var hyperspaceRemaining: Float = 0
    var portals: [PortalHUD] = []
    var freeRoamSector = "Central rendezvous"
    var activityStatus = ""
    var landingAssist = false
    var landed = false
    var nearLandingPad = false
    var missionAvailable = false
    var missionActive = false
    var activityTarget = ""
    var verticalSpeed: Float = 0
    var completedMissions = 0
    var landings = 0
    var asteroidsDestroyed = 0
    var racePlayerProgress: Float = 0
    var raceCheckpointProgress: Float = 0
    var raceRivalProgress: [Float] = []
    var raceDriftCharge = 0
    var raceBurst = false
    var raceDrafting = false
    var cityCanDock = false
    var cityDocked = false
    var cityDepartReady = false
    var cityJobDetail = ""
    var controlAxes: SIMD2<Float> = .zero
    var weaponsActive = false
    var weaponHit = ""
    var celestialDistanceLabel:String?
}

@MainActor
final class GameEngine: ObservableObject {
    var editingFlightBanner = false
    private var lastGravityHaptic: CFTimeInterval = 0
    @Published private(set) var phase: GamePhase = .title
    @Published private(set) var hud = HUDSnapshot()
    @Published private(set) var cityJobs = CoruscantJobs()
    @Published private(set) var cityJobNotice: String?
    @Published private(set) var bounty = CityBountyHunt()
    private var bountyState = CityBountyHunt()
    private var planetComets = PlanetCometField()
    private var universe = UniverseFlight()
    private var universeTargetStar:Int?
    private var universeTargetHole = false
    private var solarTarget = "Earth"
    private var departureThrottle:Float = 0
    @Published private(set) var universeTravelID = 0
    @Published private(set) var astronomyEnabled = false
    @Published private(set) var astronomyReadout = "Point the ship towards a star."

    private var cometImpactUntil:Float = 0
    private var cityJobState = CoruscantJobs()
    private var cityDock = CityDocking()
    private var homeDock = HomeDocking()
    @Published private(set) var homeLanding = HomeDocking()
    @Published private(set) var interiorHome:CityPlot?
    private var cityNoticeUntil: Float = 0
    private var controlAxes: SIMD2<Float> = .zero
    private var shotUntil: Float = 0
    private var hitUntil: Float = 0
    private var hitDescription = ""
    @Published private(set) var arrivingPlanetName: String?
    @Published private(set) var ready = false
    @Published private(set) var preparationProgress: Float = 0
    @Published private(set) var error: String?
    @Published private(set) var economy = FlightEconomy()
    @Published private(set) var droidAssistMode: DroidAssistMode = .off
    private var droidAssist = DroidFlightAssist()
    @Published private(set) var oreSurvey: OreSurvey?
    private var oreScanRequested = false
    @Published private(set) var starInspection: StarInspection?
    private var menuPreviewAngle: Float = 0
    var oreScanVisible: Bool { phase == .flying && miningAvailable && oreSurvey != nil }
    func scanOre() {
        guard miningAvailable else { acknowledge("ORE SCAN IS AVAILABLE IN SPACE FREE ROAM"); return }
        oreSurvey = nil; miningEnabled = true; oreScanRequested = true
    }
    func setDroidAssist(_ mode: DroidAssistMode) {
        guard phase == .flying || phase == .paused else { return }
        guard !aircraft.isPodracer, !arenaSelected else { acknowledge("MANUAL CONTROL FOR RACES AND DUELS"); return }
        guard mode != .altitude || !hud.inSpace || currentSurfacePlanet != nil else { acknowledge("NO ALTITUDE HOLD IN ORBIT · USE LEVEL SHIP"); return }
        droidAssist.engage(mode, state: state); droidAssistMode = mode
        acknowledge(mode.title.uppercased() + (mode == .off ? "" : " · STEER TO TAKE OVER"))
    }
    @Published var miningEnabled = false
    @Published private(set) var minedRewards: [MinedMineralReward] = []
    @Published private(set) var tradeNotice = "Mine asteroids in space free roam, then sell your cargo at a connected planet."

    var miningAvailable: Bool { universe.surfaceBody == nil && isRelaxedSpace && hud.inSpace && currentSurfacePlanet == nil && !hud.inHyperspace }
    var tradingPort: SpacePlanet? {
        guard isRelaxedSpace,universe.homePlanets else { return nil }
        if let planet = currentSurfacePlanet { return planet }
        guard hud.inSpace, !hud.inHyperspace else { return nil }
        return SpacePlanet.allCases.first { simd_distance(state.position,$0.position) <= $0.radius+900 }
    }
    func openTradeRoute(_ route: SpaceTradeRoute) {
        var saved = FlightEconomy.load(from:progress.defaults)
        guard saved.openTradeRoute(route) else { tradeNotice = "Route already open, or not enough credits."; return }
        saved.save(to:progress.defaults); economy = saved
        tradeNotice = "Opened " + route.name + ". Visit either planet to trade."
    }
    func sellMiningCargo() {
        guard let port = tradingPort else { tradeNotice = "Approach a planet within 900 m of its surface, or enter it, to trade."; return }
        var saved = FlightEconomy.load(from:progress.defaults)
        let soldUnits = saved.trading?.used ?? 0
        let credits = saved.sellMineralCargo(at:port)
        guard credits > 0 else { tradeNotice = "Open a route serving this planet and bring some cargo to sell."; return }
        saved.save(to:progress.defaults); economy = saved
        tradeNotice = "Sold cargo at \(port.name) for \(credits) credits."
        recordStoryEvent(.sold(port,soldUnits))
    }
    func beginTradeRun(_ route: SpaceTradeRoute) {
        guard let port = tradingPort else { tradeNotice = "Visit one of this route’s planets to start a run."; return }
        var saved = FlightEconomy.load(from:progress.defaults)
        guard saved.beginTradeRun(route,from:port) else { tradeNotice = "Open this route first and finish any current run."; return }
        saved.save(to:progress.defaults); economy = saved
        if let destination = saved.trading?.delivery?.destination {
            selectSpaceDestination(destination)
            tradeNotice = "Trade run to \(destination.name). Sell cargo there for a 20% route bonus."
        }
    }
    private func collectAsteroidMinerals(_ minerals: [TradeMineral]) {
        guard miningEnabled, miningAvailable, !minerals.isEmpty else { return }
        var saved = FlightEconomy.load(from:progress.defaults)
        var receipts: [String] = []
        var rewards: [MinedMineralReward] = []
        for material in minerals {
            let units = saved.collectMineral(material,quantity:Int.random(in:1...3))
            if units > 0 { saved.discoverOre(material); receipts.append("+\(units) \(material.name)"); rewards.append(.init(mineral: material, quantity: units)) }
        }
        saved.save(to:progress.defaults); economy = saved
        let receipt = receipts.isEmpty ? "CARGO HOLD FULL · SELL AT A PLANET" : receipts.joined(separator:" · ")
        minedRewards = rewards
        recordStoryEvent(.mined(rewards.reduce(0) { $0+$1.quantity }))
        tradeNotice = receipt; hitDescription = receipt.uppercased(); hitUntil = elapsed+2.5
    }
    @Published private(set) var pilotBook = PilotLogbook()
    @Published private(set) var pilotDraft: PilotFlightRecord?
    @Published private(set) var pilotNotice: String?
    private let pilotStore: PilotLogbookStore
    private var pilotTracker: PilotFlightTracker?
    private var pilotSaveClock: Float = 0
    @Published var settings: GameSettings
    @Published var throttle: Float = 0.65
    @Published private(set) var cameraMode: FlightCamera = .chase
    @Published private(set) var bestGates: Int
    @Published private(set) var motionStatus = ""
    @Published private(set) var crashCause: String?
    @Published private(set) var droidMessage: String?
    @Published private(set) var customShip: CustomShip?
    @Published private(set) var arenaSelected = false
    @Published private(set) var arenaHUD = ArenaSnapshot()
    private(set) var arenaDifficulty = ArenaDifficulty.pilot
    private(set) var arenaFormat = ArenaFormat.duel
    @Published private(set) var arenaRewardEarned = 0
    private var arena = ArenaBattle()
    @Published private(set) var customLevel: CustomLevelDefinition?
    let creations = CustomContentStore()
    let account:StarflightAccount

    let motion = MotionController()
    let hand = HandController()
    let droidVoice = DroidVoiceController()
    var stick = SIMD2<Float>.zero
    var rudder: Float = 0
    var firing = false
    var boosting = false
    var skidding = false
    private var keyboard = KeyboardControls()
    private(set) var state = FlightState()
    private(set) var terrain: TerrainGenerator
    private var lowFlightScore = LowFlightScore()
    private var fuel = FlightFuel()
    private var lastBankedFLP = 0
    private var travelScore: LowFlightScore?
    private var physics: FlightPhysics
    private var collision: CollisionSystem
    private var checkpoints: CheckpointSystem
    private var defenses: DeathStarDefenses
    private var weapons = WeaponSystem()
    private var race: PodRaceManager
    private var activities = FreeRoamActivities()
    private var hyperspace: HyperspaceManager
    private let progress: FlightProgress
    private let audio = FlightAudio()
    private var world: WorldRenderer?
    private weak var view: ARView?
#if os(macOS)
    private var displayTimer: Timer?
#else
    private var displayLink: CADisplayLink?
#endif
    private var lastTimestamp: CFTimeInterval = 0
    private var renderPreviousState = FlightState()
    private var accumulator: Float = 0
    private var hudClock: Float = 0
    private var terrainClock: Float = 0
    private var elapsed: Float = 0
    private var distance: Float = 0
    @Published private(set) var storyDebrief = false
    @Published private(set) var storyLaunching = false
    private var storySession: StoryChapter?
    private var pendingStory: StoryChapter?
    private var storyWeather: FlightWeather?
    private var effectiveWeather: FlightWeather { storyWeather ?? settings.weather }
    private var weatherActive: Bool {
        !arenaSelected && !level.isPodRace && level != .deathStar && interiorHome == nil
            && (hyperspace.zone == .atmosphere || hyperspace.surfacePlanet != nil)
    }
    @Published private(set) var replayActive = false
    @Published private(set) var replayFraction: Float = 0
    @Published private(set) var adventureMessage = "Choose a route, career, or optional emergency contract."
    @Published private(set) var activeRouteName: String?
    @Published private(set) var distressAvailable = false
    private var flightReplay = FlightReplayBuffer()
    private var lapRecording = LapGhostRecorder()
    private var emergencyFlight: EmergencyFlightContract?
    private var emergencyDocking = false
    private var emergencyContext = ""
    private var routePlan: [SpacePlanet] = []
    private var routeStep = 0
    private var distressOffered = false
    private var droidAdvisoryAt: Float = 0
    private var crashTime: Float?
    private var underFireUntil: Float = 0
    private var shield: Float = 100
    private var suspended = false
    private var droidAxes = SIMD2<Float>.zero
    private var droidSteerUntil: Float = 0
    private var droidFireUntil: Float = 0
    private var droidBoostUntil: Float = 0
    private var droidRepairReadyAt: Float = 0
    private var audioWasFlying = false

    var aircraft: AircraftType { settings.aircraft }
    var level: FlightLevel { settings.level }
    var aircraftName: String { customShip?.name ?? aircraft.name }
    var levelName: String { if let chapter = storySession { return "Chapter \(chapter.number) · " + chapter.title }; return arenaSelected ? (arenaFormat == .trio ? "Trio battle" : "Arena duel") : level.isFreeRoam && settings.spaceFreeRoam ? "Space Free Roam" : customLevel?.name ?? level.name }
    var customShipURL: URL? { customShip.map { creations.shipURL($0) } }
    var nextLevel: FlightLevel? { customLevel == nil ? level.next : nil }
    var gateCount: Int { checkpoints.checkpoints.count * checkpoints.laps }
    var racePositionLabel: String {
        switch hud.racePosition { case 1: return "1st"; case 2: return "2nd"; case 3: return "3rd"; default: return "\(hud.racePosition)th" }
    }
    var racePositionTitle: String {
        switch hud.racePosition { case 1: return "1ST PLACE"; case 2: return "2ND PLACE"; case 3: return "3RD PLACE"; default: return "\(hud.racePosition)TH PLACE" }
    }
    var deathStarTimeLimit: Float { max(140, level.routeLength / aircraft.cruiseSpeed * 1.65) }
    var weatherDescription: String {
        let strength = level.windStrength * hud.difficulty
        if level.isFreeRoam {
            if universeActive { return universe.galaxy.name.uppercased() + " · " + universe.location.uppercased() }
            if let planet = hyperspace.surfacePlanet { return PlanetExploration(planet:planet).name.uppercased() + " · PLANET SURFACE" + (weatherActive && effectiveWeather != .clear ? " · " + effectiveWeather.title.uppercased():"") }
            switch hyperspace.zone {
            case .atmosphere: return "PORTAL HUB · FREE ROAM"
            case .hyperspace: return "LIGHTSPEED · \(hyperspace.challenge.name.uppercased())"
            case .asteroidField: return hyperspace.relaxedSpace ? "ORBITAL EXPLORATION · FREE ROAM" : "DEEP SPACE · \(hyperspace.challenge.name.uppercased())"
            }
        }
        if weatherActive && effectiveWeather != .clear { return effectiveWeather.title.uppercased() + " · WATCH CLEARANCE" }
        if level == .storm { return "GUSTS · LOW VISIBILITY" }
        return strength < 0.35 ? "LIGHT WINDS · CLEAR" : strength < 0.7 ? "CROSSWIND · HAZE" : "GUSTS · LOW VISIBILITY"
    }

    init(defaults: UserDefaults = .standard) {
        account = StarflightAccount(defaults:defaults)
        let pilotStore = PilotLogbookStore(defaults:defaults)
        self.pilotStore = pilotStore
        self.pilotBook = pilotStore.recover()
#if DEBUG
        if ProcessInfo.processInfo.environment["STARFLIGHT_PILOT_FIXTURE"] == "sample" {
            var sample = PilotLogbook()
            for index in 0..<120 {
                let end = Date().addingTimeInterval(Double(index-119)*86400)
                var flight = PilotFlightRecord(startedAt:end.addingTimeInterval(-240),endedAt:end,aircraft:"T-65 X-wing",route:"Outer Rim")
                flight.outcome = index < 65 && index.isMultiple(of:17) ? .crashed:.returned
                flight.seconds = 240; flight.metres = 24000
                flight.stallSeconds = Double(max(0,12-index/10))
                flight.controlledTurns = index/12; flight.soaringClimbs = index/30
                flight.closeShaves = index.isMultiple(of:8) ? 1:0
                flight.visitedPlanets = ["hoth","endor","tatooine","coruscant"]
                flight.hothRoundTrip = index == 119
                sample.append(flight)
            }
            _ = sample.unlock(at:Date()); pilotStore.save(sample); self.pilotBook = sample
        }
#endif
        var settings = GameSettings(defaults: defaults)
        var storedEconomy = FlightEconomy.load(from:defaults)
#if DEBUG
        if ProcessInfo.processInfo.environment["STARFLIGHT_ECONOMY_FIXTURE"] == "funded" {
            storedEconomy = FlightEconomy(); storedEconomy.earn(lowFlightPoints:20000)
            storedEconomy.save(to:defaults)
        }
#endif
#if DEBUG
        if ProcessInfo.processInfo.environment["STARFLIGHT_ECONOMY_FIXTURE"] == "spares" {
            storedEconomy = FlightEconomy()
            for ship in AircraftType.blueprintFleet { storedEconomy.grant(ship,count:ship.blueprintRequirement+2) }
            storedEconomy.save(to:defaults)
        }
#endif
#if DEBUG
        if ProcessInfo.processInfo.environment["STARFLIGHT_HOME_FIXTURE"] == "landing" {
            storedEconomy = FlightEconomy(); storedEconomy.earn(lowFlightPoints:40000)
            _ = storedEconomy.buyHome(.aurora)
            for item in [InteriorItem.lounge,.holotable,.aquarium] { _ = storedEconomy.buyInterior(item,in:.aurora) }
            storedEconomy.save(to:defaults)
        }
        if ProcessInfo.processInfo.environment["STARFLIGHT_HOME_FIXTURE"] == "furnishings" {
            storedEconomy = FlightEconomy(); storedEconomy.earn(lowFlightPoints:40000)
            _ = storedEconomy.buyHome(.aurora)
            for item in [InteriorItem.floorLamp,.pendant,.nebulaPainting,.sunsetPainting,.cabinet,.patioLounge,.lantern,.fountain,.planter] { _ = storedEconomy.buyInterior(item,in:.aurora) }
            _ = storedEconomy.placeInterior(.floorLamp,in:.aurora,at:RoomPlacement(x:4,z:11))
            _ = storedEconomy.placeInterior(.patioLounge,in:.aurora,at:RoomPlacement(x:4,z:10))
            _ = storedEconomy.placeInterior(.lantern,in:.aurora,at:RoomPlacement(x:11,z:13.5))
            storedEconomy.save(to:defaults)
        }
#endif
#if DEBUG && targetEnvironment(simulator)
        // Isolated UI acceptance fixtures use the normal campaign rules, never real account data.
        let storyFixture = ProcessInfo.processInfo.environment["STARFLIGHT_STORY_FIXTURE"]
        if ["lifeline","ending","hoth","endor"].contains(storyFixture ?? "") {
            storedEconomy = FlightEconomy(); storedEconomy.earn(lowFlightPoints:20000)
            if storyFixture == "hoth" { storedEconomy.chooseStoryApproach(.covert) }
            let cargo = storyFixture == "hoth" ? 4:3
            let events: [[StoryEvent]] = [[.cityJob(.spaceportLink),.orbit(.coruscant)], [.mined(cargo),.sold(.tatooine,cargo)],
                [.scout(.hoth,0),.scout(.hoth,1),.scout(.hoth,2),.orbit(.hoth)], [.scout(.endor,0),.scout(.endor,1),.orbit(.endor)],
                [.bounty(.runaway),.orbit(.coruscant)], [.repaired(.engine)], [.route(.deathStar)]]
            for chapter in events.prefix(storyFixture == "ending" ? 7 : storyFixture == "hoth" ? 2 : storyFixture == "endor" ? 3:5) {
                storedEconomy.beginStory(); for event in chapter { _ = storedEconomy.recordStory(event) }
            }
            storedEconomy.save(to:defaults)
        }
#endif
        if !storedEconomy.unlocked(settings.aircraft) { settings.aircraft = .kestrel; settings.save(defaults:defaults) }
        self.economy = storedEconomy
        self.settings = settings
        terrain = TerrainGenerator(seed: settings.level.seed, level: settings.level)
        physics = FlightPhysics(aircraft: settings.aircraft)
        collision = CollisionSystem(terrain: terrain, aircraft: settings.aircraft)
        checkpoints = CheckpointSystem(terrain: terrain, aircraft: settings.aircraft)
        defenses = DeathStarDefenses(terrain: terrain)
        race = PodRaceManager(terrain: terrain, aircraft: settings.aircraft)
        hyperspace = HyperspaceManager(terrain: terrain)
        progress = FlightProgress(defaults: defaults)
        bestGates = progress.best(for: settings.level)
        resetFlight()
        droidVoice.onCommand = { [weak self] command in self?.handleDroidCommand(command) }
    }

    func refreshPilotProgress() {
        var latest = pilotStore.load()
        let draft = pilotTracker?.snapshot()
        if let draft { pilotStore.checkpoint(draft) }
        let earned = latest.unlock(draft:draft,at:Date())
        if !earned.isEmpty {
            pilotStore.save(latest)
            pilotNotice = "Well done! " + earned.map(\.title).joined(separator:" · ")
        }
        if pilotBook != latest { pilotBook = latest }
        if pilotDraft != draft { pilotDraft = draft }
        pilotSaveClock = 0
    }
    func dismissPilotNotice(_ notice:String) { if pilotNotice == notice { pilotNotice = nil } }
    private func finishPilotFlight(_ outcome:PilotFlightOutcome) {
        guard let tracker = pilotTracker else { return }
        let flight = tracker.finished(outcome)
        var latest = pilotStore.load()
        let previousReviews = latest.reviews.count
        if latest.append(flight) {
            let earned = latest.unlock(at:flight.endedAt)
            var messages = earned.isEmpty ? [] : ["Well done! "+earned.map(\.title).joined(separator:" · ")]
            if latest.reviews.count > previousReviews, let review = latest.latestReview {
                messages.append("30-flight review: "+review.rank.rawValue+" · "+String(format:"%.0f/100",review.score))
            }
            if !messages.isEmpty { pilotNotice = messages.joined(separator:" · ") }
            pilotStore.save(latest)
        }
        pilotStore.clearDraft(flight.id)
        pilotBook = latest; pilotDraft = nil; pilotTracker = nil; pilotSaveClock = 0
    }

    func uploadPlayerSave() async {
        guard phase == .title else { account.report(AccountError.message("Return to base before saving online.")); return }
        bankFlightRewards()
        do { await account.upload(try PlayerSaveArchive.capture(defaults:progress.defaults,creationsURL:creations.storageURL,customShipID:customShip?.id,customLevelID:customLevel?.id)) }
        catch { account.report(error) }
    }
    func downloadPlayerSave() async {
        guard phase == .title, let user = account.userID else { return }
        do {
            let archive = try await account.download()
            guard phase == .title, account.userID == user else { throw AccountError.message("Return to base and sign in to the same account before loading progress.") }
            try archive.restore(defaults:progress.defaults,creationsURL:creations.storageURL)
            lowFlightScore = LowFlightScore(); lastBankedFLP = 0
            pilotTracker = nil; pilotDraft = nil
            settings = GameSettings(defaults:progress.defaults)
            economy = FlightEconomy.load(from:progress.defaults)
            pilotBook = pilotStore.load(); creations.reload()
            customLevel = creations.levels.first { $0.id == archive.customLevelID }
            customShip = creations.ships.first { $0.id == archive.customShipID }; arenaSelected = false
            physics = FlightPhysics(aircraft:aircraft)
            configureLevel(settings.level)
            account.didRestore(archive)
        } catch { account.report(error) }
    }
    func autoSavePlayerIfReady() async {
        guard phase == .title, account.signedIn, account.hasCheckedSave, !account.needsSaveChoice else { return }
        do { await account.autoSave(try PlayerSaveArchive.capture(defaults:progress.defaults,creationsURL:creations.storageURL,customShipID:customShip?.id,customLevelID:customLevel?.id)) }
        catch { account.report(error) }
    }

    func buyBlueprintPack(_ pack:BlueprintPack) -> String? {
        guard phase == .title || phase == .paused else { return nil }
        bankFlightRewards()
        var rng = SystemRandomNumberGenerator()
        let receipt = economy.buy(pack,rng:&rng)
        economy.save(to:progress.defaults)
        return receipt
    }
    func sellExtraBlueprints(for ship: AircraftType) -> Int {
        guard phase == .title || phase == .paused else { return 0 }
        bankFlightRewards()
        let proceeds = economy.sellExtras(for:ship)
        economy.save(to:progress.defaults)
        return proceeds
    }
    func editPilotProfile(name: String, suit: String, species: String? = nil) {
        bankFlightRewards(); economy.editProfile(name: name, suit: suit, species: species); economy.save(to: progress.defaults)
    }
    func buyAvatarAccessory(_ item: AvatarAccessory) -> Bool {
        guard phase == .title || phase == .paused else { return false }
        bankFlightRewards(); let bought = economy.buyAccessory(item); economy.save(to: progress.defaults); return bought
    }
    func equipAvatarAccessory(_ item: AvatarAccessory?) {
        bankFlightRewards(); economy.equipAccessory(item); economy.save(to: progress.defaults)
    }
    func spinDailyWheel(at date:Date = Date()) -> DailyPrize? {
        guard phase == .title || phase == .paused else { return nil }
        bankFlightRewards()
        var rng = SystemRandomNumberGenerator()
        let prize = economy.spin(at:date,rng:&rng)
        economy.save(to:progress.defaults)
        return prize
    }
    private func bankFlightRewards() {
        // Merge against the latest shared save, including other windows' purchases or spins.
        var stored = FlightEconomy.load(from:progress.defaults)
        let earned = max(0,lowFlightScore.points-lastBankedFLP)
        if earned > 0 {
            stored.earn(lowFlightPoints:earned); lastBankedFLP = lowFlightScore.points
            stored.save(to:progress.defaults)
        }
        if economy != stored { economy = stored }
    }

    func best(for level: FlightLevel) -> Int { progress.best(for: level) }

    /// Browse owned ships only; locked ships remain in the planner and shop.
    func cycleHangarShip(_ direction: Int) {
        let owned = AircraftType.allCases.filter { economy.unlocked($0) }
        guard phase == .title, !owned.isEmpty else { return }
        let index = owned.firstIndex(of: aircraft) ?? 0
        selectAircraft(owned[(index + (direction < 0 ? -1 : 1) + owned.count) % owned.count])
    }

    func selectAircraft(_ type: AircraftType) {
        guard phase == .title, economy.unlocked(type), type != aircraft || customShip != nil else { return }
        customShip = nil
        settings.aircraft = type
        settings.save(defaults: progress.defaults)
        physics = FlightPhysics(aircraft: type)
        collision = CollisionSystem(terrain: terrain, aircraft: type)
        checkpoints = CheckpointSystem(terrain: terrain, aircraft: type)
        race = PodRaceManager(terrain: terrain, aircraft: type)
        world?.setAircraft(type, color: settings.aircraftColor)
        resetFlight()
    }

    func selectCustomShip(_ ship: CustomShip) {
        guard phase == .title, economy.unlocked(ship.handling) else { return }
        selectAircraft(ship.handling)
        customShip = ship
        world?.setAircraft(aircraft, color: settings.aircraftColor, customURL: customShipURL)
        resetFlight()
    }

    func selectDroid(_ type: DroidType) {
        guard phase == .title, type != settings.droid else { return }
        settings.droid = type
        settings.save(defaults: progress.defaults)
        world?.setDroid(type)
        droidMessage = nil
    }

    func selectLevel(_ selected: FlightLevel) {
        guard phase == .title else { return }
        arenaSelected = false
        settings.spaceFreeRoam = false
        customLevel = nil
        configureLevel(selected)
    }

    func selectArena(_ difficulty: ArenaDifficulty, format: ArenaFormat = .duel) {
        guard phase == .title else { return }
        arenaSelected = true; arenaDifficulty = difficulty; arenaFormat = format
        customLevel = nil; settings.spaceFreeRoam = true
        configureLevel(.freeRoam)
    }

    func selectSpaceFreeRoam() {
        guard phase == .title else { return }
        arenaSelected = false
        customLevel = nil; settings.spaceFreeRoam = true
        configureLevel(.freeRoam)
    }
    func enterSpaceFreeRoam() {
        guard level.isFreeRoam, phase == .flying || phase == .paused else { return }
        clearCityJob()
        universe = UniverseFlight(); universeTargetStar = nil; universeTargetHole = false
        activities = FreeRoamActivities(); clearControls(); weapons.reset()
        settings.spaceFreeRoam = true; settings.save(defaults: progress.defaults)
        hyperspace.beginRelaxedSpace(state: &state, speed: aircraft.cruiseSpeed)
        pilotTracker?.relocate()
        world?.camera.reset(); publishHUD()
    }

    func acceptCityJob(_ kind: CityJobKind) {
        acceptCityContract(.standard(for:kind))
    }

    func acceptCityContract(_ contract: CityContract) {
        guard hyperspace.surfacePlanet == .coruscant, phase == .flying || phase == .paused,
              cityJobState.active == nil, bountyState.contract == nil, homeDock.plot == nil else { return }
        guard economy.completedCityJobs >= contract.requiredJobs else {
            cityJobNotice = "Complete \(contract.requiredJobs) city jobs to unlock this contract"
            cityNoticeUntil = elapsed+5; publishHUD(); return
        }
        cityJobState.accept(contract)
        cityJobNotice = "Accepted: " + contract.title
        cityNoticeUntil = elapsed+5
        publishHUD()
    }

    @discardableResult
    func buyResidence(_ plot:CityPlot) -> Bool {
        var saved = FlightEconomy.load(from:progress.defaults)
        guard saved.buyHome(plot) else { return false }
        saved.save(to:progress.defaults); economy = saved; world?.updateResidences(saved.housing); return true
    }
    @discardableResult
    func buyResidenceItem(_ item:InteriorItem,in plot:CityPlot) -> Bool {
        var saved = FlightEconomy.load(from:progress.defaults)
        guard saved.buyInterior(item,in:plot) else { return false }
        saved.save(to:progress.defaults); economy = saved; world?.updateResidences(saved.housing); return true
    }
    @discardableResult
    func toggleResidenceItem(_ item:InteriorItem,in plot:CityPlot) -> Bool {
        var saved = FlightEconomy.load(from:progress.defaults)
        guard saved.toggleInterior(item,in:plot) else { return false }
        saved.save(to:progress.defaults); economy = saved; world?.updateResidences(saved.housing); return true
    }
    @discardableResult
    func placeResidenceItem(_ item:InteriorItem,in plot:CityPlot,at placement:RoomPlacement) -> Bool {
        var saved = FlightEconomy.load(from:progress.defaults)
        guard saved.placeInterior(item,in:plot,at:placement) else { return false }
        saved.save(to:progress.defaults); economy = saved; world?.updateResidences(saved.housing); return true
    }
    func resetResidenceLayout(_ plot:CityPlot,area:HomeArea? = nil) {
        var saved = FlightEconomy.load(from:progress.defaults)
        saved.resetInteriorLayout(in:plot,area:area); saved.save(to:progress.defaults); economy = saved; world?.updateResidences(saved.housing)
    }
    @discardableResult
    func restoreResidenceLayout(_ layout:[InteriorItem:RoomPlacement],in plot:CityPlot) -> Bool {
        var saved = FlightEconomy.load(from:progress.defaults)
        guard saved.restoreInteriorLayout(layout,in:plot) else { return false }
        saved.save(to:progress.defaults); economy = saved; world?.updateResidences(saved.housing); return true
    }
    @discardableResult
    func interactResidenceItem(_ item:InteriorItem,in plot:CityPlot,from position:SIMD2<Float>,area:HomeArea) -> Bool {
        var saved = FlightEconomy.load(from:progress.defaults)
        guard interiorHome == plot,item.area == area,position.x.isFinite,position.y.isFinite,
              HomeInteraction.distance(to:item,from:position,layout:saved.housing?.layout(in:plot) ?? [:])<=2.6,
              saved.interactInterior(item,in:plot) else { return false }
        saved.save(to:progress.defaults); economy = saved; world?.updateResidences(saved.housing); return true
    }
    @discardableResult
    func visitResidence(_ plot:CityPlot) -> Bool {
        guard hyperspace.surfacePlanet == .coruscant, phase == .flying || phase == .paused,
              cityJobState.active == nil,bountyState.contract == nil,interiorHome == nil,economy.housing?.owned.contains(plot) == true else { return false }
        cityDock.reset(); homeDock.reset(); clearControls(); weapons.reset(); planetComets.reset()
        state.position = plot.arrival; state.heading = 0; state.pitch = 0; state.roll = 0
        state.airspeed = 35; state.velocity = [0,0,-35]; throttle = 0.28
        pilotTracker?.relocate(); world?.camera.reset(); publishHUD(); return true
    }
    var nearbyResidence:CityPlot? {
        guard hyperspace.surfacePlanet == .coruscant else { return nil }
        if let plot = homeDock.plot { return plot }
        guard let plot = economy.housing?.owned.min(by:{ HomeDocking.distance(to:$0,state:state,aircraft:aircraft)<HomeDocking.distance(to:$1,state:state,aircraft:aircraft) }),
              HomeDocking.distance(to:plot,state:state,aircraft:aircraft)<1400 else { return nil }
        return plot
    }
    var canLandAtResidence:Bool {
        guard let plot = nearbyResidence,homeDock.plot == nil,cityDock.station == nil,
              cityJobState.active == nil,bountyState.contract == nil else { return false }
        return HomeDocking.distance(to:plot,state:state,aircraft:aircraft)<HomeDocking.captureRadius
    }
    @discardableResult
    func landAtResidence() -> Bool {
        guard hyperspace.surfacePlanet == .coruscant,phase == .flying || phase == .paused,
              canLandAtResidence,let plot = nearbyResidence,let housing = economy.housing else { return false }
        guard homeDock.begin(plot,state:&state,aircraft:aircraft,housing:housing) else {
            cityJobNotice = "Landing path blocked · move into the clear front avenue and try again"
            cityNoticeUntil = elapsed+6; publishHUD(); return false
        }
        clearControls(); weapons.reset(); throttle = 0
        cityJobNotice = "Landing at " + plot.name; cityNoticeUntil = elapsed+5
        publishHUD(); return true
    }
    @discardableResult
    func enterResidence() -> Bool {
        guard phase == .flying,homeDock.landed,let plot = homeDock.plot,
              economy.housing?.owned.contains(plot) == true else { return false }
        pause(); interiorHome = plot; return true
    }
    func exitResidence() {
        guard interiorHome != nil else { return }
        interiorHome = nil; clearControls(); resume()
    }
    @discardableResult
    func departResidence() -> Bool {
        guard interiorHome == nil,phase == .flying, !fuel.empty,let housing = economy.housing,
              homeDock.depart(state:&state,aircraft:aircraft,housing:housing) else { return false }
        clearControls(); weapons.reset(); throttle = 0.3
        cityJobNotice = "Lifting off · follow the clear avenue"; cityNoticeUntil = elapsed+5
        publishHUD(); return true
    }

    @discardableResult
    func acceptBounty(_ job:BountyContract) -> Bool {
        guard hyperspace.surfacePlanet == .coruscant,phase == .flying || phase == .paused,
              cityJobState.active == nil,bountyState.contract == nil,homeDock.plot == nil,
              (economy.factions?.points(.hunters) ?? 0) >= job.requiredStanding else { return false }
        cityDock.depart(state:&state,speed:aircraft.cruiseSpeed)
        bountyState.start(job,near:state)
        cityJobNotice = "Bounty accepted · climb to 1,000 m and follow the marked ship"
        cityNoticeUntil = elapsed+8; publishHUD(); return true
    }
    func cancelBounty() {
        bountyState.reset(); cityJobNotice = "Bounty cancelled · no credits charged"
        cityNoticeUntil = elapsed+5; publishHUD()
    }
    private func advanceBounty(dt:Float,world:WorldRenderer) {
        guard hyperspace.surfacePlanet == .coruscant,bountyState.contract != nil else { return }
        let result = bountyState.advance(ship:state,playerBolts:weapons.bolts,dt:dt)
        if !result.consumed.isEmpty { hitUntil = elapsed+0.8; hitDescription = "BOUNTY SHIELD HIT" }
        weapons.consumeBolts(at:result.consumed)
        if result.damage>0 {
            shield = max(0,shield-result.damage); underFireUntil = elapsed+1.4
            audio.shieldHit(enabled:settings.soundEnabled)
            if shield <= 0 { crash(cause:"Bounty target fire",world:world); return }
        }
        if result.completed,let job = bountyState.contract,let id = bountyState.receipt {
            var saved = FlightEconomy.load(from:progress.defaults)
            let claimed = saved.claimBounty(id,contract:job)
            if claimed { _ = saved.recordCareer(.bounty); saved.save(to:progress.defaults) }; economy = saved
            cityJobNotice = claimed ? "Bounty complete · +\(job.reward) credits · +10 Guild standing" : "Bounty already paid"
            cityNoticeUntil = elapsed+8; bountyState.reset(); audio.checkpoint(enabled:settings.soundEnabled)
            if claimed { recordStoryEvent(.bounty(job)) }
        }
    }

    func cancelCityJob() {
        cityJobState.cancel()
        cityDock.depart(state:&state,speed:aircraft.cruiseSpeed)
        cityJobNotice = "City job cancelled · no credits charged"
        cityNoticeUntil = elapsed+5
        publishHUD()
    }

    @discardableResult
    func dockAtCityJob() -> Bool {
        guard hyperspace.surfacePlanet == .coruscant, phase == .flying || phase == .paused,
              let target = cityJobState.target else { return false }
        guard cityDock.begin(target,state:&state,aircraft:aircraft) else {
            cityJobNotice = "Approach blocked · line up along a clear avenue and try Dock again"
            cityNoticeUntil = elapsed+6; publishHUD(); return false
        }
        clearControls()
        publishHUD()
        return true
    }

    func leaveCityDock() {
        guard !cityJobState.docking else { return }
        cityDock.depart(state:&state,speed:aircraft.cruiseSpeed)
        publishHUD()
    }

    private func clearCityJob() {
        interiorHome = nil; homeDock.reset(); homeLanding = homeDock
        bountyState.reset(); bounty = bountyState
        planetComets.reset(); cometImpactUntil = 0
        cityJobState.cancel()
        cityDock.reset()
        cityJobs = cityJobState
        cityJobNotice = nil
    }

    private func advanceCityJob(dt: Float) {
        guard hyperspace.surfacePlanet == .coruscant else {
            if cityJobState.active != nil || cityDock.station != nil || bountyState.contract != nil { clearCityJob() }
            return
        }
        cityJobState.observeFlight(state,flying:cityDock.station == nil,
                                   firing:firing || keyboard.firing || elapsed < shotUntil,dt:dt)
        switch cityJobState.advance(dt:dt) {
        case .none: break
        case .stopCompleted:
            let transfer: String
            switch cityJobState.active {
            case .shuttle: transfer = cityJobState.carryingPayload ? "Passenger aboard" : "Passenger delivered"
            case .rescue: transfer = cityJobState.carryingPayload ? "Patient aboard" : "Patient transferred"
            case .courier: transfer = "Package delivered"
            case .patrol: transfer = "Scan complete"
            case nil: transfer = "Service complete"
            }
            cityJobNotice = "Stop complete · \(transfer) · depart for " + (cityJobState.target?.name ?? "your next stop")
            cityNoticeUntil = elapsed+6
            audio.checkpoint(enabled:settings.soundEnabled)
        case .completed(let id,let credits):
            // Read the latest shared wallet before applying an idempotent completion receipt.
            var saved = FlightEconomy.load(from:progress.defaults)
            let claimed = saved.claimCityJob(id:id,credits:credits,report:cityJobState.lastCompletion)
            if claimed {
                let path: PilotCareerPath = cityJobState.lastCompletion?.contract.kind == .shuttle || cityJobState.lastCompletion?.contract.kind == .rescue ? .passenger : cityJobState.lastCompletion?.contract.kind == .patrol ? .explorer : .courier
                _ = saved.recordCareer(path); saved.save(to:progress.defaults)
            }
            economy = saved
            if claimed,let report = cityJobState.lastCompletion { recordStoryEvent(.cityJob(report.contract)) }
            let bonus = cityJobState.lastCompletion?.bonusCredits ?? 0
            cityJobNotice = claimed ? "Job complete · +\(credits) credits saved" + (bonus > 0 ? " · includes \(bonus) bonus" : "") : "Job complete · reward already saved"
            cityNoticeUntil = elapsed+8
            audio.checkpoint(enabled:settings.soundEnabled)
        case .expired:
            cityJobNotice = "Time expired · no reward · choose another job"
            cityNoticeUntil = elapsed+8
        }
        if cityJobNotice != nil && elapsed > cityNoticeUntil { cityJobNotice = nil }
    }

    var currentSurfacePlanet: SpacePlanet? { hyperspace.surfacePlanet }
    func enterPlanetSurface(_ planet: SpacePlanet) {
        guard level.isFreeRoam, hyperspace.relaxedSpace,universe.homePlanets else { return }
        clearCityJob()
        emergencyFlight = nil; emergencyDocking = false; flightReplay.reset()
        hyperspace.enterPlanet(planet, state: &state); pilotTracker?.relocate(); world?.camera.reset(); publishHUD()
    }
    func returnToPlanetOrbit() {
        clearCityJob()
        emergencyFlight = nil; emergencyDocking = false; flightReplay.reset()
        let departed = hyperspace.surfacePlanet
        hyperspace.returnToOrbit(state: &state); pilotTracker?.relocate(); world?.camera.reset(); publishHUD()
        if let departed { recordStoryEvent(.orbit(departed)) }
    }
    var isRelaxedSpace: Bool { hyperspace.relaxedSpace }
    var spaceReturnPortal: SIMD3<Float> { hyperspace.returnPortal }
    var selectedSpacePlanet: SpacePlanet? { hyperspace.selectedPlanet }
    func distanceToPlanet(_ planet: SpacePlanet) -> Float { simd_distance(state.position, planet.position) }

    func selectSpaceDestination(_ planet: SpacePlanet?) {
        guard level.isFreeRoam, hyperspace.relaxedSpace,universe.homePlanets else { return }
        if activeRouteName != nil, routePlan.indices.contains(routeStep), planet != routePlan[routeStep] { cancelFlightRoute() }
        hyperspace.selectPlanet(planet); publishHUD()
    }
    func travelToSpace() {
        guard phase == .flying || phase == .paused else { return }
        travelScore = lowFlightScore
        arrivingPlanetName = "Space"
        phase = .title; clearControls(); hand.stop(); motion.stop(); droidVoice.stop()
        settings.spaceFreeRoam = true; customLevel = nil
        configureLevel(.freeRoam)
    }

    @discardableResult
    func selectCustomLevel(_ definition: CustomLevelDefinition) -> Bool {
        guard phase == .title, let valid = try? definition.validated() else { return false }
        arenaSelected = false
        customLevel = valid
        configureLevel(.alpine)
        return true
    }

    private func configureLevel(_ selected: FlightLevel) {
        settings.level = selected
        settings.save(defaults: progress.defaults)
        terrain = TerrainGenerator(seed: customLevel?.seed ?? selected.seed, level: selected, customLevel: customLevel)
        collision = CollisionSystem(terrain: terrain, aircraft: aircraft)
        checkpoints = CheckpointSystem(terrain: terrain, aircraft: aircraft)
        defenses = DeathStarDefenses(terrain: terrain)
        race = PodRaceManager(terrain: terrain, aircraft: aircraft)
        hyperspace = HyperspaceManager(terrain: terrain)
        bestGates = customLevel == nil ? progress.best(for: selected) : 0
        ready = false
        preparationProgress = 0
        error = nil
        rebuildWorld()
    }

    func prepareAetherPlanet() { world?.prepareAetherPlanet() }

    func prepareNextLevel() {
        guard phase == .completed, let next = nextLevel else { return }
        phase = .title
        cameraMode = .chase
        selectLevel(next)
    }

    private func rebuildWorld() {
        world?.terrain.stop()
        world?.anchor.removeFromParent()
        world = nil
        if let view {
            world = WorldRenderer(view: view, generator: terrain, checkpoints: checkpoints.checkpoints, racePads: race.pads,
                                  color: settings.aircraftColor, type: aircraft, droidType: settings.droid, customURL: customShipURL, reducedDetail:settings.terrainReducedDetail,arenaOnly:arenaSelected)
            world?.setPerformanceMode(settings.performanceMode,reducedDetail:settings.terrainReducedDetail)
        }
        resetFlight()
    }

    func attach(to view: ARView) {
        guard world == nil else { return }
        ready = false
        preparationProgress = 0
        self.view = view
        rebuildWorld()
#if os(macOS)
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1 / Double(settings.flightFramesPerSecond), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.frame(CACurrentMediaTime())
            }
        }
#else
        let target = DisplayLinkTarget(engine: self)
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick(_:)))
        let fps = Float(settings.flightFramesPerSecond)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: fps, maximum: fps, preferred: fps)
        link.add(to: .main, forMode: .common)
        displayLink = link
#endif
    }

    func detach() {
        bankFlightRewards()
        refreshPilotProgress()
#if os(macOS)
        displayTimer?.invalidate()
        displayTimer = nil
#else
        displayLink?.invalidate()
        displayLink = nil
#endif
        motion.stop(); hand.stop()
        droidVoice.stop()
        world?.terrain.stop()
        world?.anchor.removeFromParent()
        world = nil
        view = nil
        audio.update(throttle: 0, enabled: false, flying: false)
    }

    func start() {
        guard ready else { return }
        resetFlight()
        phase = .flying
        if !arenaSelected && pilotTracker == nil {
            pilotTracker = PilotFlightTracker(aircraft:aircraftName,route:levelName)
            refreshPilotProgress()
        }
        applySettings()
        if let chapter = storySession, economy.campaignProgress.accepted { configureStoryFlight(chapter) }
        view?.becomeFirstResponder()
    }

    func navigateFreeRoam(to sector: FreeRoamSector) {
        guard (phase == .flying || phase == .paused), level.isFreeRoam, sector == .portals else { return }
        hyperspace.reset()
        settings.spaceFreeRoam = false; settings.save(defaults: progress.defaults)
        throttle = activities.transfer(to: sector, state: &state, terrain: terrain, aircraft: aircraft)
        pilotTracker?.relocate()
        clearControls(); weapons.reset(); accumulator = 0
        world?.camera.reset()
        publishHUD()
    }
    func startFreeRoamMission(_ mission: FreeRoamMission) {
        guard (phase == .flying || phase == .paused), level.isFreeRoam, hyperspace.zone == .atmosphere else { return }
        if activities.start(mission, at: state.position) { audio.checkpoint(enabled: settings.soundEnabled) }
        publishHUD()
    }
    func cancelFreeRoamMission() { activities.cancelMission(); publishHUD() }
    func toggleLandingAssist() {
        guard (phase == .flying || phase == .paused), level.isFreeRoam, hyperspace.zone == .atmosphere,
              activities.nearPad(state.position), !activities.landed else { return }
        activities.approachAssist.toggle()
        publishHUD()
    }
    func takeOffFreeRoam() {
        guard (phase == .flying || phase == .paused), level.isFreeRoam, activities.landed else { return }
        activities.takeOff(&state, cruiseSpeed: aircraft.cruiseSpeed)
        throttle = 0.65
        if aircraft.isPodracer {
            // Ground-racing physics would otherwise snap a pod below the elevated runway.
            activities.approachAssist = true
            state.velocity = [0, 0, -18]; state.airspeed = 18; throttle = 0.28
        }
        world?.camera.reset()
        publishHUD()
    }

    func pause() {
        guard phase == .flying else { return }
        phase = .paused
        refreshPilotProgress()
        bankFlightRewards()
        publishHUD()
        clearControls()
        motion.stop(); hand.stop(preserveCalibration: settings.handControlEnabled)
        droidVoice.stop()
        audio.suspend()
        audio.update(throttle: throttle, enabled: settings.soundEnabled, flying: false)
    }

    func resume() {
        guard starInspection == nil,!storyDebrief,!replayActive,phase == .paused,interiorHome == nil,(!fuel.empty || homeDock.landed) else { return }
        phase = .flying
        accumulator = 0
        applySettings()
        view?.becomeFirstResponder()
    }

    func returnToTitle() {
        storySession = nil; pendingStory = nil; storyWeather = nil; storyLaunching = false
        finishPilotFlight(.returned)
        travelScore = nil; arrivingPlanetName = nil
        let leavingArena = arenaSelected
        phase = .title
        arenaSelected = false
        cameraMode = .chase
        droidVoice.stop()
        if leavingArena { configureLevel(.freeRoam) } else { resetFlight() }
        motion.stop(); hand.stop()
        view?.becomeFirstResponder()
    }

    func setActive(_ active: Bool) {
        suspended = !active
        if !active { pause(); motion.stop(); hand.stop(); audio.update(throttle: 0, enabled: false, flying: false) }
#if os(macOS)
        displayTimer?.fireDate = active ? .now : .distantFuture
#else
        displayLink?.isPaused = !active
#endif
        lastTimestamp = 0
    }

    @Published private(set) var soundTestMessage = "Uses device media volume. Check your selected speaker or headphones."
    func testGameSound() {
        audio.setVolume(settings.soundVolume)
        soundTestMessage = audio.testSound(enabled:settings.soundEnabled)
    }
    func applySettings() {
        if settings.handControlEnabled && !hand.available { settings.handControlEnabled = false }
        settings.save(defaults: progress.defaults)
        audio.setVolume(settings.soundVolume)
        if !settings.soundEnabled { audio.suspend() }
        world?.setPerformanceMode(settings.performanceMode,reducedDetail:settings.terrainReducedDetail)
#if os(macOS)
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1 / Double(settings.flightFramesPerSecond), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.frame(CACurrentMediaTime()) }
        }
#else
        let fps = Float(settings.flightFramesPerSecond)
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: fps, maximum: fps, preferred: fps)
#endif
        if let view {
            var options: ARView.RenderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
            if settings.performanceMode { options.formUnion([.disableHDR, .disableGroundingShadows]) }
            view.renderOptions = options
        }
        world?.setAircraft(aircraft, color: settings.aircraftColor, customURL: customShipURL)
        world?.setDroid(settings.droid)
        if settings.tiltEnabled && !settings.handControlEnabled && phase == .flying {
            motion.start()
            motionStatus = motion.available ? "" : "Tilt unavailable · use the touch joystick"
        } else {
            motion.stop()
            motionStatus = ""
        }
#if os(iOS)
        if settings.handControlEnabled && phase == .flying && !suspended {
            hand.start(orientation: view?.window?.windowScene?.interfaceOrientation ?? .landscapeRight)
        } else { hand.stop(preserveCalibration: settings.handControlEnabled) }
#endif
        if phase == .title, let terrainRenderer = world?.terrain,
           let preparedMode = terrainRenderer.preparedReducedDetail,
           preparedMode != settings.terrainReducedDetail {
            ready = false
            preparationProgress = 0
            terrainRenderer.restart(reducedDetail: settings.terrainReducedDetail)
        } else {
            world?.terrain.update(position: state.position, reducedDetail: settings.terrainReducedDetail)
        }
    }

    func toggleCamera() {
        cameraMode = cameraMode == .chase ? .cockpit : .chase
        if cameraMode != .cockpit { droidVoice.stop() }
        world?.camera.mode = cameraMode
        world?.camera.reset()
    }

    func toggleDroidVoice() {
        guard phase == .flying, cameraMode == .cockpit else { return }
        droidVoice.toggle()
    }

    private func handleDroidCommand(_ command: String) {
        guard phase == .flying else { return }
        let response: String
        switch DroidCommandParser.parse(command) {
        case .throttle(let value):
            throttle = Float(clamp(value,canReverseThrust ? -100:0,100)) / 100
            response = "THROTTLE SET TO \(Int(throttle*100))%"
        case .camera:
            response = "CAMERA SWITCHING"
            toggleCamera()
        case .status:
            response = "ALT \(hud.altitude) · SPEED \(hud.airspeed) · SHIELD \(hud.shield)%"
        case .turnLeft, .turnRight, .climb, .descend:
            let parsed = DroidCommandParser.parse(command)
            if level.isPodRace && (parsed == .climb || parsed == .descend) {
                response = "POD HOVER HEIGHT IS AUTOMATIC"
            } else {
                switch parsed {
                case .turnLeft: droidAxes = [-0.5, 0]; response = "BANKING LEFT"
                case .turnRight: droidAxes = [0.5, 0]; response = "BANKING RIGHT"
                case .climb: droidAxes = [0, 0.5]; response = "CLIMBING"
                default: droidAxes = [0, -0.5]; response = "DESCENDING"
                }
                droidSteerUntil = elapsed + 1.5
            }
        case .levelShip, .holdAltitude, .followRoute:
            let command = DroidCommandParser.parse(command)
            setDroidAssist(command == .levelShip ? .level : command == .holdAltitude ? .altitude : .route)
            return
        case .scanOre:
            scanOre(); return
        case .cancelAssist:
            droidAssist = DroidFlightAssist(); droidAssistMode = .off
            droidSteerUntil = 0; droidFireUntil = 0; droidBoostUntil = 0
            response = "MANUAL CONTROL"
        case .fire:
            droidFireUntil = elapsed + 3
            response = "FIRING · THREE SECOND BURST"
        case .ceaseFire:
            droidFireUntil = 0
            response = "DROID WEAPONS STANDING DOWN"
        case .boost:
            if level.isPodRace {
                droidBoostUntil = elapsed + 2
                response = "POD BOOST · TWO SECONDS"
            } else { response = "BOOST IS AVAILABLE IN POD RACES" }
        case .repair:
            if shield >= 100 { response = "SHIELDS ALREADY FULL" }
            else if elapsed < droidRepairReadyAt {
                response = "REPAIR RECHARGING · \(Int(ceil(droidRepairReadyAt - elapsed))) SEC"
            } else {
                shield = min(100, shield + 20)
                droidRepairReadyAt = elapsed + 45
                publishHUD()
                response = "SHIELDS REPAIRED · \(Int(shield.rounded()))%"
            }
        case .navigate:
            if level.isFreeRoam {
                if let portal = hud.portals.min(by: { $0.distance < $1.distance }) {
                    response = "\(portal.name.uppercased()) · \(Int(portal.distance)) M"
                } else { response = "SPACE RUN · DODGE ASTEROIDS AHEAD" }
            } else {
                let side = hud.checkpointBearing < 0 ? "LEFT" : "RIGHT"
                let direction = abs(hud.checkpointBearing) < 0.12 ? "AHEAD" : "\(Int(abs(hud.checkpointBearing) * 180 / .pi))° \(side)"
                response = "\(hud.checkpointName.uppercased()) · \(Int(hud.checkpointDistance)) M · \(direction)"
            }
        case .scan:
            response = hud.pursuers > 0 ? "\(hud.pursuers) HOSTILES · NEAREST \(Int(hud.scannerDistance ?? 0)) M" : "NO PURSUING SHIPS DETECTED"
        case .pause:
            pause()
            response = "FLIGHT PAUSED"
        case .help:
            response = "THROTTLE · TURN · CLIMB · FIRE · REPAIR · SCAN · CHECKPOINT · PAUSE"
        case .unknown:
            response = "COMMAND NOT UNDERSTOOD"
        }
        acknowledge(response)
    }

    private func acknowledge(_ response: String) {
        let message = "DID-DID-DING · \(response)"
        droidMessage = message
        audio.droid(enabled: settings.soundEnabled)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled, self?.droidMessage == message else { return }
            self?.droidMessage = nil
        }
    }

    private func clearControls() {
        state.rudderResponse = 0
        renderPreviousState = state
        stick = .zero; rudder = 0; firing = false; boosting = false; skidding = false; keyboard.clear()
        controlAxes = .zero; shotUntil = 0; hitUntil = 0
        droidAssist = DroidFlightAssist(); droidAssistMode = .off
        oreScanRequested = false
        droidAxes = .zero; droidSteerUntil = 0; droidFireUntil = 0; droidBoostUntil = 0
    }

    func clearKeyboard() { keyboard.clear() }

    @discardableResult
    func keyDown(_ key: String) -> Bool {
        guard KeyboardControls.supported.contains(key) else { return false }
        let firstPress = keyboard.press(key)
        guard firstPress else { return true }
        switch key {
        case "c" where phase == .flying: toggleCamera()
        case "p", "space", "escape":
            if phase == .flying { pause() }
            else if phase == .paused { resume() }
            else if key == "space" && phase == .title { start() }
        case "return":
            if phase == .paused { resume() }
            else if phase == .title || phase == .crashed || phase == .completed { start() }
        case "r":
            if phase != .title { start() }
        default: break
        }
        return true
    }

    @discardableResult
    func keyUp(_ key: String) -> Bool {
        guard KeyboardControls.supported.contains(key) else { return false }
        keyboard.release(key)
        return true
    }

    private func resetFlight() {
        starInspection = nil; oreSurvey = nil
        clearCityJob()
        universe = UniverseFlight(); universeTargetStar = nil; universeTargetHole = false
        if travelScore == nil { finishPilotFlight(.returned) }
        bankFlightRewards()
        if travelScore == nil { fuel = FlightFuel() }
        replayActive = false; replayFraction = 0; flightReplay.reset()
        emergencyFlight = nil; emergencyDocking = false
        routePlan = []; routeStep = 0; activeRouteName = nil; distressAvailable = false; distressOffered = false
        state = FlightState()
        state.position.x = terrain.valleyCenter(at: state.position.z)
        state.position.y = level.isPodRace ? terrain.hoverHeight(at: state.position.z) : terrain.surfaceHeight(x: state.position.x, z: state.position.z) + level.gateClearance + 60
        checkpoints.reset()
        if let gate = checkpoints.next {
            let direction = gate.position - state.position
            state.heading = atan2(direction.x, -direction.z)
            state.velocity = state.forward * aircraft.cruiseSpeed
        } else {
            state.velocity = state.forward * aircraft.cruiseSpeed
        }
        if level.isPodRaceTrack {
            let circuit = RaceCircuit(level: level)
            state.position = circuit.point(at: 0)
            let t = circuit.tangent(at: 0)
            state.heading = atan2(t.x, -t.z)
            state.velocity = t * aircraft.cruiseSpeed
        }
        if level.isFreeRoam {
            state.position = [0, terrain.surfaceHeight(x: 0, z: 0) + 400, 0]
            state.heading = -3 * .pi / 4
            state.velocity = state.forward * aircraft.cruiseSpeed
        }
        activities = FreeRoamActivities()
        state.airspeed = aircraft.cruiseSpeed
        throttle = level.isPodRace ? 1 : 0.65
        elapsed = 0
        lowFlightScore = travelScore ?? LowFlightScore()
        lastBankedFLP = lowFlightScore.points
        distance = 0
        accumulator = 0
        crashTime = nil
        crashCause = nil
        underFireUntil = 0
        shield = 100
        droidRepairReadyAt = 0
        hyperspace.reset()
        if level.isFreeRoam && settings.spaceFreeRoam { hyperspace.beginRelaxedSpace(state: &state, speed: aircraft.cruiseSpeed) }
        if arenaSelected {
            arena = ArenaBattle(difficulty:arenaDifficulty,format:arenaFormat)
            arenaRewardEarned = 0
            state = ArenaDuel.playerStart(speed:aircraft.cruiseSpeed)
            arenaHUD = arena.snapshot
        }
        lapRecording.begin(state:state,time:0)
        defenses.reset()
        weapons.reset()
        race = PodRaceManager(terrain: terrain, aircraft: aircraft)
        clearControls()
        world?.reset()
        world?.camera.mode = cameraMode
        world?.terrain.update(position: state.position, reducedDetail: settings.terrainReducedDetail)
        pilotTracker?.relocate()
        publishHUD()
    }

    fileprivate func frame(_ timestamp: CFTimeInterval) {
        guard !suspended, let world else { return }
        let dt = lastTimestamp == 0 ? Float(1 / 60.0) : clamp(Float(timestamp - lastTimestamp), 0, 0.1)
        lastTimestamp = timestamp
        if !ready {
            let progress = world.terrain.progress
            if preparationProgress != progress { preparationProgress = progress }
            if world.terrain.ready {
                preparationProgress = 1
                ready = true
            }
        }
        if error == nil, let failure = world.terrain.failure { error = failure; pause() }
        if phase == .title {
            if pendingStory != nil && ready {
                pendingStory = nil; arrivingPlanetName = nil
                start(); storyLaunching = false; return
            }
            if arrivingPlanetName != nil && ready { arrivingPlanetName = nil; start(); travelScore = nil; return }
            if audioWasFlying {
                audio.update(throttle: 0, enabled: false, flying: false, aircraft: aircraft)
                audioWasFlying = false
            }
            if ready && settings.hangarPreview == .selectedLevel {
                world.update(state: state, throttle: 0, dt: dt, nextCheckpoint: -1, crashTime: nil, bolts: [], pursuers: [], playerBolts: [], racers: [], collectedBoostPads: [], freeRoamZone: hyperspace.zone, asteroids: [], surfacePlanet: hyperspace.surfacePlanet, relaxedSpace: hyperspace.relaxedSpace)
                world.updateUniverse(universe,active:false,state:state,dt:0,target:nil)
                menuPreviewAngle += dt*0.08
                let offset = SIMD3<Float>(sin(menuPreviewAngle)*100, 42, cos(menuPreviewAngle)*100)
                world.camera.entity.look(at: state.position, from: state.position+offset, relativeTo: nil)
            }
            return
        }
        if starInspection != nil { return }
        if replayActive {
            replayFraction = min(1,replayFraction + dt/max(0.1,flightReplay.duration))
            if let sample = flightReplay.state(at:replayFraction) {
                world.update(state:sample,throttle:0,dt:dt,nextCheckpoint:-1,crashTime:nil,bolts:[],pursuers:[],playerBolts:[],racers:[],collectedBoostPads:[],freeRoamZone:hyperspace.zone,asteroids:hyperspace.asteroids,surfacePlanet:hyperspace.surfacePlanet,arenaMode:arenaSelected,relaxedSpace:hyperspace.relaxedSpace,solarSurface:universe.surfaceBody)
                world.setReplayVisible(true)
            }
            if replayFraction >= 1 { stopReplay() }
            return
        }
        if editingFlightBanner { return }
        if phase == .flying {
            var axes = stick
            var handActions = HandGestureInput()
#if os(iOS)
            if settings.handControlEnabled && hand.active {
                hand.updateOrientation(view?.window?.windowScene?.interfaceOrientation ?? .landscapeRight)
                let handAxes = hand.input(at: CACurrentMediaTime(), dt: dt)
                handActions = hand.gestureInput(at:CACurrentMediaTime())
                if handActions.switchCamera { toggleCamera() }
                if simd_length(stick) < 0.05 { axes = handAxes }
            }
#endif
            if settings.tiltEnabled && !settings.handControlEnabled && motion.active && simd_length(stick) < 0.05 {
#if canImport(UIKit)
                let orientation = view?.window?.windowScene?.interfaceOrientation ?? .landscapeRight
                axes = motion.input(orientation: orientation)
#else
                axes = motion.input()
#endif
            }
            axes = simd_clamp(axes + keyboard.stick, SIMD2<Float>(repeating: -1), SIMD2<Float>(repeating: 1))
            // @Published emits even for an identical value, invalidating the SwiftUI HUD.
            let nextThrottle = clamp(throttle + keyboard.throttleDirection * dt * 0.5 + handActions.throttleDirection * dt * 0.25, canReverseThrust ? -1:0, 1)
            if nextThrottle != throttle { throttle = nextThrottle }
            let useDroidSteering = elapsed < droidSteerUntil && simd_length(axes) < 0.05 && abs(rudder + keyboard.rudder) < 0.05
            if droidAssist.pilotOverride(axes: axes, yaw: rudder + keyboard.rudder) {
                droidAssist = DroidFlightAssist(); droidAssistMode = .off
                acknowledge("MANUAL CONTROL · PILOT OVERRIDE")
            }
            let pitch = useDroidSteering ? droidAxes.y : clamp(axes.y * settings.sensitivity * (settings.invertPitch ? -1 : 1), -1, 1)
            let roll = useDroidSteering ? droidAxes.x : clamp(axes.x * settings.sensitivity, -1, 1)
            let yaw = clamp(rudder + keyboard.rudder, -1, 1)
            controlAxes = [roll,pitch]
            accumulator += dt
            while accumulator >= FlightPhysics.step && phase == .flying {
                let previous = state
                renderPreviousState = previous
                if universe.jumping {
                    if let arrived = universe.advanceJump(state:&state,dt:FlightPhysics.step) { finishUniverseJump(arrived) }
                    renderPreviousState = state
                    elapsed += FlightPhysics.step; accumulator -= FlightPhysics.step
                    continue
                }
                if arenaSelected {
                    let step = FlightPhysics.step
                    if arena.snapshot.countdown <= 0 {
                        physics.advanceSpace(&state,input:FlightInput(pitch:pitch,roll:roll,yaw:yaw,throttle:throttle),dt:step,speedLimit:170)
                    }
                    let shots = weapons.update(state:state,aircraft:aircraft,
                        firing:arena.snapshot.countdown <= 0 && (firing || handActions.firing || keyboard.firing),dt:step,
                        aimTarget:arena.aimPoint(from:state.position,projectileSpeed:aircraft.weaponSpeed))
                    let result = arena.advance(from:previous,player:&state,shots:shots,dt:step)
                    weapons.consumeBolts(at:result.consumed)
                    if weapons.firedThisStep { audio.laser(enabled:settings.soundEnabled,aircraft:aircraft) }
                    if result.fired { audio.laser(enabled:settings.soundEnabled,enemy:true) }
                    if result.damaged { audio.shieldHit(enabled:settings.soundEnabled) }
                    if !result.consumed.isEmpty { hitUntil = elapsed+0.5; hitDescription = "RIVAL HIT" }
                    shield = arena.snapshot.playerShield
                    elapsed += step; accumulator -= step
                    if arena.snapshot.outcome != nil {
                        var stored = FlightEconomy.load(from:progress.defaults)
                        arenaRewardEarned = stored.claimArena(id:arena.id,format:arenaFormat,difficulty:arenaDifficulty,outcome:arena.snapshot.outcome)
                        stored.save(to:progress.defaults); economy = stored
                        arenaHUD = arena.snapshot; phase = .completed
                        clearControls(); motion.stop(); hand.stop(); droidVoice.stop()
                        audio.checkpoint(enabled:settings.soundEnabled)
                        publishHUD()
                    }
                    continue
                }
                let previousSurface = hyperspace.surfacePlanet
                let difficulty = terrain.difficulty(at: state.position.z) * level.windStrength
                let wind = SIMD3<Float>((sin(elapsed * 0.31) * 8 + 4) * difficulty,
                                       sin(elapsed * 0.67) * difficulty * 2.8, cos(elapsed * 0.19) * difficulty * 4)
                    + (hyperspace.zone == .atmosphere || hyperspace.surfacePlanet != nil ? effectiveWeather.wind(at:elapsed) : .zero)
                let boostingNow = race.advance(position: state.position, requestedBoost: boosting || keyboard.boosting || elapsed < droidBoostUntil,
                                               dt: FlightPhysics.step)
                let target = emergencyFlight?.target ?? bountyState.target ?? universeWaypoint ?? cityJobState.target?.position ?? (level.isFreeRoam ? hyperspace.targetPortal(to: state.position) : checkpoints.next?.position)
                let assistAxes = droidAssist.controls(state: state, target: target)
                let assistActive = droidAssistMode != .off
                var input = FlightInput(pitch: assistActive ? assistAxes.y : pitch, roll: assistActive ? assistAxes.x : roll, yaw: yaw, throttle: throttle,
                                        boost: boostingNow, skid: skidding || keyboard.skidding)
                if emergencyFlight?.kind == .engine { input.throttle *= 0.3 }
                if emergencyDocking, let emergency = emergencyFlight {
                    advanceEmergencyDocking(to:emergency.target,dt:FlightPhysics.step)
                } else if hyperspace.surfacePlanet == .coruscant, homeDock.plot != nil {
                    if homeDock.advance(state:&state,dt:FlightPhysics.step) {
                        cityJobNotice = "Landed · enter your home or depart when ready"
                        cityNoticeUntil = elapsed+7; audio.checkpoint(enabled:settings.soundEnabled)
                    }
                } else if hyperspace.surfacePlanet == .coruscant, cityDock.station != nil {
                    if cityDock.advance(state:&state,dt:FlightPhysics.step) {
                        _ = cityJobState.beginService(at:state.position)
                    }
                } else if level.isFreeRoam && hyperspace.zone == .atmosphere && (activities.approachAssist || activities.landed) {
                    activities.advanceApproach(&state, input: input, dt: FlightPhysics.step)
                } else if level.isFreeRoam && hyperspace.zone != .atmosphere {
                    let homeApproach:Float? = nearbyResidence.flatMap { plot in
                        HomeDocking.approachSpeedLimit(state:state,plot:plot,aircraft:aircraft)
                    }
                    var approachLimit = hyperspace.surfacePlanet == .coruscant ? (cityJobState.target.flatMap { CityDocking.approachSpeedLimit(for:state,target:$0) } ?? homeApproach) : nil
                    if let emergency = emergencyFlight {
                        let range = simd_distance(state.position,emergency.target)
                        if range < 1100 { approachLimit = min(approachLimit ?? 35,35) }
                        else if emergency.kind == .engine { approachLimit = aircraft.cruiseSpeed*0.65 }
                    }
                    physics.advanceSpace(&state, input: input, dt: FlightPhysics.step,speedLimit:approachLimit)
                    state.velocity += effectiveWeather.wind(at:elapsed) * (hyperspace.surfacePlanet == nil ? 0 : FlightPhysics.step*0.3)
                } else {
                    physics.advance(&state, input: input, wind: wind, dt: FlightPhysics.step, raceSpeedMultiplier: level.podRaceSpeedMultiplier, draftStrength: race.draftStrength)
                }
                if oreScanRequested && miningAvailable && !hyperspace.asteroids.isEmpty {
                    oreSurvey = hyperspace.oreSurvey(from: state); oreScanRequested = false
                    if let survey = oreSurvey {
                        var wallet = FlightEconomy.load(from:progress.defaults); wallet.discoverOre(survey.mineral)
                        wallet.save(to:progress.defaults); economy = wallet
                    }
                    acknowledge(oreSurvey.map { "ORE SCAN · " + $0.summary.uppercased() } ?? "NO ORE AHEAD · TURN AND SCAN AGAIN")
                }
                let oldContacts = race.contacts
                race.resolveContact(player: &state, skidding: skidding || keyboard.skidding, dt: FlightPhysics.step)
                if race.contacts > oldContacts { audio.shieldHit(enabled: settings.soundEnabled) }
                let hyperspaceEvent = level.isFreeRoam && universe.surfaceBody == nil ? hyperspace.advance(state: &state, collisionRadius: aircraft.bodyRadius, cityCollisionRadius: aircraft.cityCollisionRadius, dt: FlightPhysics.step, mining:miningEnabled,planetAccess:universe.homePlanets) : .none
                switch hyperspaceEvent {
                case .beganHyperspace:
                    if activities.mission != nil { activities.cancelMission() }
                    activities.approachAssist = false
                    world.camera.reset()
                    audio.hyperspace(enabled: settings.soundEnabled)
                case .enteredSpace, .returnedToAtmosphere:
                    if let previousSurface, hyperspace.surfacePlanet == nil { recordStoryEvent(.orbit(previousSurface)) }
                    if hyperspaceEvent == .returnedToAtmosphere { throttle = max(0,throttle); settings.spaceFreeRoam = false; settings.save(defaults: progress.defaults) }
                    world.camera.reset()
                    audio.arrival(enabled: settings.soundEnabled)
                case .asteroidImpact(let damage):
                    shield = max(0, shield - damage)
                    underFireUntil = elapsed + 1.4
                    audio.shieldHit(enabled: settings.soundEnabled)
                    if shield <= 0 { crash(cause: "Asteroid impact", world: world) }
                case .surfaceBeacon:
                    if let planet = hyperspace.surfacePlanet { recordStoryEvent(.scout(planet,hyperspace.surfaceBeacons-1)) }
                    if hyperspace.surfaceBeacons == 6 { awardCareer(.explorer) }
                    audio.checkpoint(enabled: settings.soundEnabled)
                case .planetImpact(let planet):
                    let surface = PlanetExploration(planet:planet)
                    let groundHit = hyperspace.surfacePlanet != nil && surface.clearance(at:state.position) <= aircraft.bodyRadius
                    let cause = hyperspace.surfacePlanet == nil ? "Impact with \(planet.name)" : groundHit ? "\(planet.name) ground impact" : planet == .coruscant ? "Coruscant building collision" : "\(planet.name) obstacle collision"
                    crash(cause:cause,world:world)
                case .none: break
                }
                if phase == .flying && universeActive {
                    updateGravityHaptics()
                    if universe.applyGravity(state:&state,from:previous.position,radius:aircraft.bodyRadius,dt:FlightPhysics.step) {
                        crash(cause:"Black hole event horizon",world:world)
                    } else if let body = universe.surfaceBody {
                        let landscape = SolarLandscape(body:body)
                        if landscape.impact(from:previous.position,to:state.position,radius:aircraft.bodyRadius) {
                            crash(cause:body.name + (body.isCloudWorld ? " deep-atmosphere pressure" : " surface impact"),world:world)
                        } else if state.position.y > 3000 || max(abs(state.position.x),abs(state.position.z)) > 11500 {
                            engageUniverseJump(.solarSystem)
                        }
                    } else if universe.sector == .solarSystem,let body = SolarBody.impact(from:previous.position,to:state.position,radius:aircraft.bodyRadius) {
                        crash(cause:"Solar collision: " + body.name,world:world)
                    }
                }
                if phase == .flying, let planet = hyperspace.surfacePlanet {
                    let cometDamage = planetComets.advance(planet:planet,from:previous,to:state,radius:aircraft.bodyRadius,dt:FlightPhysics.step)
                    if cometDamage>0 && homeDock.plot == nil {
                        cometImpactUntil = elapsed+2.5
                        shield = max(0,shield-cometDamage); underFireUntil = elapsed+1.4
                        audio.shieldHit(enabled:settings.soundEnabled)
                        if shield <= 0 { crash(cause:"Comet impact",world:world) }
                    }
                    if planet == .coruscant, previousSurface == planet, let housing = economy.housing,
                       housing.impact(from:previous.position,to:state.position,radius:aircraft.cityCollisionRadius) {
                        crash(cause:"Coruscant residence collision",world:world)
                    }
                } else if hyperspace.surfacePlanet == nil { planetComets.reset() }
                if phase == .flying {
                    advanceCityJob(dt:FlightPhysics.step)
                    advanceAdventures(dt:FlightPhysics.step)
                }
                let terrainImpact = hyperspace.zone == .atmosphere ? collision.impact(from: previous, to: state) : nil
                let scoringClearance = universe.surfaceBody.map { state.position.y-max($0.name == "Earth" ? 0 : -10000,SolarLandscape(body:$0).height(x:state.position.x,z:state.position.z)) } ?? hyperspace.surfacePlanet.map { PlanetExploration(planet:$0).clearance(at:state.position) }
                    ?? collision.clearance(at:state.position)
                lowFlightScore.advance(clearance: scoringClearance, speed: state.airspeed,
                    eligible: phase == .flying && (hyperspace.zone == .atmosphere || hyperspace.surfacePlanet != nil || universe.surfaceBody.map { !$0.isCloudWorld } == true) && !aircraft.isPodracer && terrainImpact == nil,
                    dt: FlightPhysics.step)
                let onGroundWorld = hyperspace.zone == .atmosphere || hyperspace.surfacePlanet != nil || universe.surfaceBody.map { !$0.isCloudWorld } == true
                let flightRegion = universe.surfaceBody.map { "solar-"+$0.name } ?? hyperspace.surfacePlanet?.rawValue ?? (hyperspace.zone == .atmosphere ? "region-"+level.rawValue : "space")
                if phase == .flying {
                    pilotTracker?.observe(state:state,clearance:onGroundWorld ? scoringClearance:nil,
                        planet:hyperspace.surfacePlanet,region:flightRegion,canManeuver:!aircraft.isPodracer && hyperspace.zone != .hyperspace && !activities.landed,countDistance:hyperspace.zone != .hyperspace,dt:FlightPhysics.step)
                    pilotSaveClock += FlightPhysics.step
                    if pilotSaveClock >= 10 { refreshPilotProgress() }
                }
                if phase == .flying {
                    let context = level.rawValue + "/" + (universe.surfaceBody.map { "solar-"+$0.name } ?? hyperspace.surfacePlanet?.rawValue ?? String(describing:hyperspace.zone))
                    flightReplay.record(state,time:elapsed,context:context)
                    if level.isPodRace { lapRecording.record(state:state,time:elapsed) }
                }
                elapsed += FlightPhysics.step
                accumulator -= FlightPhysics.step
                let crossedPortal = hyperspaceEvent == .enteredSpace || hyperspaceEvent == .returnedToAtmosphere
                if !crossedPortal {
                    let flown = simd_distance(previous.position,state.position)
                    distance += flown; fuel.travel(flown)
                    if fuel.empty && phase == .flying && !homeDock.landed { pause() }
                }
                if phase == .flying, hyperspace.zone == .atmosphere, !crossedPortal, !activities.landed,
                   let impact = terrainImpact {
                    state.position = impact
                    crash(cause: "Terrain impact", world: world)
                } else if phase == .flying {
                    let playerBolts = weapons.update(state: state, aircraft: aircraft, firing: homeDock.plot == nil && (firing || handActions.firing || keyboard.firing || elapsed < droidFireUntil), dt: FlightPhysics.step, aimTarget:miningEnabled && miningAvailable ? hyperspace.miningTarget(from:state) : nil)
                    if weapons.firedThisStep { shotUntil = elapsed+0.35; audio.laser(enabled:settings.soundEnabled,aircraft:aircraft) }
                    let raceHits = race.resolvePlayerFire(playerBolts, dt: FlightPhysics.step)
                    if !raceHits.isEmpty { hitUntil = elapsed+0.6; hitDescription = "RIVAL HIT" }
                    weapons.consumeBolts(at: raceHits)
                    let asteroidHits = hyperspace.resolvePlayerFire(weapons.bolts, shipPosition: state.position)
                    if !asteroidHits.isEmpty {
                        hitUntil = elapsed+0.6; hitDescription = "ASTEROID HIT"
                        if miningEnabled && miningAvailable {
                            if hyperspace.salvageableHits > 0 { collectAsteroidMinerals(hyperspace.salvageableOre) }
                            else { hitDescription = "ORE OUT OF RANGE · MINE WITHIN 900 M"; hitUntil = elapsed+2 }
                        }
                        weapons.consumeBolts(at: asteroidHits)
                        audio.debris(enabled: settings.soundEnabled)
                    }
                    if phase == .flying { advanceBounty(dt:FlightPhysics.step,world:world) }
                    if let planet = hyperspace.surfacePlanet {
                        let surfaceHits = weapons.surfaceHits(on:PlanetExploration(planet:planet),dt:FlightPhysics.step)
                        if !surfaceHits.isEmpty {
                            weapons.consumeBolts(at:surfaceHits)
                            hitUntil = elapsed+0.6; hitDescription = planet == .coruscant ? "STRUCTURE HIT" : "SURFACE HIT"
                        }
                    }
                    if level.isFreeRoam && hyperspace.zone == .atmosphere {
                        let combat = activities.advanceCombat(ship: state, bolts: weapons.bolts, dt: FlightPhysics.step)
                        weapons.consumeBolts(at: combat.consumed)
                        if !combat.consumed.isEmpty || combat.completed { hitUntil = elapsed+0.6; hitDescription = "FIGHTER HIT"; audio.checkpoint(enabled: settings.soundEnabled) }
                        if combat.damage > 0 {
                            audio.shieldHit(enabled:settings.soundEnabled)
                            shield = max(0, shield - combat.damage); underFireUntil = elapsed + 1.4
                            if shield <= 0 { crash(cause: "Fighter interception", world: world) }
                        }
                    }
                    if defenses.resolvePlayerFire(weapons.bolts) > 0 { hitUntil = elapsed+0.6; hitDescription = "TARGET HIT" }
                    let defense = defenses.update(from: previous, to: state, passedGates: checkpoints.nextIndex, dt: FlightPhysics.step)
                    if defense.fired || defense.incoming { underFireUntil = elapsed + 1.4 }
                    if defense.fired { audio.laser(enabled: settings.soundEnabled,enemy:true) }
                    if defense.damage > 0 {
                        audio.shieldHit(enabled:settings.soundEnabled)
                        shield = max(0, shield - defense.damage)
                        if shield <= 0 { crash(cause: defense.pursuerHit ? "Enemy fighter" : "Turret strike", world: world) }
                    } else if defense.directPursuerHit {
                        crash(cause: "Enemy fighter", world: world)
                    } else if level == .deathStar && !defense.incoming {
                        // A clean escape gives the shield systems time to rebalance.
                        shield = min(100, shield + 1.5 * FlightPhysics.step)
                    }
                }
                if phase == .flying && checkpoints.advance(from: previous.position, to: state.position) {
                    audio.checkpoint(enabled: settings.soundEnabled)
                    if level == .deathStar { shield = min(100, shield + 18) }
                    if level.isPodRace {
                        race.rewardGate()
                        if checkpoints.nextIndex.isMultiple(of: level.gateCount) {
                            saveCompletedLap(); race.beginLap(); lapRecording.begin(state:state,time:elapsed)
                        }
                    }
                    bestGates = max(bestGates, checkpoints.nextIndex)
                    if customLevel == nil { progress.record(gates: checkpoints.nextIndex, for: level) }
                    if checkpoints.complete {
                        phase = .completed
                        finishPilotFlight(.completed)
                        bankFlightRewards()
                        clearControls()
                        motion.stop(); hand.stop()
                        droidVoice.stop()
                        recordStoryEvent(.route(level))
                    }
                    publishHUD()
                }
                if phase == .flying && level == .deathStar && elapsed >= deathStarTimeLimit {
                    crash(cause: "Death Star exploded", world: world)
                    world.beginDeathStarExplosion(state: state)
                    publishHUD()
                }
            }
        }
        if let time = crashTime { crashTime = min(time + dt, 4) }
        terrainClock += dt
        if terrainClock > 0.35 && hyperspace.zone == .atmosphere {
            world.terrain.update(position: state.position, reducedDetail: settings.terrainReducedDetail)
            terrainClock = 0
        }
        let displayState = phase == .flying
            ? FlightState.rendered(from: renderPreviousState, to: state, fraction: accumulator / FlightPhysics.step)
            : state
        world.update(state: displayState, throttle: homeDock.plot == nil ? throttle : 0, dt: dt, nextCheckpoint: checkpoints.next?.id ?? -1,
                     crashTime: crashTime, bolts: arenaSelected ? arena.bolts : defenses.bolts + activities.enemyBolts + bountyState.bolts,
                     pursuers: arenaSelected ? arena.pursuers : bountyState.targets.map { Pursuer(position:$0.position,velocity:$0.velocity,fireCooldown:$0.cooldown,side:0) } + defenses.pursuers + activities.enemies.map { Pursuer(position: $0.position, velocity: $0.velocity, fireCooldown: $0.fireCooldown, side: 0) },
                     playerBolts: weapons.bolts, racers: race.opponents, collectedBoostPads: race.collectedPads,
                     boosting: (race.isBoosting || state.driftBoostRemaining > 0) && phase == .flying,
                     skidding: skidding || keyboard.skidding, impactEnergy: race.collisionShake,
                     freeRoamZone: universe.jumping ? .hyperspace:hyperspace.zone, portals: level.isFreeRoam ? hyperspace.portals : [],
                     returnPortalPosition: hyperspace.returnPortal,
                     asteroids: universe.jumping ? []:hyperspace.asteroids, surfacePlanet: hyperspace.surfacePlanet, surfaceBeacons: hyperspace.surfaceBeacons,comets:planetComets.comets,arenaMode:arenaSelected,relaxedSpace:hyperspace.relaxedSpace,solarSurface:universe.surfaceBody)
        world.updateUniverse(universe,active:universeActive,state:displayState,dt:phase == .flying ? dt:0,target:universeWaypoint)
        world.updateAdventures(ghost:ghostState,platform:emergencyFlight?.target,weather:effectiveWeather,
                               weatherActive:weatherActive,state:displayState,dt:phase == .flying ? dt:0)
        world.updateResidences(economy.housing)
        world.updateBountyTarget(bountyState.target)
        world.updateCityJobs(target:hyperspace.surfacePlanet == .coruscant ? cityJobState.target : nil,servicing:cityJobState.docking)
        world.updateFreeRoamActivities(activities, inAtmosphere: hyperspace.zone == .atmosphere)
        let soundClearance = hyperspace.surfacePlanet.map { PlanetExploration(planet:$0).clearance(at:state.position) }
            ?? collision.clearance(at:state.position)
        audio.update(throttle:homeDock.plot == nil ? throttle:0,enabled:settings.soundEnabled,flying:phase == .flying,aircraft:aircraft,
                     speed:state.airspeed,clearance:soundClearance,dt:dt,
                     inSpace:hyperspace.zone != .atmosphere && hyperspace.surfacePlanet == nil,
                     boosting:(race.isBoosting || state.driftBoostRemaining > 0) && phase == .flying,
                     skidding:skidding || keyboard.skidding,cockpit:cameraMode == .cockpit,weather:effectiveWeather,weatherActive:weatherActive)
        hudClock += dt
        if hudClock > 0.1 {
            if phase == .flying {
                publishHUD()
                audioWasFlying = true
            } else if audioWasFlying {
                audioWasFlying = false
            }
            hudClock = 0
        }
    }

    private func crash(cause: String, world: WorldRenderer) {
        phase = .crashed
        finishPilotFlight(.crashed)
        bankFlightRewards()
        clearCityJob()
        crashCause = cause
        crashTime = 0
        clearControls()
        motion.stop(); hand.stop()
        droidVoice.stop()
        world.beginCrash(state: state)
        cameraMode = .chase
        audio.impact(enabled: settings.soundEnabled)
    }

    private func publishHUD() {
        updateAstronomyReadout()
        if arenaSelected { arenaHUD = arena.snapshot }
        bankFlightRewards()
        let atmosphereTarget = hyperspace.targetPortal(to: state.position)
        let cityTarget = hyperspace.surfacePlanet == .coruscant ? cityJobState.target : nil
        let homeTarget = cityTarget == nil && bountyState.contract == nil ? nearbyResidence:nil
        let target = emergencyFlight?.target ?? bountyState.target ?? universeWaypoint ?? cityTarget?.position ?? homeTarget.map { HomeDocking.padPosition($0,aircraft:aircraft) } ?? (level.isFreeRoam ? (hyperspace.zone == .atmosphere ? atmosphereTarget : hyperspace.targetPortal(to: state.position)) : checkpoints.next?.position ?? state.position)
        let delta = target - state.position
        let bearing = atan2(delta.x, -delta.z) - state.heading
        let heading = Int(state.heading * 180 / .pi + 360) % 360
        let surfaceClearance: Float? = universe.surfaceBody.map { state.position.y-max($0.name == "Earth" ? 0 : -10000,SolarLandscape(body:$0).height(x:state.position.x,z:state.position.z)) } ?? hyperspace.surfacePlanet.map { PlanetExploration(planet: $0).clearance(at: state.position) }
            ?? (hyperspace.relaxedSpace && universe.homePlanets && hyperspace.zone == .asteroidField
            ? SpacePlanet.allCases.map { $0.clearance(at: state.position) }.min() : nil)
        let surfaceWarning: String? = {
            if let body = universe.surfaceBody {
                return (surfaceClearance ?? 9999) < 100 ? (body.isCloudWorld ? "DENSE ATMOSPHERE · CLIMB" : "SURFACE · PULL UP") : nil
            }
            if let planet = hyperspace.surfacePlanet {
                let surface = PlanetExploration(planet:planet)
                if homeDock.plot != nil { return nil }
                if (surfaceClearance ?? 9999) < 80 { return "GROUND · PULL UP" }
                if [Float(0.5),1,1.5].contains(where:{
                    let point = state.position+state.velocity*$0
                    return surface.hitsObstacle(at:point,radius:aircraft.bodyRadius+8) || (planet == .coruscant && economy.housing?.hits(point,radius:aircraft.bodyRadius+8) == true)
                }) {
                    return planet == .coruscant ? "BUILDING AHEAD · BANK TO CLEAR" : "OBSTACLE AHEAD · STEER CLEAR"
                }
                return nil
            }
            return surfaceClearance.map { $0 < 80 ? "PLANET SURFACE · STEER AWAY" : nil } ?? nil
        }()
        let terrainWarning = hyperspace.zone != .atmosphere || (level.isFreeRoam && activities.landed) ? nil : collision.warning(for: state)
        let nearestAsteroid = hyperspace.nearestAsteroid(to: state.position)
        let proximityWarning: String? = nearestAsteroid.map { $0 < 170 ? "ASTEROID PROXIMITY" : nil } ?? nil
        let raceWarning = level.isPodRace ? race.proximityWarning(for: state) : nil
        let warning = blackHoleWarning ?? (fuel.empty ? "FUEL EMPTY · RESTART TO REFUEL" : fuel.percent < 10 ? "LOW FUEL · RETURN TO BASE" : elapsed < underFireUntil && hyperspace.zone == .asteroidField ? "ASTEROID IMPACT · EVADE" :
            (elapsed < cometImpactUntil ? "COMET IMPACT · SHIELD DAMAGED" : planetComets.warning) ?? surfaceWarning ?? proximityWarning ??
            (terrainWarning == "TERRAIN · PULL UP" ? terrainWarning : elapsed < underFireUntil ? "ENEMY FIRE · EVADE" : raceWarning ?? terrainWarning))
        let nearestPursuer = (defenses.pursuers.map(\.position) + activities.enemies.map(\.position) + bountyState.targets.map(\.position)).map { simd_distance($0, state.position) }.min()
        let portalHUD = level.isFreeRoam && hyperspace.zone == .atmosphere ? hyperspace.portals.map {
            PortalHUD(id: $0.id, name: $0.destination.name, distance: simd_distance($0.position, state.position))
        } : []
        let circuit = race.circuit
        let playerRaceProgress = level.isPodRace ? circuit.projection(state.position).distance / circuit.length : 0
        let checkpointRaceProgress = level.isPodRace && level.gateCount > 0
            ? Float((checkpoints.nextIndex % level.gateCount) + 1) / Float(level.gateCount) : 0
        let rivalRaceProgress = level.isPodRace ? race.opponents.filter(\.active).map {
            $0.progress.truncatingRemainder(dividingBy: circuit.length) / circuit.length
        } : []
        let cityApproach = cityTarget.map { CityApproach(position:state.position,velocity:state.velocity,target:$0.position).guidance } ?? ""
        let cityServiceDetail = cityDock.station != nil && !cityDock.arrived ? "Autodocking · repulsor brakes" : cityJobState.docking ? "Servicing · \(Int(ceil(cityJobState.serviceRemaining))) s" : cityDock.arrived ? "Ready to depart" : cityApproach
        let cityDeadline = cityJobState.timeRemaining.map { " · \(Int(ceil($0))) s left" } ?? ""
        hud = HUDSnapshot(fuelPercent:Float(fuel.percent), lowFlightPoints: lowFlightScore.points, altitude: Int(state.position.y), clearance: surfaceClearance.map { max(0, Int($0)) } ?? (hyperspace.zone == .asteroidField ? 0 : max(0, Int(collision.clearance(at: state.position)))),
                          airspeed: Int(state.airspeed * 1.94384), heading: (heading + 360) % 360,
                          checkpointDistance: simd_length(delta), checkpointBearing: atan2(sin(bearing), cos(bearing)),
                          checkpointName: universe.surfaceBody.map { $0.name + " · climb to 3,000 m for orbit" } ?? (universe.jumping ? "Jump to " + (universe.destination?.title ?? "destination") : universeWaypoint != nil ? universeWaypointTitle : emergencyFlight != nil ? emergencyFlight!.kind.title + " · repair platform" : homeTarget != nil ? (homeDock.landed ? "HOME · PARKED" : (homeTarget!.name + " · landing terrace")) : bountyState.contract != nil ? "BOUNTY · \(bountyState.remaining) targets · climb to 1,000 m" : cityTarget != nil ? cityJobState.status : level.isFreeRoam ? hyperspace.targetName(to: state.position) : checkpoints.next?.name ?? "Route complete"), passed: checkpoints.nextIndex,
                          warning: warning, elapsed: elapsed, distance: distance,
                          difficulty: terrain.difficulty(at: state.position.z), pitch: asin(clamp(state.forward.y, -1, 1)), roll: atan2(-state.orientation.act(SIMD3<Float>(1,0,0)).y, state.orientation.act(SIMD3<Float>(0,1,0)).y),
                          timeRemaining: level == .deathStar ? max(0, deathStarTimeLimit - elapsed) : nil,
                          pursuers: defenses.pursuers.count + activities.enemies.count + bountyState.remaining, scannerDistance: nearestPursuer,
                          shield: Int(shield.rounded()), boostCharge: Int(race.boostCharge.rounded()),
                          racePosition: race.position(for: state.position, passed: checkpoints.nextIndex), raceFieldSize: race.opponents.count + 1, lap: checkpoints.currentLap,
                          nearPlanetSurface: surfaceClearance.map { $0 < 1200 } ?? false,
                          inSpace: hyperspace.zone == .asteroidField,
                          inHyperspace: universe.jumping || hyperspace.zone == .hyperspace,
                          hyperspaceRemaining: universe.jumping ? universe.remaining:hyperspace.jumpTimeRemaining,
                          portals: portalHUD,
                          freeRoamSector: universeActive ? universe.galaxy.name + " · " + universe.location : hyperspace.relaxedSpace ? "Space free roam" : "Outer Rim",
                          activityStatus: universeActive ? universe.galaxy.name + " · " + universe.location + (universe.homePlanets ? " · fictional planetary sector":" · survey flight") : cityJobState.active != nil ? cityJobState.status : hyperspace.surfacePlanet.map { PlanetExploration(planet:$0).name + " · \(hyperspace.surfaceBeacons)/6 beacons · \(hyperspace.surfacePoints) points" } ?? (hyperspace.relaxedSpace ? "Explore Tatooine, Hoth, Endor and Coruscant. Steer around each globe; avoid its surface." : "Explore freely · low flight earns points below 100 m."), landingAssist: activities.approachAssist,
                          landed: activities.landed, nearLandingPad: false,
                          missionAvailable: false, missionActive: activities.mission != nil,
                          activityTarget: "Hyperspace portals", verticalSpeed: state.velocity.y,
                          completedMissions: activities.completedMissions, landings: activities.landings,
                          asteroidsDestroyed: hyperspace.destroyedAsteroids,
                          racePlayerProgress: playerRaceProgress,
                          raceCheckpointProgress: checkpointRaceProgress,
                          raceRivalProgress: rivalRaceProgress,
                          raceDriftCharge: Int(state.driftCharge * 100),
                          raceBurst: race.isBoosting || state.driftBoostRemaining > 0,
                          raceDrafting: race.draftStrength > 0.25,
                          cityCanDock: cityTarget.map { cityDock.station == nil && simd_distance(state.position,$0.position) < CityDocking.captureRadius } ?? false,
                          cityDocked: cityDock.station != nil,
                          cityDepartReady: cityDock.arrived && !cityJobState.docking,
                          cityJobDetail: cityServiceDetail + cityDeadline,
                          controlAxes:controlAxes, weaponsActive:elapsed < shotUntil && phase == .flying,
                          weaponHit:elapsed < hitUntil && phase == .flying ? hitDescription : "",
                          celestialDistanceLabel:universeActive ? selectedUniverseStar.map { String(format:"%.2f ly",simd_distance($0.positionPC,universe.observerPC(local:state.position))*3.26156) }:nil)
        if hyperspace.surfacePlanet == .coruscant || cityJobs.active != nil { cityJobs = cityJobState }
        if hyperspace.surfacePlanet == .coruscant || homeLanding.plot != nil { homeLanding = homeDock }
        if hyperspace.surfacePlanet == .coruscant || bounty.contract != nil { bounty = bountyState }
    }
}

#if !os(macOS)
@MainActor
private final class DisplayLinkTarget: NSObject {
    weak var engine: GameEngine?
    init(engine: GameEngine) { self.engine = engine }
    @objc func tick(_ link: CADisplayLink) { engine?.frame(link.timestamp) }
}
#endif

// MARK: Flight adventures, navigation, and playback
extension GameEngine {
    var canWatchReplay: Bool { !replayActive && flightReplay.duration >= 1 && phase != .title && interiorHome == nil }
    var replaySeconds: Float { flightReplay.duration }
    func watchReplay() {
        guard canWatchReplay else { return }
        if phase == .flying { pause() }
        replayFraction = 0; replayActive = true; world?.camera.reset(); audio.suspend()
    }
    func seekReplay(_ fraction: Float) { replayFraction = clamp(fraction,0,0.995) }
    func stopReplay() { replayActive = false; world?.setReplayVisible(false); world?.camera.reset() }
    var ghostKey: String { level.rawValue + "/" + aircraft.rawValue + "/" + settings.weather.rawValue }
    var ghostState: FlightState? {
        guard settings.showGhost,level.isPodRace,phase == .flying else { return nil }
        return economy.adventureProgress.bestLaps.first { $0.key == ghostKey }?.state(at:elapsed-lapRecording.startedAt)
    }
    var ghostBestTime: Float? { economy.adventureProgress.bestLaps.first { $0.key == ghostKey }?.duration }
    private func saveCompletedLap() {
        guard let ghost = lapRecording.finished(state:state,time:elapsed,key:ghostKey) else { return }
        var wallet = FlightEconomy.load(from:progress.defaults)
        if wallet.saveBestLap(ghost) {
            wallet.save(to:progress.defaults); economy = wallet
            adventureMessage = String(format:"New best lap · %.2f s · ghost saved",ghost.duration)
            acknowledge(adventureMessage.uppercased())
        }
    }
    func awardCareer(_ path: PilotCareerPath) {
        var wallet = FlightEconomy.load(from:progress.defaults)
        let bonus = wallet.recordCareer(path); wallet.save(to:progress.defaults); economy = wallet
        if bonus > 0 { adventureMessage = path.title + " promotion · +\(bonus) credits"; acknowledge(adventureMessage.uppercased()) }
    }
    @discardableResult
    func saveFlightRoute(name:String,planets:[SpacePlanet]) -> Bool {
        let clean = String(name.trimmingCharacters(in:.whitespacesAndNewlines).prefix(40))
        let route = SavedFlightRoute(name:clean.isEmpty ? "My route":clean,planets:planets.map(\.rawValue))
        var wallet = FlightEconomy.load(from:progress.defaults)
        guard wallet.saveRoute(route) else { adventureMessage = "Choose 1–8 stops without repeated neighbours. Your library holds eight routes."; return false }
        wallet.save(to:progress.defaults); economy = wallet; adventureMessage = "Saved " + route.name
        return true
    }
    func removeFlightRoute(_ route:SavedFlightRoute) {
        var wallet = FlightEconomy.load(from:progress.defaults); wallet.removeRoute(route.id)
        wallet.save(to:progress.defaults); economy = wallet
    }
    func followFlightRoute(_ route:SavedFlightRoute) {
        guard isRelaxedSpace, phase == .flying || phase == .paused, route.valid else { adventureMessage = "Start Space free roam to follow a saved route."; return }
        routePlan = route.destinations; routeStep = 0; activeRouteName = route.name
        if currentSurfacePlanet == routePlan.first { routeStep = 1 }
        if routeStep < routePlan.count { selectSpaceDestination(routePlan[routeStep]); adventureMessage = route.name + " · " + routePlan[routeStep].name + " next" }
        else { activeRouteName = nil; adventureMessage = "Route complete." }
    }
    func cancelFlightRoute() { routePlan = []; activeRouteName = nil; adventureMessage = "Saved route stopped." }
    var plannedRoutePlanets: [SpacePlanet] { Array(routePlan.dropFirst(routeStep)) }
    var routeSummary: String? {
        guard let name = activeRouteName, routeStep < routePlan.count else { return nil }
        return "\(name) · stop \(routeStep+1)/\(routePlan.count) · \(routePlan[routeStep].name)"
    }
    var activeEmergency: EmergencyFlightContract? { emergencyFlight }
    var canStartEmergency: Bool {
        level.isFreeRoam && !aircraft.isPodracer && !arenaSelected && !hud.inHyperspace
            && emergencyFlight == nil && cityJobState.active == nil && bountyState.contract == nil
            && homeDock.plot == nil && interiorHome == nil && (phase == .flying || phase == .paused)
    }
    func startEmergency(_ kind:EmergencyContractKind) {
        guard canStartEmergency, economy.adventureProgress.career["courier",default:0] >= kind.requiredCompletions else { adventureMessage = "Finish more courier activities to unlock this challenge, or finish your current job."; return }
        var forward = state.forward; forward.y = 0
        forward = simd_length(forward) > 0.01 ? simd_normalize(forward) : SIMD3<Float>(0,0,-1)
        var target = state.position + forward * 1400
        if let planet = currentSurfacePlanet {
            let surface = PlanetExploration(planet:planet)
            target.y = max(target.y,surface.groundHeight(x:target.x,z:target.z)+300)
            while surface.hitsObstacle(at:target,radius:160) && target.y < 1700 { target.y += 120 }
        } else if !hud.inSpace { target.y = max(target.y,terrain.surfaceHeight(x:target.x,z:target.z)+350) }
        emergencyFlight = EmergencyFlightContract(kind:kind,target:target); emergencyDocking = false; emergencyContext = flightContext
        distressAvailable = false; adventureMessage = kind.briefing
        acknowledge(kind.title.uppercased() + " · FOLLOW THE GREEN PLATFORM")
    }
    func cancelEmergency() {
        emergencyFlight = nil; emergencyDocking = false
        adventureMessage = "Contract cancelled · normal engine control restored."; publishHUD()
    }
    var emergencyCanDock: Bool {
        guard let mission = emergencyFlight, !emergencyDocking, simd_distance(state.position,mission.target) < 450 else { return false }
        return emergencyApproachClear(to:mission.target)
    }
    private func emergencyApproachClear(to target:SIMD3<Float>) -> Bool {
        let length = simd_distance(state.position,target)
        for index in 0...max(1,Int(ceil(length/15))) {
            let t = Float(index)/Float(max(1,Int(ceil(length/15))))
            let point = simd_mix(state.position,target,SIMD3<Float>(repeating:t))
            if let planet = currentSurfacePlanet {
                let surface = PlanetExploration(planet:planet)
                if surface.clearance(at:point) < aircraft.bodyRadius+8 || surface.hitsObstacle(at:point,radius:aircraft.cityCollisionRadius+5) { return false }
            } else if !hud.inSpace && collision.clearance(at:point) < aircraft.bodyRadius+8 { return false }
        }
        return true
    }
    func dockEmergency() {
        guard emergencyCanDock else { adventureMessage = "Approach within 450 m along a clear path."; return }
        emergencyDocking = true; clearControls(); throttle = 0.15
        adventureMessage = "Repair approach assist · aligning for a safe touchdown"
    }
    private func advanceEmergencyDocking(to target:SIMD3<Float>,dt:Float) {
        let delta = target-state.position, range = simd_length(delta)
        let desired = delta * min(2,35/max(1,range))
        state.velocity += (desired-state.velocity)*(1-exp(-dt*12))
        state.position += state.velocity*dt; state.airspeed = simd_length(state.velocity)
        state.pitch *= exp(-dt*5)
        let bank = atan2(sin(state.roll),cos(state.roll)); state.roll -= bank*(1-exp(-dt*5))
        state.pitchRate = 0
    }
    private var flightContext: String { level.rawValue + "/" + (currentSurfacePlanet?.rawValue ?? String(describing:hyperspace.zone)) }
    private func advanceAdventures(dt:Float) {
        if emergencyFlight != nil && emergencyContext != flightContext {
            emergencyFlight = nil; emergencyDocking = false
            adventureMessage = "Contract ended on region transfer · normal engines restored"
        }
        if let expected = routePlan.indices.contains(routeStep) ? routePlan[routeStep] : nil, currentSurfacePlanet == expected {
            routeStep += 1
            if routeStep >= routePlan.count { activeRouteName = nil; routePlan = []; adventureMessage = "Route complete · all destinations visited"; awardCareer(.explorer) }
            else { selectSpaceDestination(routePlan[routeStep]); adventureMessage = "Visited \(expected.name). Return to orbit for \(routePlan[routeStep].name)." }
        }
        if let mission = emergencyFlight {
            if mission.kind == .leak { fuel.travel(dt*3500) }
            var updated = mission
            if updated.advance(state:state,dt:dt) {
                var wallet = FlightEconomy.load(from:progress.defaults)
                let paid = wallet.claimEmergency(updated); wallet.save(to:progress.defaults); economy = wallet
                emergencyFlight = nil; emergencyDocking = false
                throttle = 0.65; state.velocity = state.forward*max(60,aircraft.cruiseSpeed*0.7); state.airspeed = simd_length(state.velocity)
                adventureMessage = "Contract complete · +\(paid) credits · engine repaired"; acknowledge(adventureMessage.uppercased())
                recordStoryEvent(.repaired(updated.kind))
            } else if updated.failed { emergencyFlight = nil; emergencyDocking = false; adventureMessage = "Contract expired · engine restored · no reward" }
            else { emergencyFlight = updated }
        }
        if !distressOffered,canStartEmergency,isRelaxedSpace,economy.trading?.delivery != nil,distance > 1800 {
            distressOffered = true; distressAvailable = true
            adventureMessage = "Distress signal nearby · optional 90-credit rescue diversion in Navigation & missions"
            acknowledge("DISTRESS SIGNAL · OPTIONAL RESCUE DIVERSION")
        }
        if elapsed >= droidAdvisoryAt && state.airspeed > 70 {
            let clearance = currentSurfacePlanet.map { PlanetExploration(planet:$0).clearance(at:state.position) } ?? (hud.inSpace ? 10000:collision.clearance(at:state.position))
            if clearance < 90 && !aircraft.isPodracer {
                acknowledge("LOW CLEARANCE · CLIMB GENTLY"); droidAdvisoryAt = elapsed+18
            } else if let mission = emergencyFlight,simd_distance(state.position,mission.target) < 700,state.airspeed > 45 {
                acknowledge("REPAIR PLATFORM AHEAD · SLOW DOWN"); droidAdvisoryAt = elapsed+18
            }
        }
    }
}

// MARK: The Last Beacon campaign
extension GameEngine {
    var storyProgress: StoryCampaignProgress { economy.campaignProgress }
    var storyFlightActive: Bool { storySession != nil && storyProgress.accepted }
    var storyConditions: String? { storyWeather?.title }
    @discardableResult
    func restartStoryCampaign() -> Bool {
        guard !storyLaunching,interiorHome == nil else { return false }
        if phase != .title { returnToTitle() }
        storySession = nil; pendingStory = nil; storyWeather = nil; storyDebrief = false
        var wallet = FlightEconomy.load(from:progress.defaults); wallet.restartStory()
        wallet.save(to:progress.defaults); economy = wallet
        adventureMessage = "Story restarted · choose a new flight plan"
        return true
    }
    func launchStoryChapter() {
        guard !storyLaunching, interiorHome == nil, let chapter = storyProgress.current else { return }
        if phase != .title { returnToTitle() }
        if aircraft.isPodracer { selectAircraft(.kestrel) }
        var wallet = FlightEconomy.load(from:progress.defaults); wallet.beginStory()
        wallet.save(to:progress.defaults); economy = wallet
        storySession = chapter; pendingStory = chapter; storyWeather = nil
        storyDebrief = false; storyLaunching = true
        arenaSelected = false; customLevel = nil
        settings.spaceFreeRoam = chapter != .dawn
        configureLevel(chapter == .dawn ? .deathStar:.freeRoam)
        arrivingPlanetName = "Chapter \(chapter.number) · " + chapter.title
    }
    private func configureStoryFlight(_ chapter:StoryChapter) {
        storyWeather = chapter == .whiteout ? (storyProgress.plan == .covert ? .mist:.whiteout) : chapter == .canopy ? .mist:nil
        miningEnabled = chapter == .salvage
        if let planet = chapter.planet { enterPlanetSurface(planet) }
        switch chapter {
        case .signal: if !storyProgress.passengerSafe { acceptCityContract(.spaceportLink) }
        case .salvage:
            var wallet = FlightEconomy.load(from:progress.defaults)
            _ = wallet.openTradeRoute(SpaceTradeRoute.all[0]); wallet.save(to:progress.defaults); economy = wallet
            selectSpaceDestination(.tatooine)
        case .shadow: if !storyProgress.recorderSafe { _ = acceptBounty(.runaway) }
        case .lifeline: startEmergency(.engine)
        default: break
        }
        acknowledge("CHAPTER \(chapter.number) · " + chapter.title.uppercased())
        adventureMessage = storyProgress.objectiveProgress
        publishHUD()
    }
    private func recordStoryEvent(_ event:StoryEvent) {
        guard let sessionChapter = storySession,sessionChapter == storyProgress.current,storyProgress.accepted else { return }
        var wallet = FlightEconomy.load(from:progress.defaults)
        let before = wallet.campaignProgress
        let completed = wallet.recordStory(event)
        guard wallet.campaignProgress != before else { return }
        wallet.save(to:progress.defaults); economy = wallet
        if completed == nil {
            adventureMessage = storyProgress.transmission
            acknowledge(storyProgress.objectiveProgress.uppercased())
        }
        if let completed {
            storySession = nil
            adventureMessage = "Chapter \(completed.number) complete" + (economy.storyRewardAvailable(for:completed) ? " · +\(completed.reward) credits":" · replay complete")
            acknowledge("TRANSMISSION SECURED · " + adventureMessage.uppercased())
            pause(); storyDebrief = true
        }
    }
    func chooseStoryApproach(_ choice:StoryApproach) {
        var wallet = FlightEconomy.load(from:progress.defaults); wallet.chooseStoryApproach(choice)
        wallet.save(to:progress.defaults); economy = wallet
    }
    func chooseStoryRelay(_ choice:StoryRelayChoice) {
        var wallet = FlightEconomy.load(from:progress.defaults); wallet.chooseStoryRelay(choice)
        wallet.save(to:progress.defaults); economy = wallet
    }
    func dismissStoryDebrief() { storyDebrief = false }
    func chooseStoryEnding(_ ending:StoryEnding) {
        var wallet = FlightEconomy.load(from:progress.defaults); wallet.chooseStoryEnding(ending)
        wallet.save(to:progress.defaults); economy = wallet
        if let chosen = wallet.campaignProgress.ending { adventureMessage = chosen.title }
    }
}

// MARK: Universe exploration
extension GameEngine {
    var universeActive:Bool { level.isFreeRoam && isRelaxedSpace && hyperspace.zone == .asteroidField && currentSurfacePlanet == nil && !arenaSelected }
    var universeAvailable:Bool { level.isFreeRoam && isRelaxedSpace && !arenaSelected }
    var currentGalaxy:Galaxy { universe.galaxy }
    var currentUniverseLocation:String { universe.location }
    var homePlanetsAvailable:Bool { !universeAvailable || universe.homePlanets }
    var selectedSolarBody: SolarBody? { SolarBody.all.first { $0.name == solarTarget } }
    var solarSystemActive:Bool { universeActive && universe.sector == .solarSystem && universe.surfaceBody == nil }
    var currentSolarSurface: SolarBody? { universe.surfaceBody }
    func enterSolarBody(_ body: SolarBody) { engageUniverseJump(.surface(body.name)) }
    var galaxyJumpActive:Bool { universe.jumping }
    var galaxyJumpRemaining:Float { universe.remaining }
    var galaxyJumpTitle:String { universe.destination?.title ?? "Hyperspace" }
    var canReverseThrust:Bool { level.isFreeRoam && hyperspace.zone != .atmosphere && !aircraft.isPodracer }
    var visitedGalaxies:Set<String> { economy.adventureProgress.visitedGalaxies ?? [] }
    var visitedStars:Set<Int> { economy.adventureProgress.visitedStars ?? [] }
    var selectedUniverseStar:CatalogStar? { universeTargetStar.flatMap(StarCatalogue.star) }
    var astronomyObserver:String { universe.observerHIP.flatMap(StarCatalogue.star)?.title ?? "Earth reference" }
    var universeTravelRestriction:String? {
        if !universeAvailable { return "Start Space free roam to travel between sectors." }
        if currentSurfacePlanet != nil { return "Return to orbit before engaging hyperspace." }
        if universe.jumping { return "A jump is already in progress." }
        if storyFlightActive || storyDebrief { return "Finish or leave this story flight before travelling." }
        if emergencyFlight != nil || cityJobState.active != nil || bountyState.contract != nil { return "Finish the current job before changing sectors." }
        if interiorHome != nil { return "Depart your home before travelling." }
        if fuel.empty { return "Return to base to refuel before travelling." }
        if let hole = universe.blackHole,hole.zone(at:state.position) == .strong || hole.zone(at:state.position) == .horizon { return "Gravity is too strong for hyperspace. Thrust away from the black hole first." }
        return nil
    }
    var blackHoleRange:Float? { guard universeActive,let hole = universe.blackHole else { return nil }; return max(0,simd_distance(state.position,hole.center)-hole.horizon) }
    var blackHoleWarning:String? {
        guard universeActive,!universe.jumping,let hole = universe.blackHole else { return nil }
        switch hole.zone(at:state.position) {
        case .clear:return nil
        case .outer:return "BLACK HOLE · GRAVITY DRIFT · THRUST AWAY"
        case .strong:return "EXTREME GRAVITY · HYPERSPACE BLOCKED · ESCAPE NOW"
        case .horizon:return "EVENT HORIZON"
        }
    }
    private func updateGravityHaptics() {
#if os(iOS) && !targetEnvironment(macCatalyst)
        guard phase == .flying, !editingFlightBanner, !universe.jumping,
              let hole = universe.blackHole else { return }
        let distance = simd_distance(state.position, hole.center)
        guard distance < hole.influence else { return }
        let intensity = CGFloat(clamp(1 - (distance-hole.horizon)/(hole.influence-hole.horizon), 0, 1))
        let now = CACurrentMediaTime()
        guard now-lastGravityHaptic >= 0.8-Double(intensity)*0.64 else { return }
        lastGravityHaptic = now
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.2+0.8*intensity)
#endif
    }
    var gravityDriftSpeed:Float { simd_length(universe.gravityDrift) }
    var blackHoleEscapeCourse:String? {
        guard let hole = universe.blackHole else { return nil }
        let delta = state.position-hole.center
        return String(format:"Escape heading %03.0f° · %@",(atan2(delta.x,-delta.z)*180/Float.pi+360).truncatingRemainder(dividingBy:360),delta.y >= 0 ? "climb away":"descend away")
    }
    var universeWaypoint:SIMD3<Float>? {
        guard universeActive,!universe.jumping,universe.surfaceBody == nil else { return nil }
        if let star = selectedUniverseStar {
            let delta = star.positionPC-universe.observerPC(local:state.position)
            if simd_length(delta)>0.00001 { return state.position+SIMD3<Float>(simd_normalize(delta))*2800 }
        }
        if solarSystemActive { return SolarBody.all.first { $0.name == solarTarget }?.position }
        if universeTargetHole || !universe.homePlanets { return universe.blackHole?.center }
        return nil
    }
    var universeWaypointTitle:String {
        if let star = selectedUniverseStar { return "Star bearing · " + star.title }
        if solarSystemActive { return "Solar flyby · " + solarTarget }
        return "Black-hole survey · keep outside the horizon"
    }
    func selectSolarBody(_ body:SolarBody) { solarTarget = body.name; universeTargetStar = nil; publishHUD() }
    func selectUniverseStar(_ star:CatalogStar) { guard universe.catalogVisible else { return }; universeTargetStar = star.hip; universeTargetHole = false; astronomyEnabled = true; publishHUD() }
    func setAstronomyMode(_ enabled:Bool) { astronomyEnabled = enabled; publishHUD() }
    func engageUniverseJump(_ destination:UniverseDestination) {
        guard phase == .flying || phase == .paused,universeTravelRestriction == nil else { return }
        guard universe.begin(destination,state:state) else { return }
        departureThrottle = throttle; clearControls(); weapons.reset(); droidAssist = DroidFlightAssist(); droidAssistMode = .off
        droidVoice.stop(); audio.hyperspace(enabled:settings.soundEnabled)
        if phase == .paused { resume() }
        universeTravelID += 1; publishHUD()
    }
    func cancelUniverseJump() {
        universe.cancel(state:&state); throttle = departureThrottle; renderPreviousState = state
        world?.camera.reset(); publishHUD()
    }
    private func finishUniverseJump(_ destination:UniverseDestination) {
        let arrival = state
        hyperspace.beginRelaxedSpace(state:&state,speed:aircraft.cruiseSpeed); state = arrival
        universeTargetStar = nil; universeTargetHole = false; miningEnabled = false; oreSurvey = nil
        if case .star(let hip) = destination { universeTargetStar = hip; astronomyEnabled = true }
        if destination == .blackHole { universeTargetHole = true }
        throttle = 0; renderPreviousState = state; clearControls(); weapons.reset(); planetComets.reset()
        pilotTracker?.relocate(); flightReplay.reset(); world?.camera.reset()
        var wallet = FlightEconomy.load(from:progress.defaults); wallet.recordUniverseVisit(universe.galaxy,star:universe.observerHIP)
        wallet.save(to:progress.defaults); economy = wallet
        audio.arrival(enabled:settings.soundEnabled); acknowledge("ARRIVED · " + universe.location.uppercased()); publishHUD()
    }
    private func updateAstronomyReadout() {
        guard astronomyEnabled,universeActive,!universe.jumping,universe.surfaceBody == nil else { return }
        guard universe.catalogVisible else { astronomyReadout = "Procedural survey stars · real-star catalogue is available in the Milky Way"; return }
        let observer = universe.observerPC(local:state.position)
        let star = selectedUniverseStar ?? StarCatalogue.all.filter {
            let delta = $0.positionPC-observer
            return simd_length(delta)>0.0001 && simd_dot(SIMD3<Float>(simd_normalize(delta)),state.forward)>0.995
        }.min { $0.apparentMagnitude(from:observer)<$1.apparentMagnitude(from:observer) }
        if let star {
            astronomyReadout = String(format:"%@ · %.2f ly from observer · V %.1f",star.title,simd_distance(star.positionPC,observer)*3.26156,star.apparentMagnitude(from:observer))
        } else { astronomyReadout = "No catalogued star at the crosshair · select a star in Astronomy" }
    }
}

struct StarInspection: Identifiable {
    let star: CatalogStar
    let point: CGPoint
    let viewport: CGSize
    var id: Int { star.hip }
}
struct ScanProjection {
    let center: CGPoint
    let radius: CGFloat
}
extension GameEngine {
    func inspectUnobstructedSky(at windowPoint: CGPoint) {
        guard let view, let window = view.window else { return }
        let point = view.convert(windowPoint, from: window)
        // Do not turn taps on instruments, navigation or flight controls into star selections.
        let clearSky = CGRect(x: min(110, view.bounds.width*0.22), y: 170,
            width: max(0,view.bounds.width-min(110,view.bounds.width*0.22)-min(170,view.bounds.width*0.25)),
            height: max(0,view.bounds.height-330))
        guard clearSky.contains(point) else { return }
        inspectStar(at:point)
    }
    func inspectStar(at point: CGPoint) {
        guard phase == .flying, universeActive, universe.catalogVisible, !universe.jumping,
              universe.surfaceBody == nil, let view, let world else { return }
        let observer = universe.observerPC(local: state.position)
        let origin = world.camera.entity.position
        let cameraForward = world.camera.entity.orientation.act(SIMD3<Float>(0, 0, -1))
        let limit = settings.performanceMode ? 1000 : 3000
        var nearest: (CatalogStar, CGPoint, CGFloat)?
        for star in StarCatalogue.all.prefix(limit) {
            let direction = StarSkyGeometry.direction(position:star.positionPC,observer:observer,lens:universe.blackHole.map { $0.center-origin })
            guard simd_dot(direction, cameraForward) > 0,
                  let projected = view.project(origin+direction*46000) else { continue }
            let distance = hypot(projected.x-point.x, projected.y-point.y)
            if distance <= 28 && distance < (nearest?.2 ?? 29) { nearest = (star, projected, distance) }
        }
        guard let match = nearest else { return }
        pause()
        starInspection = StarInspection(star: match.0, point: match.1, viewport: view.bounds.size)
    }
    func inspectSelectedStar() {
        guard phase == .flying, universeActive, universe.surfaceBody == nil, let star = selectedUniverseStar, let view, let world else { return }
        let direction = StarSkyGeometry.direction(position:star.positionPC,observer:universe.observerPC(local:state.position),lens:universe.blackHole.map { $0.center-world.camera.entity.position })
        let point = view.project(world.camera.entity.position+direction*46000) ?? CGPoint(x:view.bounds.midX,y:view.bounds.midY)
        pause(); starInspection = StarInspection(star:star,point:point,viewport:view.bounds.size)
    }
    func closeStarInspection() {
        starInspection = nil
        if phase == .paused { resume() }
    }
    func scanProjection() -> ScanProjection? {
        guard oreScanVisible, let survey = oreSurvey, let view, let world,
              let rock = hyperspace.asteroids.first(where: { $0.id == survey.asteroidID }) else { return nil }
        let delta = rock.position-world.camera.entity.position
        guard simd_dot(delta, world.camera.entity.orientation.act([0,0,-1])) > 0,
              let center = view.project(rock.position),
              let edge = view.project(rock.position+world.camera.entity.orientation.act([rock.radius,0,0])) else { return nil }
        return ScanProjection(center: center, radius: max(14, hypot(edge.x-center.x,edge.y-center.y)+8))
    }
}
