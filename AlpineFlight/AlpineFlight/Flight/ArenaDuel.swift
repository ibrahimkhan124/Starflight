import Foundation
import simd

enum ArenaDifficulty: String, CaseIterable, Identifiable {
    case rookie = "Rookie", pilot = "Pilot", ace = "Ace"
    var id: String { rawValue }
    var aggression: Float { self == .rookie ? 0.7 : self == .pilot ? 1 : 1.3 }
}
enum ArenaFormat: String, CaseIterable, Identifiable {
    case duel = "Duel", trio = "Trio"
    var id: String { rawValue }
    func victoryReward(for difficulty: ArenaDifficulty) -> Int {
        switch (self,difficulty) {
        case (.duel,.rookie): return 350
        case (.duel,.pilot): return 700
        case (.duel,.ace): return 1400
        case (.trio,.rookie): return 950
        case (.trio,.pilot): return 1300
        case (.trio,.ace): return 2000
        }
    }
}

enum ArenaTactic: String { case attack = "Attack run", evade = "Evasive break", recover = "Shield recovery", regroup = "Turning inward" }
enum ArenaOutcome: String { case victory = "Duel won", defeat = "Duel lost", draw = "Duel drawn" }

struct ArenaSnapshot {
    var playerShield: Float = 100
    var enemyShield: Float = 100
    var countdown: Float = 3
    var remaining: Float = 150
    var tactic = ArenaTactic.attack
    var range: Float = 520
    var bearing: Float = 0
    var elevation: Float = 0
    var boundary = false
    var hits = 0
    var endedOnTime = false
    var rivals: [ArenaRivalStatus] = []
    var targetNumber = 1
    var outcome: ArenaOutcome?
}

/// Deterministic steering AI with bounded turn rate, telegraphed attacks and swept hits.
/// Only this simulation owns duel health/results; rendering never decides damage.
struct ArenaDuel {
    static let radius: Float = 1400
    let difficulty: ArenaDifficulty
    private let opponentOnly: Bool
    private(set) var enemyPosition = SIMD3<Float>(0, 0, -380)
    private(set) var enemyVelocity = SIMD3<Float>(0, 0, 75)
    private(set) var bolts: [TurretBolt] = []
    private(set) var snapshot = ArenaSnapshot()
    private var clock: Float = 0
    private var thinkAt: Float = 0
    private var maneuverUntil: Float = 0
    private var defendReadyAt: Float = 0
    private var fireAt: Float = 0.8
    private var playerHitAt: Float = -10
    private var enemyHitAt: Float = -10
    private var collisionReadyAt: Float = 0

    init(difficulty: ArenaDifficulty = .pilot, spawnOffset: SIMD3<Float> = .zero, opponentOnly: Bool = false) {
        self.difficulty = difficulty
        self.opponentOnly = opponentOnly
        enemyPosition += spawnOffset
        if opponentOnly { snapshot.countdown = 0 }
    }

    static func playerStart(speed: Float) -> FlightState {
        var state = FlightState()
        state.position = [0, 0, 140]; state.heading = 0; state.pitch = 0; state.roll = 0
        state.airspeed = min(150, max(65, speed)); state.velocity = state.forward * state.airspeed
        return state
    }

    struct Update { var consumed: Set<Int> = []; var fired = false; var damaged = false }
    mutating func advance(from old: FlightState, player: inout FlightState, shots: [PlayerBolt], dt: Float) -> Update {
        var result = Update()
        guard dt.isFinite, dt > 0, dt <= 0.1, snapshot.outcome == nil else { return result }
        if opponentOnly {
            guard snapshot.enemyShield > 0 else { bolts = []; return result }
            snapshot.playerShield = 100
        }
        if snapshot.countdown > 0 {
            snapshot.countdown = max(0, snapshot.countdown-dt)
            updateTarget(player)
            return result
        }
        clock += dt
        snapshot.remaining = max(0, 150-clock)
        let previousEnemy = enemyPosition
        if clock >= thinkAt {
            thinkAt = clock + 0.25
            let threatened = shots.contains { shot in
                let relative = shot.position-enemyPosition
                let motion = shot.velocity-enemyVelocity
                let t = clamp(-simd_dot(relative,motion)/max(simd_length_squared(motion),0.001),0,0.9)
                return simd_length(relative+motion*t) < 38 && simd_length(relative) < 330
            }
            if simd_length(enemyPosition) > Self.radius*0.8 {
                snapshot.tactic = .regroup; maneuverUntil = clock+1
            } else if clock >= maneuverUntil {
                if clock >= defendReadyAt && threatened {
                    snapshot.tactic = .evade; maneuverUntil = clock+0.9; defendReadyAt = clock+6
                } else if clock >= defendReadyAt && snapshot.enemyShield < 35 {
                    snapshot.tactic = .recover; maneuverUntil = clock+3.5; defendReadyAt = clock+10
                } else { snapshot.tactic = .attack }
            }
        }
        let toward = Self.unit(player.position-enemyPosition)
        let sideways = Self.unit(simd_cross(toward, SIMD3<Float>(0,1,0)), fallback: [1,0,0])
        var desired = toward
        switch snapshot.tactic {
        case .attack:
            desired = Self.unit(player.position + player.velocity*0.45-enemyPosition + sideways*sin(clock*0.7)*35)
            if simd_distance(player.position,enemyPosition) < 130 { desired = Self.unit(sideways-toward*0.4) }
        case .evade: desired = Self.unit(sideways*1.6 + SIMD3<Float>(0,sin(clock*2)*0.8,0) - toward*0.3)
        case .recover: desired = Self.unit(-toward+sideways*0.5-enemyPosition/Self.radius*0.8)
        case .regroup: desired = Self.unit(-enemyPosition)
        }
        // Rotate towards the desired heading at a finite angular speed, never snap.
        let direction = Self.unit(enemyVelocity)
        let angle = acos(clamp(simd_dot(direction,desired),-1,1))
        let rotation = simd_quatf(from:direction,to:desired)
        let fraction = min(1,dt*(0.65+difficulty.aggression*0.35)/max(angle,0.001))
        let newDirection = simd_slerp(simd_quatf(),rotation,fraction).act(direction)
        let speed = min(155,max(65,player.airspeed*(snapshot.tactic == .recover ? 1.1 : 0.8)))
        enemyVelocity = newDirection*speed
        enemyPosition += enemyVelocity*dt
        if simd_length(enemyPosition) > Self.radius { enemyPosition = Self.unit(enemyPosition)*Self.radius }
        let range = simd_distance(player.position,enemyPosition)
        if snapshot.tactic == .attack, clock >= fireAt, range > 65, range < 700,
           simd_dot(newDirection,toward) > 0.9, bolts.count < 14 {
            let lead = player.position + player.velocity*min(0.65,range/260)
            let spread = SIMD3<Float>(sin(clock*4),cos(clock*3),0)*(16/difficulty.aggression)
            let aim = Self.unit(lead+spread-enemyPosition)
            bolts.append(TurretBolt(position:enemyPosition+aim*18,velocity:aim*260,fromPursuer:true))
            fireAt = clock+1.3/difficulty.aggression; result.fired = true
        }
        for (index,shot) in shots.enumerated() {
            let start = shot.position-shot.velocity*min(dt,shot.age)
            if Self.separation(start-previousEnemy,shot.position-enemyPosition) < (difficulty == .ace ? 24 : 32) {
                snapshot.enemyShield = max(0,snapshot.enemyShield-clamp(shot.damage,5,40))
                enemyHitAt = clock; snapshot.hits += 1; result.consumed.insert(index)
            }
        }
        var remainingBolts: [TurretBolt] = []
        for var bolt in bolts {
            let start = bolt.position
            bolt.position += bolt.velocity*dt; bolt.age += dt
            if Self.separation(start-old.position,bolt.position-player.position) < 9 {
                snapshot.playerShield = max(0,snapshot.playerShield-7*difficulty.aggression)
                playerHitAt = clock; result.damaged = true
            } else if bolt.age < 4 { remainingBolts.append(bolt) }
        }
        bolts = remainingBolts
        if range < 24 && clock >= collisionReadyAt {
            let away = Self.unit(player.position-enemyPosition)
            player.position = enemyPosition+away*30
            snapshot.playerShield = max(0,snapshot.playerShield-5)
            snapshot.enemyShield = max(0,snapshot.enemyShield-5)
            collisionReadyAt = clock+1; playerHitAt = clock; enemyHitAt = clock; result.damaged = true
        }
        snapshot.boundary = simd_length(player.position) > Self.radius-180
        if simd_length(player.position) > Self.radius {
            let normal = Self.unit(player.position)
            player.position = normal*(Self.radius-5)
            if simd_dot(player.velocity,normal) > 0 {
                player.velocity -= 2*simd_dot(player.velocity,normal)*normal
                player.heading = atan2(player.velocity.x,-player.velocity.z)
                player.pitch = asin(clamp(Self.unit(player.velocity).y,-0.8,0.8)); player.roll = 0
            }
        }
        if !opponentOnly && clock-playerHitAt > 6 { snapshot.playerShield = min(100,snapshot.playerShield+1.5*dt) }
        if snapshot.tactic == .recover && clock-enemyHitAt > 2 { snapshot.enemyShield = min(100,snapshot.enemyShield+4*dt) }
        if !opponentOnly {
        if snapshot.playerShield <= 0 && snapshot.enemyShield <= 0 { snapshot.outcome = .draw }
        else if snapshot.enemyShield <= 0 { snapshot.outcome = .victory }
        else if snapshot.playerShield <= 0 { snapshot.outcome = .defeat }
        else if snapshot.remaining <= 0 {
            snapshot.endedOnTime = true
            snapshot.outcome = Self.timeLimitOutcome(playerShield:snapshot.playerShield,enemyShield:snapshot.enemyShield)
        }
        }
        if snapshot.outcome != nil || snapshot.enemyShield <= 0 { bolts = [] }
        updateTarget(player)
        return result
    }
    static func timeLimitOutcome(playerShield: Float, enemyShield: Float) -> ArenaOutcome {
        if playerShield > enemyShield { return .victory }
        if enemyShield > playerShield { return .defeat }
        return .draw
    }

    func aimPoint(from position: SIMD3<Float>, projectileSpeed: Float) -> SIMD3<Float> {
        enemyPosition + enemyVelocity * min(1.2,simd_distance(position,enemyPosition)/max(1,projectileSpeed))
    }

    private mutating func updateTarget(_ player: FlightState) {
        let delta = enemyPosition-player.position
        snapshot.range = simd_length(delta)
        var bearing = atan2(delta.x,-delta.z)-player.heading
        bearing = atan2(sin(bearing),cos(bearing))
        snapshot.bearing = bearing
        snapshot.elevation = atan2(delta.y,max(0.01,simd_length(SIMD2<Float>(delta.x,delta.z))))
    }
    private static func unit(_ vector: SIMD3<Float>, fallback: SIMD3<Float> = [0,0,-1]) -> SIMD3<Float> {
        simd_length_squared(vector) > 0.0001 ? simd_normalize(vector) : fallback
    }
    private static func separation(_ start: SIMD3<Float>, _ end: SIMD3<Float>) -> Float {
        let travel = end-start
        let t = clamp(-simd_dot(start,travel)/max(simd_length_squared(travel),0.0001),0,1)
        return simd_length(start+travel*t)
    }
}


struct ArenaRivalStatus: Identifiable {
    let id: Int
    let shield: Float
}

/// A single match clock and player shield pool coordinate one or two independent rivals.
/// Bolts are consumed once across all rivals; eliminated rivals stop attacking immediately.
struct ArenaBattle {
    let id = UUID()
    let format: ArenaFormat
    let difficulty: ArenaDifficulty
    private(set) var snapshot = ArenaSnapshot()
    private var opponents: [ArenaDuel]
    private var elapsed: Float = 0
    private var lastHit: Float = -10
    private var targetIndex = 0
    var enemyPosition: SIMD3<Float> { opponents[targetIndex].enemyPosition }
    var enemyVelocity: SIMD3<Float> { opponents[targetIndex].enemyVelocity }
    var bolts: [TurretBolt] { snapshot.outcome != nil ? [] : opponents.filter { $0.snapshot.enemyShield > 0 }.flatMap(\.bolts) }
    var pursuers: [Pursuer] {
        opponents.filter { $0.snapshot.enemyShield > 0 }.map {
            Pursuer(position:$0.enemyPosition,velocity:$0.enemyVelocity,fireCooldown:0,side:0)
        }
    }
    init(difficulty: ArenaDifficulty = .pilot, format: ArenaFormat = .duel) {
        self.difficulty = difficulty; self.format = format
        let offsets: [SIMD3<Float>] = format == .duel ? [.zero] : [[-190,35,0],[190,-35,-110]]
        opponents = offsets.map { ArenaDuel(difficulty:difficulty,spawnOffset:$0,opponentOnly:true) }
        snapshot.rivals = opponents.indices.map { ArenaRivalStatus(id:$0,shield:100) }
    }
    func aimPoint(from position: SIMD3<Float>, projectileSpeed: Float) -> SIMD3<Float> {
        opponents[targetIndex].aimPoint(from:position,projectileSpeed:projectileSpeed)
    }
    mutating func advance(from old: FlightState, player: inout FlightState, shots: [PlayerBolt], dt: Float) -> ArenaDuel.Update {
        var combined = ArenaDuel.Update()
        guard dt.isFinite, dt > 0, dt <= 0.1, snapshot.outcome == nil else { return combined }
        if snapshot.countdown > 0 {
            snapshot.countdown = max(0,snapshot.countdown-dt)
            updateTarget(player)
            return combined
        }
        elapsed += dt; snapshot.remaining = max(0,150-elapsed)
        for index in opponents.indices where opponents[index].snapshot.enemyShield > 0 {
            let available = shots.enumerated().filter { !combined.consumed.contains($0.offset) }
            let result = opponents[index].advance(from:old,player:&player,shots:available.map(\.element),dt:dt)
            combined.consumed.formUnion(result.consumed.map { available[$0].offset })
            combined.fired = combined.fired || result.fired
            combined.damaged = combined.damaged || result.damaged
            snapshot.playerShield = max(0,snapshot.playerShield-(100-opponents[index].snapshot.playerShield))
        }
        snapshot.hits = opponents.reduce(0) { $0+$1.snapshot.hits }
        if combined.damaged { lastHit = elapsed }
        if elapsed-lastHit > 6 && snapshot.playerShield > 0 { snapshot.playerShield = min(100,snapshot.playerShield+1.5*dt) }
        let highestRivalShield = opponents.map { $0.snapshot.enemyShield }.max() ?? 0
        if snapshot.playerShield <= 0 && highestRivalShield <= 0 { snapshot.outcome = .draw }
        else if highestRivalShield <= 0 { snapshot.outcome = .victory }
        else if snapshot.playerShield <= 0 { snapshot.outcome = .defeat }
        else if snapshot.remaining <= 0 {
            snapshot.endedOnTime = true
            snapshot.outcome = ArenaDuel.timeLimitOutcome(playerShield:snapshot.playerShield,enemyShield:highestRivalShield)
        }
        updateTarget(player)
        return combined
    }
    private mutating func updateTarget(_ player: FlightState) {
        let living = opponents.indices.filter { opponents[$0].snapshot.enemyShield > 0 }
        if let best = living.min(by: { score($0,player) < score($1,player) }) { targetIndex = best }
        let delta = enemyPosition-player.position
        snapshot.range = simd_length(delta)
        let bearing = atan2(delta.x,-delta.z)-player.heading
        snapshot.bearing = atan2(sin(bearing),cos(bearing))
        snapshot.elevation = atan2(delta.y,max(0.01,simd_length(SIMD2<Float>(delta.x,delta.z))))
        snapshot.enemyShield = opponents[targetIndex].snapshot.enemyShield
        snapshot.tactic = opponents[targetIndex].snapshot.tactic
        snapshot.targetNumber = targetIndex+1
        snapshot.boundary = simd_length(player.position) > ArenaDuel.radius-180
        snapshot.rivals = opponents.indices.map { ArenaRivalStatus(id:$0,shield:opponents[$0].snapshot.enemyShield) }
    }
    private func score(_ index: Int, _ player: FlightState) -> Float {
        let delta = opponents[index].enemyPosition-player.position
        let distance = simd_length(delta)
        let alignment = distance > 0.01 ? simd_dot(delta/distance,player.forward) : 1
        return distance+(1-alignment)*400
    }
}
