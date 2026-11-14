import SwiftUI

enum AircraftColor: String, CaseIterable, Identifiable {
    case glacier, rescue, marigold
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .glacier: return Color(red: 0.8, green: 0.9, blue: 0.87)
        case .rescue: return Color(red: 0.9, green: 0.26, blue: 0.18)
        case .marigold: return Color(red: 0.97, green: 0.66, blue: 0.2)
        }
    }
}

enum LaunchIntroStyle: String, CaseIterable, Identifiable {
    case canva, starWars
    var id: String { rawValue }
    var title: String { self == .canva ? "Canva cinematic" : "Star Wars title" }
}

enum HangarPreviewStyle: String, CaseIterable, Identifiable {
    case hangar, selectedLevel
    var id: String { rawValue }
    var title: String { self == .hangar ? "Hangar showroom" : "Selected level" }
}

struct GameSettings {
    var hangarPreview: HangarPreviewStyle = .hangar
    var weather: FlightWeather = .clear
    var showGhost = true
    var introStyle: LaunchIntroStyle = .canva
    var spaceFreeRoam = false
    var tiltEnabled = false
    var handControlEnabled = false
    var invertPitch = false
    var soundEnabled = true
    var soundVolume: Float = 0.8
    var sensitivity: Float = 1
    var reducedDetail = false
    var performanceMode = true
    var terrainReducedDetail: Bool { performanceMode || reducedDetail }
    var flightFramesPerSecond: Int { performanceMode ? 30 : 60 }
    var aircraftColor: AircraftColor = .glacier
    var aircraft: AircraftType = .kestrel
    var droid: DroidType = .r2d2
    var level: FlightLevel = .alpine

    init(defaults: UserDefaults = .standard) {
        hangarPreview = HangarPreviewStyle(rawValue: defaults.string(forKey: "hangarPreview") ?? "") ?? .hangar
        weather = FlightWeather(rawValue:defaults.string(forKey:"flightWeather") ?? "") ?? .clear
        showGhost = defaults.object(forKey:"showLapGhost") as? Bool ?? true
        introStyle = LaunchIntroStyle(rawValue: defaults.string(forKey: "introStyle") ?? "") ?? .canva
        spaceFreeRoam = defaults.bool(forKey: "spaceFreeRoam")
        tiltEnabled = defaults.bool(forKey: "tilt")
        handControlEnabled = defaults.bool(forKey: "handControl")
        invertPitch = defaults.bool(forKey: "invertPitch")
        soundEnabled = defaults.object(forKey: "sound") as? Bool ?? true
        let savedVolume: Float = defaults.object(forKey:"soundVolume") == nil ? 0.8 : defaults.float(forKey:"soundVolume")
        soundVolume = savedVolume.isFinite ? clamp(savedVolume,0,1) : 0.8
        sensitivity = defaults.object(forKey: "sensitivity") as? Float ?? 1
        reducedDetail = defaults.bool(forKey: "reducedDetail")
        performanceMode = defaults.object(forKey: "performanceMode") as? Bool ?? true
        aircraftColor = AircraftColor(rawValue: defaults.string(forKey: "aircraftColor") ?? "") ?? .glacier
        aircraft = AircraftType(rawValue: defaults.string(forKey: "aircraft") ?? "") ?? .kestrel
        droid = DroidType(rawValue: defaults.string(forKey: "droid") ?? "") ?? .r2d2
        level = FlightLevel(rawValue: defaults.string(forKey: "level") ?? "") ?? .alpine
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(hangarPreview.rawValue, forKey: "hangarPreview")
        defaults.set(weather.rawValue,forKey:"flightWeather")
        defaults.set(showGhost,forKey:"showLapGhost")
        defaults.set(introStyle.rawValue, forKey: "introStyle")
        defaults.set(spaceFreeRoam, forKey: "spaceFreeRoam")
        defaults.set(tiltEnabled, forKey: "tilt")
        defaults.set(handControlEnabled, forKey: "handControl")
        defaults.set(invertPitch, forKey: "invertPitch")
        defaults.set(soundEnabled, forKey: "sound")
        defaults.set(soundVolume, forKey:"soundVolume")
        defaults.set(sensitivity, forKey: "sensitivity")
        defaults.set(reducedDetail, forKey: "reducedDetail")
        defaults.set(performanceMode, forKey: "performanceMode")
        defaults.set(aircraftColor.rawValue, forKey: "aircraftColor")
        defaults.set(aircraft.rawValue, forKey: "aircraft")
        defaults.set(droid.rawValue, forKey: "droid")
        defaults.set(level.rawValue, forKey: "level")
    }
}
