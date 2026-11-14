import Foundation
import simd

enum FlightLevel: String, CaseIterable, Identifiable, Sendable {
    case alpine, canyon, glacier, endor, skylands, volcano, storm, deathStar
    case boontaEve, sentinelOne, ordIbanna, andoPrime, lantaana, ordMantell, corellia, narShaddaa, freeRoam

    var id: String { rawValue }
    var number: Int { Self.allCases.firstIndex(of: self)! + 1 }

    var name: String {
        switch self { case .alpine: return "Hoth: Echo Ridge"; case .canyon: return "Tatooine: Beggar’s Canyon"; case .glacier: return "Jakku: Wreckage Run"; case .storm: return "Exegol: Sith Storm"; case .deathStar: return "Death Star Trench Run"; case .endor: return "Endor Moon Run"; case .volcano: return "Mustafar: Magma Pass"; case .skylands: return "Bespin: Cloud City Approach"; case .boontaEve: return "Boonta Eve Classic"; case .sentinelOne: return "Sentinel One: Magma Circuit"; case .ordIbanna: return "Ord Ibanna: Canyon Dash"; case .andoPrime: return "Ando Prime Icebreaker"; case .lantaana: return "Lantaana Canopy Run"; case .ordMantell: return "Ord Mantell: Scrap Run"; case .corellia: return "Corellia: Shipyard Sprint"; case .narShaddaa: return "Nar Shaddaa: Neon Run"; case .freeRoam: return "Outer Rim Free Flight" }
    }

    var subtitle: String {
        switch self {
        case .alpine: return "Hoth’s frozen ridgelines. Skim the ice and keep clear of the Imperial patrols."
        case .canyon: return "Thread the sandstone maze where podracers once thundered across the Dune Sea."
        case .glacier: return "Jakku’s buried wrecks and shifting dunes turn every narrow pass into a gamble."
        case .storm: return "A lightning-wracked Sith world, jagged ridges, and the hardest flight beyond the trench."
        case .deathStar: return "Boss run: beat the countdown through a winding trench. TIE fighters join after gate 3."
        case .endor: return "Fly low over the forest moon’s green canopy, misty ravines, and rebel outposts."
        case .volcano: return "Follow Mustafar’s lava rivers between black cliffs and glowing mining platforms."
        case .skylands: return "Approach Cloud City through Bespin’s orange cloudbanks and floating platforms."
        case .boontaEve: return "The famous Mos Espa course: long straights, canyon bends, and room to learn the racing line."
        case .sentinelOne: return "Scream across a volcanic industrial world, threading lava channels and refinery wreckage."
        case .ordIbanna: return "A steep canyon circuit around Ord Ibanna’s mesas, with gates that come fast."
        case .andoPrime: return "Skim icy ravines and broken glaciers where poor visibility makes every turn count."
        case .lantaana: return "Race beneath a dense jungle canopy through the series’ tightest turns and gates."
        case .ordMantell: return "Thread a scrapyard slalom between wrecked freighters, rusting towers, and flying debris."
        case .corellia: return "Blast through the orbital shipyards, weaving between gantries and half-built cruisers."
        case .narShaddaa: return "A neon-lit night sprint through the packed vertical lanes of the Smuggler’s Moon."
        case .freeRoam: return "Explore the mountains, earn low-flight points, or choose peaceful space free roam and hyperspace asteroid challenges."
        }
    }

    var challenge: String {
        switch self { case .alpine: return "HOTH · 01"; case .canyon: return "TATOOINE · 02"; case .glacier: return "JAKKU · 03"; case .endor: return "ENDOR · 04"; case .skylands: return "BESPIN · 05"; case .volcano: return "MUSTAFAR · 06"; case .storm: return "EXEGOL · 07"; case .deathStar: return "LEGENDARY"; case .boontaEve: return "PODRACE · 01"; case .sentinelOne: return "PODRACE · 02"; case .ordIbanna: return "PODRACE · 03"; case .andoPrime: return "PODRACE · 04"; case .lantaana: return "PODRACE · 05"; case .ordMantell: return "PODRACE · 06"; case .corellia: return "PODRACE · 07"; case .narShaddaa: return "PODRACE · 08"; case .freeRoam: return "OUTER RIM" }
    }

    var seed: UInt32 {
        switch self { case .alpine: return 7319; case .canyon: return 18421; case .glacier: return 62003; case .storm: return 99107; case .deathStar: return 1977; case .endor: return 1983; case .volcano: return 48291; case .skylands: return 77513; case .boontaEve: return 24042; case .sentinelOne: return 36019; case .ordIbanna: return 41007; case .andoPrime: return 55810; case .lantaana: return 77421; case .ordMantell: return 83115; case .corellia: return 99417; case .narShaddaa: return 105731; case .freeRoam: return 64728 }
    }

    var gateDepths: [Float] {
        switch self {
        case .alpine: return [1400, 3000, 4800, 6700, 8800]
        case .canyon: return [1800, 3700, 5900, 8100, 10400]
        case .glacier: return [1500, 3200, 5200, 7100, 9100, 11200]
        case .storm: return [1700, 3600, 5600, 7700, 9900, 12200, 14600]
        case .deathStar: return [1000, 2100, 3200, 4300, 5400, 6500, 7600, 8700, 9800, 10900, 12000, 13200]
        case .boontaEve: return [1450, 3000, 4700, 6500, 8400, 10500]
        case .sentinelOne: return [1250, 2700, 4300, 6000, 7800, 9700, 11800]
        case .ordIbanna: return [1100, 2350, 3750, 5300, 7000, 8850, 10800, 13000]
        case .andoPrime: return [950, 2050, 3300, 4700, 6250, 7950, 9800, 11800, 14000]
        case .lantaana: return [850, 1850, 3000, 4300, 5750, 7350, 9100, 11000, 13100, 15400]
        case .ordMantell: return [800, 1750, 2850, 4150, 5650, 7350, 9250, 11350, 13700]
        case .corellia: return [750, 1650, 2700, 3950, 5400, 7050, 8900, 10950, 13300, 15900]
        case .narShaddaa: return [700, 1550, 2550, 3750, 5150, 6750, 8550, 10550, 12850, 15400, 18100]
        case .endor: return [1600, 3300, 5200, 7300, 9500, 11800]
        case .volcano: return [1500, 3100, 4800, 6600, 8500, 10500, 12600]
        case .skylands: return [1700, 3500, 5500, 7600, 9800, 12100]
        case .freeRoam: return []
        }
    }

    var gateNames: [String] {
        switch self {
        case .alpine: return ["Echo Base", "Ice Shelf", "Rogue Squadron", "The Trench", "Echo Ridge"]
        case .canyon: return ["Mos Espa", "Podrace Bend", "Beggar’s Canyon", "Jundland Arch", "Dune Sea"]
        case .glacier: return ["Starship Graveyard", "Jakku Wreck", "Niima Outpost", "Dune Cut", "Scavenger’s Pass", "Great Beyond"]
        case .storm: return ["Sith Citadel", "Red Lightning", "Exegol Rift", "Dark Ridge", "Sith Pass", "Wayfinder Run", "Final Order"]
        case .deathStar: return ["Trench Entry", "Reactor Bend", "Turbolaser Alley", "Shield Channel", "Service Turn", "Exhaust Run", "Tower Gauntlet", "Power Conduit", "Target Corridor", "Final Bend", "Reactor Core", "Escape Vector"]
        case .boontaEve: return ["Mos Espa Start", "Tusken Cut", "Arch Canyon", "Dune Sea", "Hutt Straight", "Finish Gate"]
        case .sentinelOne: return ["Refinery Start", "Lava Channel", "Furnace Bend", "Cooling Tower", "Scrap Fields", "Flare Run", "Finish Gate"]
        case .ordIbanna: return ["Mesa Launch", "Canyon Split", "Rockslide", "Ibanna Arch", "Narrow Cut", "Spire Bend", "Outer Wall", "Finish Gate"]
        case .andoPrime: return ["Ice Shelf", "Blue Ravine", "Crevasse Cut", "Glacier Arch", "Whiteout", "Frost Chicane", "Broken Flow", "Icefall", "Finish Gate"]
        case .lantaana: return ["Canopy Start", "Vine Chicane", "Jungle Drop", "Root Run", "Green Tunnel", "Waterfall Bend", "Ridge Leap", "Fern Cut", "Final S-Bend", "Finish Gate"]
        case .ordMantell: return ["Junkyard Start", "Wreck Row", "Falling Freighter", "Scrap Chicane", "Droid Graveyard", "Rust Tower", "Shipbreaker", "Debris Field", "Finish Gate"]
        case .corellia: return ["Shipyard Launch", "Assembly Gantry", "Docking Ring", "Cruiser Spine", "Cargo Crane", "Foundry Turn", "Hull Gap", "Orbital Slipway", "Starport Gate", "Finish Gate"]
        case .narShaddaa: return ["Neon Start", "Lower Promenade", "Smuggler’s Cut", "Traffic Weave", "Red Sector", "Vertical Drop", "Market Run", "Rainline", "Midnight Chicane", "Skybridge", "Finish Gate"]
        case .endor: return ["Bright Tree", "Ewok Village", "Fallen AT-ST", "Forest Moon", "Shield Bunker", "Sanctuary"]
        case .volcano: return ["Mining Colony", "Lava Flow", "Mustafar Ridge", "Duel Platform", "Obsidian Pass", "Magma River", "Outer Foundry"]
        case .skylands: return ["Cloud City", "Tibanna Fields", "Floating Platform", "Bespin Drift", "Cloud Car Pass", "Administrator’s Tower"]
        case .freeRoam: return []
        }
    }

    var gateCount: Int { gateDepths.count }
    var raceLaps: Int { isPodRaceTrack ? 3 : 1 }
    var totalCheckpoints: Int { gateCount * raceLaps }
    var routeLength: Float { self == .freeRoam ? 20000 : (gateDepths.last ?? 0) + 250 }
    var isFreeRoam: Bool { self == .freeRoam }
    var isPodRace: Bool { [.boontaEve, .sentinelOne, .ordIbanna, .andoPrime, .lantaana, .ordMantell, .corellia, .narShaddaa].contains(self) }
    /// The first circuit stays approachable; later circuits add pace and more assertive rivals.
    var podRaceDifficulty: Float {
        guard let index = Self.allCases.filter(\.isPodRace).firstIndex(of: self) else { return 0 }
        return Float(index) / 7
    }
    var podRaceSpeedMultiplier: Float { isPodRace ? 2.0 + podRaceDifficulty * 0.4 : 1 }

    var boostPadDepths: [Float] {
        switch self {
        case .boontaEve: return [2350, 5400, 8250]
        case .sentinelOne: return [2150, 4900, 7950, 10300]
        case .ordIbanna: return [1900, 4450, 7050, 9900, 11900]
        case .andoPrime: return [1650, 3950, 6500, 9150, 11500, 13200]
        case .lantaana: return [1450, 3550, 5900, 8400, 10900, 13300, 14700]
        case .ordMantell: return [1300, 3300, 5650, 8200, 10800, 12900]
        case .corellia: return [1250, 3200, 5550, 8150, 10800, 13200, 15100]
        case .narShaddaa: return [1200, 3050, 5300, 7850, 10400, 12800, 15000, 17200]
        default: return []
        }
    }

    var valleyWidth: Float {
        switch self { case .alpine: return 650; case .canyon: return 610; case .glacier: return 560; case .endor: return 510; case .skylands: return 465; case .volcano: return 415; case .storm: return 370; case .deathStar: return 290; case .boontaEve: return 620; case .sentinelOne: return 550; case .ordIbanna: return 485; case .andoPrime: return 420; case .lantaana: return 365; case .ordMantell: return 335; case .corellia: return 310; case .narShaddaa: return 285; case .freeRoam: return 680 }
    }

    /// Centerline amplitude for the alternating pod-race hairpins.
    var raceTurnRadius: Float {
        switch self { case .boontaEve: return 285; case .sentinelOne: return 260; case .ordIbanna: return 235; case .andoPrime: return 215; case .lantaana: return 200; case .ordMantell: return 185; case .corellia: return 170; case .narShaddaa: return 155; default: return 0 }
    }

    var isPodRaceTrack: Bool { isPodRace }

    var bendFrequency: Float {
        switch self { case .alpine: return 0.00056; case .canyon: return 0.00048; case .glacier: return 0.00066; case .endor: return 0.00073; case .skylands: return 0.00082; case .volcano: return 0.0009; case .storm: return 0.00098; case .deathStar: return 0.00035; case .boontaEve: return 0.00032; case .sentinelOne: return 0.00038; case .ordIbanna: return 0.00043; case .andoPrime: return 0.00048; case .lantaana: return 0.00052; case .ordMantell: return 0.00056; case .corellia: return 0.0006; case .narShaddaa: return 0.00064; case .freeRoam: return 0.00055 }
    }

    var mountainScale: Float {
        switch self { case .alpine: return 0.68; case .canyon: return 0.78; case .glacier: return 0.92; case .endor: return 1.04; case .skylands: return 1.16; case .volcano: return 1.29; case .storm: return 1.43; case .deathStar: return 0.82; case .boontaEve: return 0.72; case .sentinelOne: return 0.92; case .ordIbanna: return 1.12; case .andoPrime: return 1.32; case .lantaana: return 1.5; case .ordMantell: return 1.58; case .corellia: return 1.66; case .narShaddaa: return 1.74; case .freeRoam: return 0.72 }
    }

    var saddleScale: Float {
        switch self { case .alpine: return 0.7; case .canyon: return 0.72; case .glacier: return 0.84; case .endor: return 0.92; case .skylands: return 1.02; case .volcano: return 1.12; case .storm: return 1.22; case .deathStar: return 0.45; case .boontaEve: return 0.62; case .sentinelOne: return 0.78; case .ordIbanna: return 0.96; case .andoPrime: return 1.14; case .lantaana: return 1.32; case .ordMantell: return 1.42; case .corellia: return 1.5; case .narShaddaa: return 1.58; case .freeRoam: return 0.4 }
    }

    var gateClearance: Float {
        switch self { case .alpine: return 330; case .canyon: return 310; case .glacier: return 295; case .endor: return 280; case .skylands: return 265; case .volcano: return 245; case .storm: return 225; case .deathStar: return 175; case .boontaEve: return 315; case .sentinelOne: return 285; case .ordIbanna: return 255; case .andoPrime: return 225; case .lantaana: return 200; case .ordMantell: return 185; case .corellia: return 172; case .narShaddaa: return 158; case .freeRoam: return 330 }
    }

    var gateRadius: Float {
        switch self { case .alpine: return 155; case .canyon: return 150; case .glacier: return 140; case .endor: return 128; case .skylands: return 118; case .volcano: return 108; case .storm: return 98; case .deathStar: return 95; case .boontaEve: return 145; case .sentinelOne: return 128; case .ordIbanna: return 112; case .andoPrime: return 96; case .lantaana: return 84; case .ordMantell: return 78; case .corellia: return 72; case .narShaddaa: return 66; case .freeRoam: return 0 }
    }

    var windStrength: Float {
        switch self { case .alpine: return 0.65; case .canyon: return 0.75; case .glacier: return 0.9; case .endor: return 1.05; case .skylands: return 1.2; case .volcano: return 1.35; case .storm: return 1.55; case .deathStar: return 0.7; case .boontaEve: return 0.5; case .sentinelOne: return 0.8; case .ordIbanna: return 1.05; case .andoPrime: return 1.3; case .lantaana: return 1.6; case .ordMantell: return 1.7; case .corellia: return 1.82; case .narShaddaa: return 1.92; case .freeRoam: return 0.4 }
    }

    var hazeScale: Float {
        switch self { case .alpine: return 1.1; case .canyon: return 1.05; case .glacier: return 0.98; case .endor: return 0.9; case .skylands: return 0.82; case .volcano: return 0.74; case .storm: return 0.62; case .deathStar: return 1.8; case .boontaEve: return 1.25; case .sentinelOne: return 1.05; case .ordIbanna: return 0.9; case .andoPrime: return 0.74; case .lantaana: return 0.6; case .ordMantell: return 0.58; case .corellia: return 0.52; case .narShaddaa: return 0.46; case .freeRoam: return 1.3 }
    }

    var snowLine: Float { self == .alpine ? 890 : self == .andoPrime ? 520 : self == .skylands ? 410 : 10000 }

    var fogColor: SIMD3<Float> {
        switch self {
        case .alpine: return [0.71, 0.83, 0.91]
        case .canyon: return [0.87, 0.62, 0.35]
        case .glacier: return [0.84, 0.72, 0.53]
        case .storm: return [0.31, 0.18, 0.29]
        case .deathStar: return [0.12, 0.14, 0.18]
        case .endor: return [0.34, 0.5, 0.31]
        case .volcano: return [0.42, 0.16, 0.08]
        case .skylands: return [0.9, 0.57, 0.31]
        case .freeRoam: return [0.24, 0.33, 0.49]
        case .boontaEve: return [0.91, 0.68, 0.42]
        case .sentinelOne: return [0.45, 0.18, 0.1]
        case .ordIbanna: return [0.78, 0.55, 0.35]
        case .andoPrime: return [0.7, 0.83, 0.93]
        case .lantaana: return [0.35, 0.54, 0.37]
        case .ordMantell: return [0.45, 0.34, 0.24]
        case .corellia: return [0.34, 0.4, 0.48]
        case .narShaddaa: return [0.18, 0.16, 0.34]
        }
    }

    var skyColor: SIMD3<Float> {
        switch self {
        case .alpine: return [0.39, 0.66, 0.88]
        case .canyon: return [0.58, 0.31, 0.23]
        case .glacier: return [0.47, 0.39, 0.32]
        case .storm: return [0.12, 0.025, 0.12]
        case .deathStar: return [0.005, 0.008, 0.02]
        case .endor: return [0.12, 0.27, 0.2]
        case .volcano: return [0.13, 0.025, 0.008]
        case .skylands: return [0.93, 0.57, 0.3]
        case .freeRoam: return [0.08, 0.14, 0.32]
        case .boontaEve: return [0.93, 0.61, 0.29]
        case .sentinelOne: return [0.2, 0.035, 0.015]
        case .ordIbanna: return [0.62, 0.34, 0.2]
        case .andoPrime: return [0.2, 0.38, 0.58]
        case .lantaana: return [0.13, 0.3, 0.18]
        case .ordMantell: return [0.13, 0.1, 0.09]
        case .corellia: return [0.12, 0.22, 0.35]
        case .narShaddaa: return [0.045, 0.02, 0.12]
        }
    }

    var palette: [SIMD3<Float>] {
        switch self {
        case .alpine: return [[0.66, 0.75, 0.82], [0.56, 0.67, 0.75], [0.41, 0.53, 0.62], [0.34, 0.42, 0.51], [0.92, 0.96, 0.99]]
        case .canyon: return [[0.48, 0.25, 0.15], [0.68, 0.35, 0.17], [0.78, 0.49, 0.25], [0.53, 0.27, 0.17], [0.91, 0.7, 0.45]]
        case .glacier: return [[0.55, 0.42, 0.28], [0.61, 0.49, 0.34], [0.67, 0.54, 0.36], [0.42, 0.33, 0.24], [0.82, 0.75, 0.63]]
        case .storm: return [[0.16, 0.11, 0.2], [0.27, 0.15, 0.3], [0.39, 0.19, 0.34], [0.22, 0.12, 0.27], [0.72, 0.2, 0.34]]
        case .deathStar: return [[0.13, 0.14, 0.16], [0.2, 0.21, 0.23], [0.28, 0.29, 0.31], [0.1, 0.11, 0.13], [0.4, 0.42, 0.45]]
        case .endor: return [[0.08, 0.21, 0.11], [0.12, 0.28, 0.14], [0.2, 0.34, 0.18], [0.1, 0.2, 0.13], [0.36, 0.49, 0.29]]
        case .volcano: return [[0.14, 0.04, 0.025], [0.29, 0.07, 0.025], [0.47, 0.13, 0.035], [0.11, 0.035, 0.02], [0.82, 0.23, 0.035]]
        case .skylands: return [[0.54, 0.32, 0.2], [0.67, 0.42, 0.24], [0.79, 0.53, 0.3], [0.47, 0.29, 0.23], [0.96, 0.73, 0.43]]
        case .freeRoam: return [[0.2, 0.31, 0.42], [0.31, 0.39, 0.51], [0.42, 0.47, 0.58], [0.22, 0.28, 0.41], [0.68, 0.72, 0.78]]
        case .boontaEve: return [[0.62, 0.38, 0.18], [0.77, 0.48, 0.22], [0.88, 0.62, 0.3], [0.59, 0.33, 0.17], [0.97, 0.78, 0.5]]
        case .sentinelOne: return [[0.16, 0.045, 0.025], [0.31, 0.075, 0.03], [0.48, 0.13, 0.035], [0.19, 0.055, 0.025], [0.87, 0.28, 0.04]]
        case .ordIbanna: return [[0.5, 0.29, 0.16], [0.67, 0.39, 0.2], [0.78, 0.5, 0.27], [0.44, 0.24, 0.15], [0.89, 0.66, 0.39]]
        case .andoPrime: return [[0.29, 0.43, 0.54], [0.42, 0.59, 0.69], [0.55, 0.71, 0.8], [0.29, 0.4, 0.5], [0.88, 0.94, 0.98]]
        case .lantaana: return [[0.07, 0.2, 0.1], [0.1, 0.3, 0.15], [0.17, 0.39, 0.2], [0.08, 0.18, 0.12], [0.39, 0.61, 0.35]]
        case .ordMantell: return [[0.2, 0.17, 0.15], [0.32, 0.25, 0.2], [0.46, 0.34, 0.24], [0.16, 0.14, 0.13], [0.72, 0.39, 0.2]]
        case .corellia: return [[0.16, 0.21, 0.28], [0.24, 0.31, 0.4], [0.35, 0.43, 0.52], [0.12, 0.17, 0.24], [0.45, 0.63, 0.8]]
        case .narShaddaa: return [[0.11, 0.08, 0.2], [0.2, 0.12, 0.31], [0.31, 0.17, 0.42], [0.08, 0.06, 0.16], [0.65, 0.2, 0.57]]
        }
    }

    var next: FlightLevel? { number < Self.allCases.count ? Self.allCases[number] : nil }
}

/// Gate records belong to a route, so changing levels never shares another route's score.
struct FlightProgress {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func best(for level: FlightLevel) -> Int {
        let value = defaults.object(forKey: "bestGates.\(level.rawValue)") as? Int
        return clamp(value ?? (level == .alpine ? defaults.integer(forKey: "bestGates") : 0), 0, level.gateCount * (level.isPodRaceTrack ? 3 : 1))
    }

    func record(gates: Int, for level: FlightLevel) {
        defaults.set(max(best(for: level), clamp(gates, 0, level.gateCount * (level.isPodRaceTrack ? 3 : 1))), forKey: "bestGates.\(level.rawValue)")
    }
}
