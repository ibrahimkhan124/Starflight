import Foundation
import simd

/// Lightweight flight-path replay. Hazards are frozen; playback never advances gameplay.
struct FlightPathSample: Codable, Equatable {
    var time: Float
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var pitch: Float
    var roll: Float
    var heading: Float
    var speed: Float
    init(time: Float, state: FlightState) {
        self.time = time; position = state.position; velocity = state.velocity
        pitch = state.pitch; roll = state.roll; heading = state.heading; speed = state.airspeed
    }
    var state: FlightState {
        var s = FlightState(); s.position = position; s.velocity = velocity
        s.pitch = pitch; s.roll = roll; s.heading = heading; s.airspeed = speed; return s
    }
    var valid: Bool {
        [time, position.x,position.y,position.z,velocity.x,velocity.y,velocity.z,pitch,roll,heading,speed].allSatisfy(\.isFinite)
            && time >= 0 && speed >= 0 && simd_length(position) < 10_000_000
    }
    static func interpolated(_ samples: [Self], at time: Float) -> FlightState? {
        guard let first = samples.first, let last = samples.last else { return nil }
        if time <= first.time { return first.state }; if time >= last.time { return last.state }
        // Binary search keeps a long best-lap ghost cheap on older devices.
        var lo = 0, hi = samples.count - 1
        while hi-lo > 1 { let mid = (lo+hi)/2; if samples[mid].time <= time { lo = mid } else { hi = mid } }
        let a = samples[lo], b = samples[hi]
        let t = clamp((time-a.time)/max(0.001,b.time-a.time),0,1)
        var state = b.state
        state.position = simd_mix(a.position,b.position,SIMD3<Float>(repeating:t))
        state.velocity = simd_mix(a.velocity,b.velocity,SIMD3<Float>(repeating:t))
        func angle(_ x:Float,_ y:Float) -> Float { x+atan2(sin(y-x),cos(y-x))*t }
        state.pitch = angle(a.pitch,b.pitch); state.roll = angle(a.roll,b.roll); state.heading = angle(a.heading,b.heading)
        state.airspeed = a.speed+(b.speed-a.speed)*t
        return state
    }
}

struct FlightReplayBuffer {
    private(set) var samples: [FlightPathSample] = []
    private(set) var context = ""
    mutating func record(_ state: FlightState, time: Float, context: String) {
        if self.context != context || time < (samples.last?.time ?? 0) { samples = []; self.context = context }
        if let last = samples.last, simd_distance(last.position,state.position) > max(600,state.airspeed*0.5) { samples = [] }
        guard samples.isEmpty || time - samples.last!.time >= 0.099 else { return }
        samples.append(.init(time:time,state:state))
        while samples.count > 151 || (samples.first?.time ?? time) < time-15 { samples.removeFirst() }
    }
    mutating func reset() { samples = []; context = "" }
    var duration: Float { max(0,(samples.last?.time ?? 0)-(samples.first?.time ?? 0)) }
    func state(at fraction: Float) -> FlightState? {
        FlightPathSample.interpolated(samples,at:(samples.first?.time ?? 0)+clamp(fraction,0,1)*duration)
    }
}

enum FlightWeather: String, CaseIterable, Codable, Identifiable {
    case clear, dust, whiteout, rain, mist
    var id: String { rawValue }
    var title: String { switch self { case .clear: return "Clear skies"; case .dust: return "Dust storm"; case .whiteout: return "Snow squall"; case .rain: return "Neon rain"; case .mist: return "Drifting mist" } }
    var briefing: String {
        switch self {
        case .clear: return "Good visibility. Normal wind."
        case .dust: return "Amber dust and gusting crosswinds. Leave more room around obstacles."
        case .whiteout: return "Blowing snow and strong crosswinds. Use ground clearance and your map."
        case .rain: return "Rain streaks, blue haze, rain patter and distant thunder. Watch your approach speed."
        case .mist: return "Soft drifting cloud and light wind. Use ground clearance when distant terrain disappears."
        }
    }
    func wind(at time: Float) -> SIMD3<Float> {
        let strength: Float = self == .clear ? 0 : self == .mist ? 3 : self == .whiteout ? 16 : self == .dust ? 12 : 8
        return SIMD3<Float>(sin(time*0.63)*strength, sin(time*0.37)*strength*0.12, cos(time*0.41)*strength*0.4)
    }
}

enum PilotCareerPath: String, CaseIterable, Codable, Identifiable {
    case courier, passenger, explorer, bounty
    var id: String { rawValue }
    var title: String { switch self { case .courier: return "Courier"; case .passenger: return "Passenger pilot"; case .explorer: return "Explorer"; case .bounty: return "Bounty hunter" } }
    var activity: String { switch self { case .courier: return "Complete deliveries or emergency contracts."; case .passenger: return "Complete shuttle and medical rescue jobs."; case .explorer: return "Discover new minerals or complete a planet's scout route."; case .bounty: return "Finish bounty contracts." } }
    static let milestones = [2,6,12]
    static func rank(_ count: Int) -> String { count >= 12 ? "Master" : count >= 6 ? "Veteran" : count >= 2 ? "Licensed" : "Trainee" }
}

struct SavedFlightRoute: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var planets: [String]
    var destinations: [SpacePlanet] { planets.compactMap(SpacePlanet.init(rawValue:)) }
    var valid: Bool { !name.isEmpty && name.count <= 40 && (1...8).contains(planets.count) && destinations.count == planets.count
        && zip(planets,planets.dropFirst()).allSatisfy { $0 != $1 } }
}

struct LapGhost: Codable, Equatable {
    var key: String
    var duration: Float
    var frames: [FlightPathSample]
    var valid: Bool {
        key.count <= 100 && duration.isFinite && duration > 0 && duration <= 1200
            && (2...12001).contains(frames.count) && frames.allSatisfy(\.valid)
            && frames.first!.time <= 0.1 && abs(frames.last!.time-duration) < 0.2
            && zip(frames,frames.dropFirst()).allSatisfy { $0.time < $1.time }
    }
    func state(at time: Float) -> FlightState? { guard time <= duration else { return nil }; return FlightPathSample.interpolated(frames,at:time) }
}

struct LapGhostRecorder {
    private(set) var frames: [FlightPathSample] = []
    private(set) var startedAt: Float = 0
    mutating func begin(state: FlightState, time: Float) { startedAt = time; frames = [.init(time:0,state:state)] }
    mutating func record(state: FlightState, time: Float) {
        let local = time-startedAt
        guard local >= 0, local <= 1200, frames.count < 12001, local-(frames.last?.time ?? -1) >= 0.099 else { return }
        frames.append(.init(time:local,state:state))
    }
    func finished(state: FlightState, time: Float, key: String) -> LapGhost? {
        let duration = time-startedAt
        var samples = frames.filter { $0.time < duration }
        samples.append(.init(time:duration,state:state))
        let ghost = LapGhost(key:key,duration:duration,frames:samples)
        return ghost.valid ? ghost : nil
    }
}

/// Stored inside the wallet, so mission receipts and rewards commit together and sync together.
struct FlightAdventureProgress: Codable, Equatable {
    var routes: [SavedFlightRoute] = []
    var career: [String:Int] = [:]
    var careerAwards: Set<String> = []
    var missionReceipts: Set<UUID> = []
    var scanned: Set<String> = []
    var bestLaps: [LapGhost] = []
    var visitedGalaxies:Set<String>?
    var visitedStars:Set<Int>?
    var valid: Bool {
        (visitedGalaxies ?? []).isSubset(of:Set(Galaxy.allCases.map(\.rawValue))) && (visitedStars ?? []).count <= 128 && (visitedStars ?? []).allSatisfy { (1...120500).contains($0) } && routes.count <= 8 && routes.allSatisfy(\.valid) && Set(routes.map(\.id)).count == routes.count
            && Set(career.keys).isSubset(of:Set(PilotCareerPath.allCases.map(\.rawValue)))
            && career.values.allSatisfy { (0...1_000_000).contains($0) }
            && scanned.isSubset(of:Set(TradeMineral.all.map(\.id))) && bestLaps.count <= 16 && bestLaps.allSatisfy(\.valid)
            && Set(bestLaps.map(\.key)).count == bestLaps.count && bestLaps.reduce(0,{ $0+$1.frames.count }) <= 24000
    }
    mutating func record(_ path: PilotCareerPath) -> Int {
        career[path.rawValue] = min(1_000_000,(career[path.rawValue] ?? 0)+1)
        var bonus = 0
        for (index,step) in PilotCareerPath.milestones.enumerated() where career[path.rawValue,default:0] >= step {
            if careerAwards.insert(path.rawValue+".\(step)").inserted { bonus += [100,250,500][index] }
        }
        return bonus
    }
    mutating func saveLap(_ ghost: LapGhost) -> Bool {
        guard ghost.valid else { return false }
        if let index = bestLaps.firstIndex(where:{$0.key == ghost.key}) {
            guard ghost.duration < bestLaps[index].duration else { return false }
            bestLaps[index] = ghost
        } else { bestLaps.append(ghost) }
        while bestLaps.count > 16 || bestLaps.reduce(0,{ $0+$1.frames.count }) > 24000 { bestLaps.removeFirst() }
        return true
    }
}

enum EmergencyContractKind: String, CaseIterable, Identifiable {
    case engine, leak, approach, rescue
    var id: String { rawValue }
    var title: String { switch self { case .engine: return "Engine trouble"; case .leak: return "Fuel-line leak"; case .approach: return "Precision repair approach"; case .rescue: return "Distress signal diversion" } }
    var reward: Int { switch self { case .engine: return 120; case .leak: return 180; case .approach: return 240; case .rescue: return 90 } }
    var requiredCompletions: Int { switch self { case .engine,.rescue: return 0; case .leak: return 2; case .approach: return 6 } }
    var briefing: String {
        switch self {
        case .engine: return "Reduced engine power. Reach the green repair platform within 150 seconds."
        case .leak: return "Fuel is leaking. Reach the repair platform within 120 seconds."
        case .approach: return "Reach the smaller repair platform within 90 seconds. Keep pitch and bank within 12° on touchdown."
        case .rescue: return "Optional trade-run diversion. Reach the green rescue platform and hold for three seconds. Your cargo route stays active."
        }
    }
}

struct EmergencyFlightContract {
    let id: UUID
    let kind: EmergencyContractKind
    let target: SIMD3<Float>
    private(set) var remaining: Float
    private(set) var serviceTime: Float = 0
    private(set) var completed = false
    var failed: Bool { remaining <= 0 && !completed }
    init(kind: EmergencyContractKind, target: SIMD3<Float>, id: UUID = UUID()) {
        self.id = id; self.kind = kind; self.target = target
        remaining = kind == .engine ? 150 : kind == .leak ? 120 : 90
    }
    mutating func advance(state: FlightState, dt: Float) -> Bool {
        guard !completed, !failed, dt.isFinite, dt > 0 else { return false }
        remaining = max(0,remaining-dt)
        let bank = abs(atan2(sin(state.roll),cos(state.roll)))
        let pitch = abs(asin(clamp(state.forward.y,-1,1)))
        let safe = simd_distance(state.position,target) < (kind == .approach ? 25 : 45)
            && state.airspeed < 12 && abs(state.velocity.y) < 3 && bank < 0.21 && pitch < 0.21
        serviceTime = safe ? serviceTime + dt : 0
        if serviceTime >= 3 && remaining > 0 { completed = true; return true }
        return false
    }
}
