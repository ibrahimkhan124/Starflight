import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// Playback follows media volume and the in-game sound setting, including in Silent Mode.
/// Recording owns its session while the droid microphone is listening.
@MainActor
enum GameAudioSession {
    static func preparePlayback(activate:Bool = false) throws {
#if canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        guard session.category != .playAndRecord else { return }
        if session.category != .playback || session.mode != .default || !session.categoryOptions.contains(.mixWithOthers) {
            try session.setCategory(.playback,mode:.default,options:[.mixWithOthers])
        }
        if activate { try session.setActive(true) }
#endif
    }
    static func restoreAfterRecording() {
#if canImport(UIKit)
        try? AVAudioSession.sharedInstance().setCategory(.playback,mode:.default,options:[.mixWithOthers])
#endif
    }
    static var outputDescription:String {
#if canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute.outputs.map(\.portName).joined(separator:", ")
        return (route.isEmpty ? "Device audio output":route) + " · device volume \(Int(session.outputVolume*100))%"
#else
        return "System audio output"
#endif
    }
}

/// Frame-rate-independent control smoothing prevents audible throttle steps.
struct FlightSoundMix {
    private(set) var engine: Float = 0
    private(set) var rate: Float = 0.8
    private(set) var wind: Float = 0
    private(set) var skid: Float = 0

    mutating func advance(throttle: Float, speed: Float, clearance: Float, dt: Float,
                          inSpace: Bool, boosting: Bool, skidding: Bool, cockpit: Bool) {
        let power = throttle.isFinite ? clamp(abs(throttle),0,1) : 0
        let velocity = speed.isFinite ? clamp(speed/260,0,1) : 0
        let proximity: Float = clearance.isFinite ? 1-clamp(clearance/100,0,1) : 0
        let step = dt.isFinite ? clamp(dt,0,0.25) : 0
        let response = 1-exp(-step*7)
        let engineTarget: Float = (0.11+power*0.13+(boosting ? 0.055:0))*(cockpit ? 0.82:1)
        let pitchTarget: Float = 0.78+power*0.36+velocity*0.08+(boosting ? 0.08:0)
        let windTarget: Float = inSpace ? 0 : (velocity*velocity*0.075+proximity*velocity*0.04)*(cockpit ? 0.3:1)
        let skidTarget: Float = skidding && !inSpace ? velocity*0.17 : 0
        engine += (engineTarget-engine)*response
        rate += (pitchTarget-rate)*response
        wind += (windTarget-wind)*response
        skid += (skidTarget-skid)*response
    }
    mutating func reset() { self = FlightSoundMix() }
}

/// Crossfades weather beds independently of the aircraft engine. No audio in vacuum.
struct WeatherSoundMix {
    private(set) var rain: Float = 0
    private(set) var snow: Float = 0
    private(set) var dust: Float = 0
    private(set) var mist: Float = 0
    mutating func advance(weather:FlightWeather,active:Bool,cockpit:Bool,dt:Float) {
        let step = dt.isFinite ? clamp(dt,0,0.25):0
        let response = 1-exp(-step*2.2)
        let gain:Float = active ? (cockpit ? 0.42:1):0
        rain += ((weather == .rain ? 0.32*gain:0)-rain)*response
        snow += ((weather == .whiteout ? 0.32*gain:0)-snow)*response
        dust += ((weather == .dust ? 0.30*gain:0)-dust)*response
        mist += ((weather == .mist ? 0.14*gain:0)-mist)*response
    }
}

@MainActor
final class FlightAudio {
    enum EngineProfile: String, CaseIterable {
        case fighter = "jet", freighter = "engine", ion, warp, pod
        static func profile(for aircraft: AircraftType) -> Self {
            if aircraft.isPodracer { return .pod }
            switch aircraft {
            case .tieFighter,.tieDefender,.tieInterceptor: return .ion
            case .enterprise,.voyager,.birdOfPrey: return .warp
            case .millenniumFalcon,.razorCrest,.atlas,.meridian,.imperialShuttle,.slaveI,.scimitar: return .freighter
            default: return .fighter
            }
        }
    }
    static let effectNames = ["impact","checkpoint","laser","laser_heavy","laser_ion","shield","hyperspace","arrival","boost","droid","weather_thunder"]
    static let weatherLoops = ["weather_rain","weather_snow","weather_dust","weather_mist"]
    static var assetNames: [String] { EngineProfile.allCases.map(\.rawValue)+["wind","skid"]+weatherLoops+effectNames }
    private var loops: [String:AVAudioPlayer] = [:]
    private var effects: [String:[AVAudioPlayer]] = [:]
    private var slots: [String:Int] = [:]
    private var lastShieldTime: TimeInterval = -.infinity
    private var wasBoosting = false
    private var hasPlayback = false
    private var activeProfile: EngineProfile?
    private var master: Float = 0.8
    private var sessionReady = false
    private(set) var playbackIssue:String?
    var isPlaying:Bool { loops.values.contains(where: { $0.isPlaying }) || effects.values.flatMap { $0 }.contains(where: { $0.isPlaying }) }
    private var mix = FlightSoundMix()
    private var weatherMix = WeatherSoundMix()
    private var thunderClock:Float = 0
    private(set) var missingAssets: [String] = []

    init() {
        do { try GameAudioSession.preparePlayback() }
        catch { playbackIssue = "Audio setup: " + error.localizedDescription }
        for name in EngineProfile.allCases.map(\.rawValue)+["wind","skid"]+Self.weatherLoops {
            if let player = load(name) {
                player.numberOfLoops = -1; player.enableRate = true
                loops[name] = player
            } else { missingAssets.append(name) }
        }
        for name in Self.effectNames {
            // Short volleys can overlap; a new shot does not cut off the previous tail.
            let count = name.hasPrefix("laser") ? 3 : 1
            let pool = (0..<count).compactMap { _ in load(name) }
            if pool.count != count { missingAssets.append(name) }
            effects[name] = pool
        }
    }
    static func assetURL(_ name: String) -> URL? {
        Bundle.main.url(forResource:name,withExtension:"wav",subdirectory:"Audio") ??
            Bundle.main.url(forResource:name,withExtension:"wav")
    }
    private func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Self.assetURL(name), let player = try? AVAudioPlayer(contentsOf:url) else { return nil }
        player.volume = 0; player.enableRate = true; player.prepareToPlay()
        return player
    }
    func setVolume(_ value: Float) {
        master = value.isFinite ? clamp(value,0,1) : 0.8
        if master == 0 { suspend() }
    }
    func suspend() {
        sessionReady = false
        guard hasPlayback else { return }
        for player in loops.values { player.pause(); player.volume = 0 }
        for pool in effects.values { for player in pool { player.stop(); player.currentTime = 0 } }
        mix.reset(); weatherMix = WeatherSoundMix(); thunderClock = 0; wasBoosting = false; hasPlayback = false; activeProfile = nil
    }
    func update(throttle: Float, enabled: Bool, flying: Bool, aircraft: AircraftType = .kestrel,
                speed: Float = 0, clearance: Float = 300, dt: Float = 0.1,
                inSpace: Bool = false, boosting: Bool = false, skidding: Bool = false, cockpit: Bool = false, weather:FlightWeather = .clear, weatherActive:Bool = false) {
        guard enabled && master > 0 else { suspend(); return }
        guard flying else {
            for player in loops.values where player.isPlaying { player.pause() }
            for player in effects["weather_thunder"] ?? [] { player.stop(); player.currentTime = 0 }
            mix.reset(); weatherMix = WeatherSoundMix(); thunderClock = 0; wasBoosting = false
            return // Crash/checkpoint tails are allowed to finish after flight stops.
        }
        mix.advance(throttle:throttle,speed:speed,clearance:clearance,dt:dt,inSpace:inSpace,boosting:boosting,skidding:skidding,cockpit:cockpit)
        weatherMix.advance(weather:weather,active:weatherActive && !inSpace,cockpit:cockpit,dt:dt)
        for (name,volume) in zip(Self.weatherLoops,[weatherMix.rain,weatherMix.snow,weatherMix.dust,weatherMix.mist]) {
            if let player = loops[name] { playLoop(player,volume:volume,rate:1) }
        }
        if weatherActive && !inSpace && weather == .rain {
            thunderClock += dt.isFinite ? clamp(dt,0,0.25):0
            if thunderClock >= 19 { thunderClock = 0; effect("weather_thunder",enabled:enabled,volume:cockpit ? 0.13:0.25,pan:-0.35) }
        } else { thunderClock = 0 }
        let profile = EngineProfile.profile(for:aircraft)
        if activeProfile != profile {
            for kind in EngineProfile.allCases where kind != profile {
                if let player = loops[kind.rawValue], player.isPlaying { player.pause() }
            }
            activeProfile = profile
        }
        if let player = loops[profile.rawValue] { playLoop(player,volume:mix.engine,rate:mix.rate) }
        if let wind = loops["wind"] { playLoop(wind,volume:mix.wind,rate:0.85+min(1,max(0,speed/260))*0.25) }
        if let skid = loops["skid"] { playLoop(skid,volume:mix.skid,rate:0.9) }
        if boosting && !wasBoosting { effect("boost",enabled:enabled,volume:0.28) }
        wasBoosting = boosting
    }
    private func activatePlayback() -> Bool {
        guard !sessionReady else { return true }
        do { try GameAudioSession.preparePlayback(activate:true); sessionReady = true; playbackIssue = nil; return true }
        catch { playbackIssue = "Audio output: " + error.localizedDescription; return false }
    }
    func testSound(enabled:Bool) -> String {
        guard enabled else { return "Turn on Sound effects to hear the test." }
        guard master > 0 else { return "Raise the game's Sound volume above 0%." }
        guard effect("checkpoint",enabled:true,volume:0.6) else {
            return playbackIssue ?? "The test sound could not start."
        }
        return "Test sound playing · " + GameAudioSession.outputDescription
    }
    private func playLoop(_ player: AVAudioPlayer, volume: Float, rate: Float) {
        player.volume = volume*master*0.75
        player.rate = clamp(rate,0.5,2)
        if volume > 0.001 {
            if !player.isPlaying && activatePlayback() {
                let started = player.play(); hasPlayback = hasPlayback || started
                if !started { sessionReady = false; playbackIssue = "Audio playback could not start." }
            }
        }
        else if player.isPlaying { player.pause() }
    }
    @discardableResult
    private func effect(_ name: String, enabled: Bool, volume: Float, pan: Float = 0) -> Bool {
        guard enabled, master > 0 else { return false }
        guard let pool = effects[name], !pool.isEmpty else { playbackIssue = "Missing sound: " + name; return false }
        guard activatePlayback() else { return false }
        let index = slots[name,default:0] % pool.count
        slots[name] = index+1
        let player = pool[index]
        player.currentTime = 0; player.pan = pan
        player.volume = volume*master*0.75
        player.rate = name.hasPrefix("laser") ? [0.98,1.015,1.0][index%3] : 1
        let started = player.play(); hasPlayback = hasPlayback || started
        if !started { sessionReady = false; playbackIssue = "Audio playback could not start." }
        return started
    }
    func impact(enabled: Bool) {
        suspend()
        effect("impact",enabled:enabled,volume:0.65)
#if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
#endif
    }
    func shieldHit(enabled: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now-lastShieldTime > 0.12 else { return }
        lastShieldTime = now
        effect("shield",enabled:enabled,volume:0.3)
    }
    func debris(enabled: Bool) { effect("impact",enabled:enabled,volume:0.22) }
    func checkpoint(enabled: Bool) {
        effect("checkpoint",enabled:enabled,volume:0.28)
#if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
    }
    func laser(enabled: Bool, aircraft: AircraftType = .xwing, enemy: Bool = false) {
        let profile = EngineProfile.profile(for:aircraft)
        let name = enemy || profile == .ion ? "laser_ion" : aircraft.weaponPower >= 24 ? "laser_heavy" : "laser"
        effect(name,enabled:enabled,volume:enemy ? 0.13:0.27,pan:enemy ? -0.15:0.06)
    }
    func hyperspace(enabled: Bool) { effect("hyperspace",enabled:enabled,volume:0.42) }
    func arrival(enabled: Bool) { effect("arrival",enabled:enabled,volume:0.32) }
    func droid(enabled: Bool) { effect("droid",enabled:enabled,volume:0.28) }
}
