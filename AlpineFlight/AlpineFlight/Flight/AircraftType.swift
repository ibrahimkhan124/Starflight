import Foundation
import simd

/// Original aircraft with game-tuned performance, rather than real aircraft specifications.
enum AircraftType: String, CaseIterable, Identifiable, Codable, Sendable {
    case kestrel, meridian, falcon, atlas, xwing, tieFighter, millenniumFalcon
    case aWing, yWing, n1Starfighter, enterprise, voyager, birdOfPrey
    case starkJet, novaSkiff, anakinPodracer, sebulbaPodracer, quadinPodracer, rattsPodracer, nevaKeePodracer, voltwingPodracer, razorCrest

    case bWing, imperialShuttle, tieDefender, tieInterceptor, slaveI, scimitar, starDestroyer

    var id: String { rawValue }

    var name: String {
        switch self { case .starDestroyer: return "Imperial Star Destroyer"; case .tieInterceptor: return "TIE Interceptor"; case .slaveI: return "Slave I"; case .scimitar: return "Scimitar";  case .bWing: return "B-wing"; case .imperialShuttle: return "Imperial Shuttle"; case .tieDefender: return "TIE Defender";  case .razorCrest: return "Razor Crest";
        case .kestrel: return "T-47 Snowspeeder"
        case .meridian: return "Rebel U-wing"
        case .falcon: return "ARC-170 Starfighter"
        case .atlas: return "LAAT/i Gunship"
        case .xwing: return "T-65 X-wing"
        case .tieFighter: return "TIE fighter"
        case .millenniumFalcon: return "Millennium Falcon"
        case .aWing: return "A-wing"
        case .yWing: return "Y-wing"
        case .n1Starfighter: return "Naboo N-1"
        case .enterprise: return "USS Enterprise"
        case .voyager: return "USS Voyager"
        case .birdOfPrey: return "Klingon Bird-of-Prey"
        case .starkJet: return "T-70 X-wing"
        case .novaSkiff: return "Eta-2 Jedi Interceptor"
        case .anakinPodracer: return "Anakin’s Podracer"
        case .sebulbaPodracer: return "Sebulba’s Podracer"
        case .quadinPodracer: return "Quadinaros’ Podracer"
        case .rattsPodracer: return "Ratts Tyerell’s Podracer"
        case .nevaKeePodracer: return "Neva Kee’s Podracer"
        case .voltwingPodracer: return "Voltwing Podracer"
        }
    }

    var category: String {
        switch self { case .starDestroyer: return "IMPERIAL CAPITAL SHIP"; case .tieInterceptor: return "IMPERIAL INTERCEPTOR"; case .slaveI: return "BOUNTY HUNTER ATTACK SHIP"; case .scimitar: return "SITH INFILTRATOR";  case .bWing: return "REBEL HEAVY FIGHTER"; case .imperialShuttle: return "IMPERIAL COMMAND SHUTTLE"; case .tieDefender: return "ELITE IMPERIAL INTERCEPTOR";  case .razorCrest: return "MANDALORIAN GUNSHIP";
        case .kestrel: return "REBEL SNOWSPEEDER"
        case .meridian: return "REBEL ASSAULT TRANSPORT"
        case .falcon: return "REPUBLIC STARFIGHTER"
        case .atlas: return "REPUBLIC GUNSHIP"
        case .xwing: return "REBEL STARFIGHTER"
        case .tieFighter: return "IMPERIAL STARFIGHTER"
        case .millenniumFalcon: return "LIGHT FREIGHTER"
        case .aWing: return "REBEL INTERCEPTOR"
        case .yWing: return "REBEL BOMBER"
        case .n1Starfighter: return "NABOO STARFIGHTER"
        case .enterprise: return "STARFLEET EXPLORER"
        case .voyager: return "STARFLEET SCIENCE SHIP"
        case .birdOfPrey: return "KLINGON RAIDER"
        case .starkJet: return "RESISTANCE STARFIGHTER"
        case .novaSkiff: return "JEDI INTERCEPTOR"
        case .anakinPodracer, .sebulbaPodracer, .quadinPodracer, .rattsPodracer, .nevaKeePodracer: return "PODRACER"
        case .voltwingPodracer: return "PODRACER · BLENDER MODEL"
        }
    }

    var summary: String {
        switch self { case .starDestroyer: return "Command a formidable wedge-shaped Imperial capital ship with powerful guns and steady, heavy handling."; case .tieInterceptor: return "Four dagger-shaped solar wings and quick ion drives. Collect rare blueprints to unlock this agile interceptor."; case .slaveI: return "A distinctive armoured patrol craft with rotating stabilisers and twin heavy guns. Collect epic blueprints."; case .scimitar: return "A long-nosed Sith infiltrator with folding solar wings, red drives and powerful cannons. Collect legendary blueprints.";  case .bWing: return "An asymmetric heavy fighter with a long weapons spar and powerful cannons. Collect its rare blueprints."; case .imperialShuttle: return "A tri-wing command shuttle with reinforced armour and strong guns. Collect epic blueprints."; case .tieDefender: return "A fast six-panel interceptor with exceptional agility and advanced lasers. Legendary blueprints are the hardest to find.";  case .razorCrest: return "Din Djarin and Grogu’s original armored gunship, with twin engines and a roomy cargo hold.";
        case .kestrel: return "A rugged Rebel snow speeder built to skim icy ridges and surprise Imperial walkers."
        case .meridian: return "A versatile Rebel transport with a troop bay, folding wings, and heavy forward cannons."
        case .falcon: return "A Republic-era heavy fighter with three engines, broad wings, and a rear gunner turret."
        case .atlas: return "A fast low-altitude Republic gunship with troop doors and twin laser cannons."
        case .xwing: return "Lock S-foils into attack position and thread the trench at high speed."
        case .tieFighter: return "Twin ion engines and instant roll response make this a precise, unforgiving interceptor."
        case .millenniumFalcon: return "A famously quick freighter with a broad hull, offset cockpit, and surprisingly lively handling."
        case .aWing: return "A compact wedge-shaped interceptor built for lightning-fast turns."
        case .yWing: return "A rugged twin-engine bomber. Hold a steady line through dangerous passes."
        case .n1Starfighter: return "A sleek royal starfighter with twin needle-like engine pods."
        case .enterprise: return "Explore in a classic saucer-and-nacelle starship with calm, deliberate controls."
        case .voyager: return "A compact Starfleet explorer with swept pylons and responsive handling."
        case .birdOfPrey: return "A winged raider that banks sharply through the mountain corridors."
        case .starkJet: return "A next-generation Resistance starfighter with powerful, precise laser cannons."
        case .novaSkiff: return "A tiny Jedi interceptor with sharp turns and an oversized punch."
        case .anakinPodracer: return "Twin turbine engines, long control cables, and a nimble cockpit pod."
        case .sebulbaPodracer: return "A brutal, wide-bodied racer with oversized engines and a heavy cockpit sled."
        case .quadinPodracer: return "Four roaring turbines make this unusual racer quick off the line and easy to steer."
        case .rattsPodracer: return "A tiny, light racer with compact engines and razor-sharp response through tight gates."
        case .nevaKeePodracer: return "A broad, heavy twin-engine pod that trades agility for a strong, steady launch."
        case .voltwingPodracer: return "An original low-poly racer built in Blender, exported as USDZ, and driven by Swift physics."
        }
    }

    var handling: String {
        switch self { case .starDestroyer: return "Heavy & powerful"; case .tieInterceptor: return "Fast & precise"; case .slaveI: return "Armoured attack ship"; case .scimitar: return "Swift & powerful";  case .bWing: return "Heavy cannon platform"; case .imperialShuttle: return "Armoured & powerful"; case .tieDefender: return "Elite speed & agility";  case .razorCrest: return "Heavy & powerful";
        case .kestrel: return "Low & nimble"
        case .meridian: return "Smooth & heavy"
        case .falcon: return "Fast & agile"
        case .atlas: return "Steady & broad"
        case .xwing: return "Fast & balanced"
        case .tieFighter: return "Ultra agile"
        case .millenniumFalcon: return "Quick & wide"
        case .aWing: return "Lightning fast"
        case .yWing: return "Heavy & steady"
        case .n1Starfighter: return "Nimble"
        case .enterprise: return "Majestic"
        case .voyager: return "Smooth & swift"
        case .birdOfPrey: return "Aggressive"
        case .starkJet: return "Fast & precise"
        case .novaSkiff: return "Nimble"
        case .anakinPodracer: return "Fast & light"
        case .sebulbaPodracer: return "Heavy & powerful"
        case .quadinPodracer: return "Stable & quick"
        case .rattsPodracer: return "Tiny & nimble"
        case .nevaKeePodracer: return "Heavy & steady"
        case .voltwingPodracer: return "Fast & skittish"
        }
    }

    var cruiseSpeed: Float {
        switch self { case .starDestroyer: return 110; case .tieInterceptor: return 198; case .slaveI: return 155; case .scimitar: return 205;  case .bWing: return 150; case .imperialShuttle: return 140; case .tieDefender: return 210;  case .razorCrest: return 145; case .kestrel: return 62; case .meridian: return 115; case .falcon: return 160; case .starkJet: return 175; case .atlas: return 92; case .xwing: return 165; case .tieFighter: return 175; case .millenniumFalcon: return 155; case .aWing: return 185; case .yWing: return 130; case .n1Starfighter: return 170; case .enterprise: return 95; case .voyager: return 125; case .birdOfPrey: return 145; case .novaSkiff: return 180; case .anakinPodracer: return 205; case .sebulbaPodracer: return 195; case .quadinPodracer: return 185; case .rattsPodracer: return 212; case .nevaKeePodracer: return 178; case .voltwingPodracer: return 220 }
    }

    var response: Float {
        switch self { case .starDestroyer: return 1.4; case .tieInterceptor: return 5.3; case .slaveI: return 3.2; case .scimitar: return 5.0;  case .bWing: return 3.2; case .imperialShuttle: return 2.5; case .tieDefender: return 5.6;  case .razorCrest: return 2.6; case .kestrel: return 2.5; case .meridian: return 1.75; case .falcon: return 4.2; case .starkJet: return 4.5; case .atlas: return 2.8; case .xwing: return 4.2; case .tieFighter: return 4.8; case .millenniumFalcon: return 3.4; case .aWing: return 5; case .yWing: return 2; case .n1Starfighter: return 4.4; case .enterprise: return 1.15; case .voyager: return 2.2; case .birdOfPrey: return 3.6; case .novaSkiff: return 4.5; case .anakinPodracer: return 5.2; case .sebulbaPodracer: return 3.8; case .quadinPodracer: return 4.4; case .rattsPodracer: return 5.6; case .nevaKeePodracer: return 3.5; case .voltwingPodracer: return 5.4 }
    }

    var maximumPitch: Float {
        switch self { case .starDestroyer: return 0.32; case .tieInterceptor: return AircraftType.tieFighter.maximumPitch; case .slaveI: return AircraftType.millenniumFalcon.maximumPitch; case .scimitar: return AircraftType.imperialShuttle.maximumPitch;  case .bWing: return AircraftType.yWing.maximumPitch; case .imperialShuttle: return AircraftType.meridian.maximumPitch; case .tieDefender: return AircraftType.tieFighter.maximumPitch;  case .razorCrest: return 0.5; case .kestrel: return 0.48; case .meridian: return 0.45; case .falcon: return 0.62; case .starkJet: return 0.68; case .atlas: return 0.5; case .xwing: return 0.62; case .tieFighter: return 0.66; case .millenniumFalcon: return 0.5; case .aWing: return 0.7; case .yWing: return 0.4; case .n1Starfighter: return 0.62; case .enterprise: return 0.3; case .voyager: return 0.42; case .birdOfPrey: return 0.55; case .novaSkiff: return 0.68; case .anakinPodracer: return 0.72; case .sebulbaPodracer: return 0.56; case .quadinPodracer: return 0.64; case .rattsPodracer: return 0.78; case .nevaKeePodracer: return 0.5; case .voltwingPodracer: return 0.7 }
    }

    var maximumRoll: Float {
        switch self { case .starDestroyer: return 0.65; case .tieInterceptor: return AircraftType.tieFighter.maximumRoll; case .slaveI: return AircraftType.millenniumFalcon.maximumRoll; case .scimitar: return AircraftType.imperialShuttle.maximumRoll;  case .bWing: return AircraftType.yWing.maximumRoll; case .imperialShuttle: return AircraftType.meridian.maximumRoll; case .tieDefender: return AircraftType.tieFighter.maximumRoll;  case .razorCrest: return 1.1; case .kestrel: return 1.05; case .meridian: return 1.0; case .falcon: return 1.38; case .starkJet: return 1.4; case .atlas: return 1.1; case .xwing: return 1.35; case .tieFighter: return 1.48; case .millenniumFalcon: return 1.12; case .aWing: return 1.55; case .yWing: return 0.85; case .n1Starfighter: return 1.4; case .enterprise: return 0.7; case .voyager: return 0.95; case .birdOfPrey: return 1.3; case .novaSkiff: return 1.5; case .anakinPodracer: return 1.6; case .sebulbaPodracer: return 1.2; case .quadinPodracer: return 1.4; case .rattsPodracer: return 1.72; case .nevaKeePodracer: return 1.0; case .voltwingPodracer: return 1.5 }
    }

    var yawAuthority: Float {
        switch self { case .starDestroyer: return 0.17; case .tieInterceptor: return AircraftType.tieFighter.yawAuthority; case .slaveI: return AircraftType.millenniumFalcon.yawAuthority; case .scimitar: return AircraftType.imperialShuttle.yawAuthority;  case .bWing: return AircraftType.yWing.yawAuthority; case .imperialShuttle: return AircraftType.meridian.yawAuthority; case .tieDefender: return AircraftType.tieFighter.yawAuthority;  case .razorCrest: return 0.28; case .kestrel: return 0.23; case .meridian: return 0.2; case .falcon: return 0.4; case .starkJet: return 0.42; case .atlas: return 0.24; case .xwing: return 0.38; case .tieFighter: return 0.42; case .millenniumFalcon: return 0.3; case .aWing: return 0.44; case .yWing: return 0.23; case .n1Starfighter: return 0.4; case .enterprise: return 0.16; case .voyager: return 0.22; case .birdOfPrey: return 0.36; case .novaSkiff: return 0.4; case .anakinPodracer: return 0.48; case .sebulbaPodracer: return 0.36; case .quadinPodracer: return 0.42; case .rattsPodracer: return 0.52; case .nevaKeePodracer: return 0.31; case .voltwingPodracer: return 0.5 }
    }

    var wingspan: Float {
        switch self { case .starDestroyer: return 38; case .tieInterceptor: return 14.5; case .slaveI: return 22; case .scimitar: return 26;  case .bWing: return 18; case .imperialShuttle: return 25; case .tieDefender: return 13;  case .razorCrest: return 24; case .kestrel: return 12.4; case .meridian: return 27; case .falcon: return 14; case .starkJet: return 11.8; case .atlas: return 21; case .xwing: return 11.8; case .tieFighter: return 6.7; case .millenniumFalcon: return 25.6; case .aWing: return 9; case .yWing: return 12; case .n1Starfighter: return 12; case .enterprise: return 39; case .voyager: return 34; case .birdOfPrey: return 27; case .novaSkiff: return 8.9; case .anakinPodracer: return 35.5; case .sebulbaPodracer: return 41.6; case .quadinPodracer: return 43.5; case .rattsPodracer: return 28; case .nevaKeePodracer: return 50; case .voltwingPodracer: return 29 }
    }

    var length: Float {
        switch self { case .starDestroyer: return 50; case .tieInterceptor: return 12; case .slaveI: return 28; case .scimitar: return 24;  case .bWing: return 17; case .imperialShuttle: return 24; case .tieDefender: return 12;  case .razorCrest: return 27; case .kestrel: return 10; case .meridian: return 22.6; case .falcon: return 19; case .starkJet: return 13.4; case .atlas: return 24; case .xwing: return 13.4; case .tieFighter: return 8; case .millenniumFalcon: return 34.8; case .aWing: return 9.6; case .yWing: return 16; case .n1Starfighter: return 12; case .enterprise: return 42; case .voyager: return 37; case .birdOfPrey: return 25; case .novaSkiff: return 9.9; case .anakinPodracer: return 20; case .sebulbaPodracer: return 22; case .quadinPodracer: return 20; case .rattsPodracer: return 17; case .nevaKeePodracer: return 20; case .voltwingPodracer: return 19 }
    }

    var bodyRadius: Float {
        switch self { case .starDestroyer: return 3.5; case .tieInterceptor: return 2; case .slaveI: return 3; case .scimitar: return 2.8;  case .bWing: return 1.5; case .imperialShuttle: return 2.5; case .tieDefender: return 2.5;  case .razorCrest: return 2.2; case .kestrel: return 1; case .meridian: return 1.8; case .falcon: return 1.4; case .starkJet: return 1; case .atlas: return 1.8; case .xwing: return 1; case .tieFighter: return 2.5; case .millenniumFalcon: return 2.2; case .aWing: return 1; case .yWing: return 1.2; case .n1Starfighter: return 1; case .enterprise: return 3; case .voyager: return 2.8; case .birdOfPrey: return 2.2; case .novaSkiff: return 0.9; case .anakinPodracer: return 0.8; case .sebulbaPodracer: return 1.1; case .quadinPodracer: return 1; case .rattsPodracer: return 0.65; case .nevaKeePodracer: return 1.35; case .voltwingPodracer: return 1.1 }
    }

    /// Forgiving city contact envelope; visual dimensions and ground clearance stay full size.
    var cityCollisionRadius: Float { bodyRadius * 0.6 }

    var chaseOffset: SIMD3<Float> { [0, max(9, length * 0.45), max(31, length * 2)] }
    var cockpitOffset: SIMD3<Float> { self == .starDestroyer ? [0, 6, 16] : [0, bodyRadius * 1.2, -length * 0.32] }
    var hasPropellers: Bool { false }
    var isPodracer: Bool {
        switch self { case .tieInterceptor: return AircraftType.tieFighter.isPodracer; case .slaveI: return AircraftType.millenniumFalcon.isPodracer; case .scimitar: return AircraftType.imperialShuttle.isPodracer; 
        case .anakinPodracer, .sebulbaPodracer, .quadinPodracer, .rattsPodracer, .nevaKeePodracer, .voltwingPodracer: return true
        default: return false
        }
    }

    var weaponPower: Float {
        switch self { case .starDestroyer: return 48; case .tieInterceptor: return 19; case .slaveI: return 34; case .scimitar: return 40;  case .bWing: return 28; case .imperialShuttle: return 32; case .tieDefender: return 36;  case .razorCrest: return 24;
        case .kestrel: return 8
        case .meridian, .enterprise, .voyager: return 5
        case .falcon, .atlas: return 12
        case .xwing, .n1Starfighter: return 15
        case .tieFighter, .aWing: return 11
        case .millenniumFalcon, .birdOfPrey: return 18
        case .yWing, .novaSkiff: return 22
        case .starkJet: return 20
        case .anakinPodracer, .sebulbaPodracer, .quadinPodracer, .rattsPodracer, .nevaKeePodracer, .voltwingPodracer: return 14
        }
    }

    var weaponCooldown: Float {
        switch self { case .starDestroyer: return 0.35; case .tieInterceptor: return 0.15; case .slaveI: return 0.3; case .scimitar: return 0.2;  case .bWing: return 0.3; case .imperialShuttle: return 0.32; case .tieDefender: return 0.16;  case .razorCrest: return 0.32;
        case .aWing, .tieFighter, .xwing: return 0.16
        case .falcon, .n1Starfighter, .birdOfPrey: return 0.22
        case .yWing, .millenniumFalcon: return 0.34
        case .kestrel, .meridian, .atlas, .enterprise, .voyager, .novaSkiff, .quadinPodracer, .nevaKeePodracer: return 0.48
        case .anakinPodracer, .sebulbaPodracer, .rattsPodracer, .voltwingPodracer: return 0.2
        case .starkJet: return 0.18
        }
    }

    var weaponSpeed: Float {
        switch self { case .starDestroyer: return 230; case .tieInterceptor: return AircraftType.tieFighter.weaponSpeed; case .slaveI: return AircraftType.millenniumFalcon.weaponSpeed; case .scimitar: return AircraftType.imperialShuttle.weaponSpeed;  case .bWing: return AircraftType.yWing.weaponSpeed; case .imperialShuttle: return AircraftType.meridian.weaponSpeed; case .tieDefender: return AircraftType.tieFighter.weaponSpeed; 
        case .aWing, .tieFighter, .xwing, .anakinPodracer, .sebulbaPodracer, .quadinPodracer, .rattsPodracer, .nevaKeePodracer, .voltwingPodracer: return 300
        case .falcon, .n1Starfighter, .birdOfPrey: return 270
        default: return 230
        }
    }

    var collisionProbes: [SIMD3<Float>] {
        if self == .starDestroyer {
            return [[0, -0.6, 0], [0, 0, -25], [0, 0, 25], [-9, 0, 0], [9, 0, 0], [-18, 0, 23], [18, 0, 23]]
        }
        var probes: [SIMD3<Float>] = [[0, -bodyRadius, 0], [0, 0, -length * 0.5], [0, 0, length * 0.5]]
        for side: Float in [-1, 1] {
            for fraction: Float in [0.25, 0.5] {
                probes.append([side * wingspan * fraction, 0, self == .meridian || self == .falcon || self == .millenniumFalcon ? fraction * 6 : 0])
            }
        }
        return probes
    }
}
