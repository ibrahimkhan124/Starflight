import Foundation
import simd

struct RaceBoostPad: Identifiable {
    let id: Int
    let position: SIMD3<Float>
    let radius: Float
}

struct RaceOpponent: Identifiable {
    let id: Int
    var position: SIMD3<Float>
    let cruiseSpeed: Float
    let finishDistance: Float
    let lane: Float
    var speed: Float
    var desiredSpeed: Float
    var desiredOffset: Float
    var lateralVelocity: Float = 0
    var progress: Float = 0
    var lateralOffset: Float = 0
    var heading: Float = 0
    var active = true
    var armour: Float = 56
    var boostTime: Float = 0
    var boostCooldown: Float = 0
    var attackTime: Float = 0
    var attackCooldown: Float = 0
    var attackSide: Float = 1
    var contactCooldown: Float = 0
    var steeringStagger: Float = 0
    var boosting: Bool { boostTime > 0 }
    var finished: Bool { progress >= finishDistance }
}

/// Six rivals use bounded steering and timed attacks, rather than teleporting between lanes.
struct PodRaceManager {
    static let rivalTypes: [AircraftType] = [.anakinPodracer, .sebulbaPodracer, .quadinPodracer,
                                            .rattsPodracer, .nevaKeePodracer, .voltwingPodracer]
    let terrain: TerrainGenerator
    let circuit: RaceCircuit
    let pads: [RaceBoostPad]
    private(set) var collectedPads: Set<Int> = []
    private(set) var boostCharge: Float = 100
    private(set) var isBoosting = false
    private(set) var opponents: [RaceOpponent]
    private(set) var skidIntensity: Float = 0
    private(set) var collisionShake: Float = 0
    private(set) var contacts = 0
    private(set) var draftStrength: Float = 0
    private var clock: Float = 0
    private var decisionClock: Float = 0
    private var playerRecovery: Float = 0
    private var packRecovery: Float = 0
    private var draftTarget: Float = 0

    init(terrain: TerrainGenerator, aircraft: AircraftType) {
        self.terrain = terrain
        let circuit = RaceCircuit(level: terrain.level)
        self.circuit = circuit
        var routePads = terrain.level.boostPadDepths.enumerated().map { index, depth in
            RaceBoostPad(id: index, position: circuit.point(at: depth / terrain.level.routeLength * circuit.length), radius: 78)
        }
        if terrain.level.isPodRace && circuit.hasShortcut {
            let firstID = routePads.count
            routePads += [0.35, 0.7].enumerated().map { index, fraction in
                RaceBoostPad(id: firstID + index, position: circuit.shortcutPoint(Float(fraction)), radius: 35)
            }
        }
        pads = routePads
        opponents = terrain.level.isPodRace ? Self.rivalTypes.indices.map { index in
            let lane: Float = index.isMultiple(of: 2) ? -1 : 1
            let progress = Float(72 + index * 48)
            let t = circuit.tangent(at: progress)
            let offset = lane * Float(44 + (index / 2) * 15)
            let racePace: Float = aircraft.isPodracer ? 1.34 * terrain.level.podRaceSpeedMultiplier : 1
            let speed = aircraft.cruiseSpeed * racePace
                * (0.96 + Float(index) * 0.018 + terrain.level.podRaceDifficulty * 0.025)
            var position = circuit.point(at: progress) + SIMD3<Float>(-t.z, 0, t.x) * offset
            position.y = terrain.surfaceHeight(x:position.x,z:position.z) + TerrainGenerator.podGroundClearance
            return RaceOpponent(id: index,
                position: position,
                cruiseSpeed: speed, finishDistance: circuit.length * 3, lane: lane, speed: speed, desiredSpeed: speed, desiredOffset: offset,
                progress: progress, lateralOffset: offset, heading: atan2(t.x, -t.z),
                boostCooldown: 0.45 + Float(index) * 0.32, attackCooldown: Float(index) * 0.15)
        } : []
    }

    func position(for player: SIMD3<Float>, passed: Int) -> Int {
        guard terrain.level.isPodRace else { return 1 }
        let lap = passed / max(1, terrain.level.gateCount)
        if passed >= terrain.level.totalCheckpoints {
            return 1 + opponents.filter { $0.active && $0.progress >= circuit.length * 3 }.count
        }
        let progress = Float(lap) * circuit.length + circuit.projection(player).distance
        return 1 + opponents.filter { $0.active && $0.progress > progress }.count
    }

    /// Reuse the warning space on the HUD; do not add another phone panel.
    func proximityWarning(for player: FlightState) -> String? {
        if collisionShake > 0.45 { return "POD CONTACT · COUNTERSTEER" }
        let forward = SIMD3<Float>(sin(player.heading), 0, -cos(player.heading))
        let right = SIMD3<Float>(cos(player.heading), 0, sin(player.heading))
        for rival in opponents where rival.active && rival.progress < circuit.length * 3 {
            let delta = rival.position - player.position
            let lateral = simd_dot(delta, right), ahead = simd_dot(delta, forward)
            if abs(lateral) < 85 && abs(ahead) < 95 && abs(delta.y) < 20 {
                return lateral < 0 ? "RIVAL LEFT · HOLD YOUR LINE" : "RIVAL RIGHT · HOLD YOUR LINE"
            }
        }
        if circuit.hasShortcut && simd_distance(player.position, circuit.shortcutPoint(0)) < 450 {
            return "CYAN ARCHES · NARROW SHORTCUT / MAIN TRACK WIDE"
        }
        if draftStrength > 0.55 { return "SLIPSTREAM · PULL OUT TO PASS" }
        let progress = circuit.projection(player.position).distance
        let bend = acos(clamp(simd_dot(circuit.tangent(at:progress),circuit.tangent(at:progress+max(160,player.airspeed*0.3))),-1,1))
        if bend > 0.5 { return "TIGHT BEND AHEAD · LIFT THROTTLE / SKID" }
        return nil
    }

    mutating func reset(aircraft: AircraftType) { self = PodRaceManager(terrain: terrain, aircraft: aircraft) }

    mutating func advance(position: SIMD3<Float>, requestedBoost: Bool, dt: Float) -> Bool {
        guard terrain.level.isPodRace, dt > 0 else { return false }
        clock += dt
        decisionClock -= dt
        playerRecovery = max(0, playerRecovery - dt)
        packRecovery = max(0, packRecovery - dt)
        for pad in pads where !collectedPads.contains(pad.id) {
            let delta = position - pad.position
            if simd_length(SIMD2<Float>(delta.x, delta.z)) < pad.radius && abs(delta.y) < 105 {
                collectedPads.insert(pad.id)
                boostCharge = min(100, boostCharge + 28)
            }
        }
        // Expensive curve/traffic decisions run at 10 Hz, movement at the fixed physics rate.
        let decide = decisionClock <= 0
        if decide { decisionClock += 0.1 }
        // The visible shoulder climbs into a hovering pod around 45% of the valley width.
        // Steering stays inside it, but a deliberate shove can carry a rival over the edge.
        let edge = terrain.level.valleyWidth * 0.44
        if decide {
            draftTarget = 0
            for rival in opponents where rival.active && !rival.finished {
                // Slipstream follows the rival's wake, including while it changes lanes.
                let tangent = circuit.tangent(at: rival.progress)
                let right = SIMD3<Float>(-tangent.z, 0, tangent.x)
                let delta = rival.position - position
                let ahead = simd_dot(delta, tangent), across = abs(simd_dot(delta, right))
                if ahead > 25 && ahead < 260 && across < 38 && abs(delta.y) < 20 {
                    let alignment = 1 - across / 38
                    let distance = min(1, (260 - ahead) / 100)
                    draftTarget = max(draftTarget, alignment * distance)
                }
            }
        }
        draftStrength += (draftTarget - draftStrength) * (1 - exp(-dt * (draftTarget > draftStrength ? 2.8 : 6)))
        for index in opponents.indices where opponents[index].active {
            if opponents[index].progress >= circuit.length * 3 { continue }
            opponents[index].contactCooldown = max(0, opponents[index].contactCooldown - dt)
            opponents[index].boostCooldown -= dt
            opponents[index].boostTime = max(0, opponents[index].boostTime - dt)
            opponents[index].attackCooldown -= dt
            opponents[index].attackTime = max(0, opponents[index].attackTime - dt)
            opponents[index].steeringStagger = max(0, opponents[index].steeringStagger - dt)
            if decide {
                let rival = opponents[index]
                let t = circuit.tangent(at: rival.progress)
                let right = SIMD3<Float>(-t.z, 0, t.x)
                let delta = position - rival.position
                let ahead = simd_dot(delta, t)
                let playerOffset = rival.lateralOffset + simd_dot(delta, right)
                let bend = acos(clamp(simd_dot(t, circuit.tangent(at: rival.progress + max(140, rival.speed * 0.35))), -1, 1))
                let cornerFactor = max(0.86, 1 - bend * 0.24)
                if rival.boostCooldown <= 0 && bend < 0.22 && rival.steeringStagger <= 0 {
                    opponents[index].boostTime = 1.4 + terrain.level.podRaceDifficulty * 0.45
                    opponents[index].boostCooldown = 3.7 + Float(index) * 0.18 - terrain.level.podRaceDifficulty * 0.8
                }
                let chase: Float = ahead > 100 && ahead < 650 && abs(delta.y) < 20 ? 1.08 : 1
                opponents[index].desiredSpeed = rival.cruiseSpeed * cornerFactor * (opponents[index].boosting ? 1.38 : chase)
                if rival.steeringStagger <= 0 {
                    var lane = rival.lane * (44 + Float(index / 2) * 15) + sin(clock * 1.1 + Float(index)) * 16
                    // Commit to a side-swipe only when already alongside. Attacks have a recovery window.
                    if rival.attackTime > 0 {
                        lane = playerOffset + rival.attackSide * 10
                    } else if abs(ahead) < 100 && abs(delta.y) < 20 && abs(playerOffset - rival.lateralOffset) < 120 && rival.attackCooldown <= 0 {
                        let side: Float = rival.lateralOffset < playerOffset ? -1 : 1
                        lane = playerOffset + side * 10
                        opponents[index].attackSide = side
                        opponents[index].attackTime = 0.8
                        opponents[index].attackCooldown = 2.6 - terrain.level.podRaceDifficulty * 0.6 + Float(index) * 0.08
                    } else if ahead > 65 && ahead < 360 && abs(delta.y) < 20 {
                        lane = playerOffset + rival.lane * 50 // Pull alongside first, then attack from the side.
                    } else if ahead < -55 && ahead > -240 && index.isMultiple(of: 2) {
                        lane = playerOffset + rival.lane * 16
                    }
                    // Give other rivals enough space to race two abreast.
                    for other in opponents where other.id != rival.id && other.active {
                        let gap = other.progress - rival.progress
                        if gap > 0 && gap < 70 && abs(other.lateralOffset - lane) < 28 {
                            lane += rival.lane * 34
                        }
                    }
                    opponents[index].desiredOffset = clamp(lane, -edge * 0.72, edge * 0.72)
                }
            }
            if opponents[index].steeringStagger > 0 {
                // Preserve contact momentum long enough to countersteer or knock a pod off track.
                opponents[index].lateralVelocity *= exp(-dt * 0.85)
            } else {
                let targetLateralSpeed = clamp((opponents[index].desiredOffset - opponents[index].lateralOffset) * 3.4, -145, 145)
                opponents[index].lateralVelocity += (targetLateralSpeed - opponents[index].lateralVelocity) * (1 - exp(-dt * 5.5))
            }
            opponents[index].lateralOffset += opponents[index].lateralVelocity * dt
            opponents[index].speed += (opponents[index].desiredSpeed - opponents[index].speed) * (1 - exp(-dt * 2))
            opponents[index].progress = min(circuit.length * 3, opponents[index].progress + opponents[index].speed * dt)
            let t = circuit.tangent(at: opponents[index].progress)
            opponents[index].heading = atan2(t.x, -t.z) + atan2(opponents[index].lateralVelocity, max(1, opponents[index].speed))
            opponents[index].position = circuit.point(at: opponents[index].progress) + SIMD3<Float>(-t.z, 0, t.x) * opponents[index].lateralOffset
            opponents[index].position.y = terrain.surfaceHeight(x:opponents[index].position.x,z:opponents[index].position.z) + TerrainGenerator.podGroundClearance
            if abs(opponents[index].lateralOffset) > edge { opponents[index].active = false }
        }
        if packRecovery <= 0 {
            for i in opponents.indices where opponents[i].active {
                for j in opponents.indices where j > i && opponents[j].active {
                    if abs(opponents[i].progress - opponents[j].progress) < 35 && abs(opponents[i].lateralOffset - opponents[j].lateralOffset) < 28 {
                        let side: Float = opponents[i].lateralOffset <= opponents[j].lateralOffset ? -1 : 1
                        opponents[i].lateralVelocity = side * 62
                        opponents[j].lateralVelocity = -side * 62
                        packRecovery = 0.4
                    }
                }
            }
        }
        isBoosting = requestedBoost && (isBoosting ? boostCharge > 0 : boostCharge >= 15)
        boostCharge = clamp(boostCharge + (isBoosting ? -28 : 5) * dt, 0, 100)
        return isBoosting
    }

    /// Swept, consumed shots prevent a single bolt damaging a rival on every simulation step.
    mutating func resolvePlayerFire(_ bolts: [PlayerBolt], dt: Float) -> Set<Int> {
        var consumed: Set<Int> = []
        for (boltIndex, bolt) in bolts.enumerated() {
            let old = bolt.position - bolt.velocity * dt
            let segment = bolt.position - old
            let squared = simd_length_squared(segment)
            var closest: (index: Int, fraction: Float)?
            for index in opponents.indices where opponents[index].active && opponents[index].progress < circuit.length * 3 {
                let t = squared > 0 ? clamp(simd_dot(opponents[index].position - old, segment) / squared, 0, 1) : 0
                if simd_distance(old + segment * t, opponents[index].position) < 22,
                   closest == nil || t < closest!.fraction { closest = (index, t) }
            }
            if let hit = closest {
                consumed.insert(boltIndex)
                opponents[hit.index].armour = max(0, opponents[hit.index].armour - bolt.damage)
                opponents[hit.index].speed *= 0.96
                if opponents[hit.index].armour <= 0 {
                    opponents[hit.index].active = false
                    boostCharge = min(100, boostCharge + 12)
                }
            }
        }
        return consumed
    }

    mutating func rewardGate() { boostCharge = min(100, boostCharge + 14) }
    mutating func beginLap() { collectedPads.removeAll() }

    /// One bounded impact, followed by a brief recovery; no repeated 120 Hz pinball impulses.
    mutating func resolveContact(player: inout FlightState, skidding: Bool = false, dt: Float) {
        skidIntensity = skidding ? 1 : max(0, skidIntensity - dt * 1.8)
        collisionShake = max(0, collisionShake - dt * 2.5)
        guard terrain.level.isPodRaceTrack, playerRecovery <= 0 else { return }
        let right = SIMD3<Float>(cos(player.heading), 0, sin(player.heading))
        let forward = SIMD3<Float>(sin(player.heading), 0, -cos(player.heading))
        for index in opponents.indices where opponents[index].active && opponents[index].progress < circuit.length * 3 {
            let delta = opponents[index].position - player.position
            let lateral = simd_dot(delta, right)
            guard abs(lateral) < 34, abs(simd_dot(delta, forward)) < 42,
                  abs(delta.y) < 18, opponents[index].contactCooldown <= 0 else { continue }
            let side: Float = lateral >= 0 ? -1 : 1
            let impulse: Float = 50 + terrain.level.podRaceDifficulty * 14
            let counterShove: Float = skidding ? 145 : 115
            opponents[index].lateralVelocity = clamp(opponents[index].lateralVelocity - side * counterShove, -180, 180)
            opponents[index].steeringStagger = 0.72
            opponents[index].attackTime = 0
            opponents[index].contactCooldown = 0.9
            player.velocity += right * side * impulse
            player.velocity -= forward * max(0, simd_dot(player.velocity, forward)) * 0.02
            player.lateralDrift = clamp(player.lateralDrift + side * 50, -200, 200)
            player.airspeed *= 0.98
            player.position += right * side * min(9, (34 - abs(lateral)) * 0.3)
            playerRecovery = 0.4
            contacts += 1
            skidIntensity = 1
            collisionShake = 1
            break
        }
    }
}

