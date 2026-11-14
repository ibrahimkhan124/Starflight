import Foundation
import simd

/// Fixed locations shared by terrain, navigation, activities, and scenery.
enum FreeRoamSector: String, CaseIterable, Identifiable {
    case explore, portals, landing, missions
    var id: String { rawValue }
    var name: String {
        switch self {
        case .explore: return "Open skies"
        case .portals: return "Hyperspace port"
        case .landing: return "Landing academy"
        case .missions: return "Mission outpost"
        }
    }
    var center: SIMD3<Float> {
        switch self {
        case .explore: return [-1500, 480, 1500]
        case .portals: return [-1500, 580, -1500]
        case .landing: return [1500, 210, 1500]
        case .missions: return [1500, 210, -1500]
        }
    }
    static func containing(_ position: SIMD3<Float>) -> Self {
        position.x < 0 ? (position.z < 0 ? .portals : .explore) : (position.z < 0 ? .missions : .landing)
    }
}

enum FreeRoamMission: String, CaseIterable, Identifiable {
    case survey, delivery, patrol
    var id: String { rawValue }
    var name: String { self == .survey ? "Ridge survey" : self == .delivery ? "Supply delivery" : "Fighter interception" }
    var waypoints: [SIMD3<Float>] {
        if self == .patrol { return [] }
        return self == .survey ? [[2200, 650, -2000], [2800, 850, -800], [2200, 650, 500]] :
            [[900, 600, -900], [600, 600, 300], [1500, 530, 1500]]
    }
}

enum LandingResult: Equatable { case none, landed, hardImpact }

struct FreeRoamActivities {
    static let padHeight: Float = 210
    static let padHalfWidth: Float = 220
    static let padHalfLength: Float = 850
    static let pads = [FreeRoamSector.landing.center, FreeRoamSector.missions.center]
    private(set) var destination: FreeRoamSector = .explore
    private(set) var mission: FreeRoamMission?
    private(set) var waypointIndex = 0
    private(set) var missionComplete = false
    private(set) var completedMissions = 0
    private(set) var landings = 0
    private(set) var landed = false
    private(set) var enemies: [MissionFighter] = []
    private(set) var enemyBolts: [TurretBolt] = []
    private(set) var fightersDestroyed = 0
    private var combatTime: Float = 0
    var approachAssist = false
    private(set) var status = "Choose a sector to explore. Start at the central rendezvous."

    mutating func navigate(to sector: FreeRoamSector) { destination = sector }
    mutating func transfer(to sector: FreeRoamSector, state: inout FlightState, terrain: TerrainGenerator, aircraft: AircraftType) -> Float {
        cancelMission()
        destination = sector; landed = false
        state.pitch = 0; state.roll = 0; state.heading = 0; state.stalled = false
        state.position = sector.center
        approachAssist = sector == .landing
        if sector == .landing {
            state.position.z += 1150
            state.position.y = Self.padHeight + 85
            state.velocity = [0, 0, -18]; state.airspeed = 18
        } else {
            state.position.y = max(sector.center.y, terrain.surfaceHeight(x: state.position.x, z: state.position.z) + 400)
            state.velocity = state.forward * aircraft.cruiseSpeed; state.airspeed = aircraft.cruiseSpeed
        }
        status = sector == .landing ? "Aligned with the long runway. Approach assist is on: lower throttle and descend gently." : "Arrived at \(sector.name)."
        return approachAssist ? 0.28 : 0.65
    }
    /// Rectangular clearings include both runway ends and a long, obstacle-free approach.
    static func clearingDistance(x: Float, z: Float) -> Float {
        pads.map { pad in
            simd_length(SIMD2<Float>(max(0, abs(x - pad.x) - 420), max(0, abs(z - pad.z) - 1600)))
        }.min() ?? 10000
    }
    func nearPad(_ position: SIMD3<Float>, radius: Float = 900) -> Bool {
        Self.pads.contains {
            abs($0.x - position.x) < Self.padHalfWidth + radius && abs($0.z - position.z) < Self.padHalfLength + radius
        }
    }
    func canStartMission(at position: SIMD3<Float>) -> Bool {
        simd_length(SIMD2<Float>(position.x - 1500, position.z + 1500)) < 900 && mission == nil
    }
    @discardableResult
    mutating func start(_ choice: FreeRoamMission, at position: SIMD3<Float>) -> Bool {
        guard canStartMission(at: position) else { return false }
        mission = choice; waypointIndex = 0; missionComplete = false
        status = "\(choice.name): fly within 180 m of each beacon."
        if choice == .patrol {
            combatTime = 0; fightersDestroyed = 0; enemyBolts = []
            enemies = (0..<3).map { MissionFighter(id: $0, position: stateSafeFighterPosition(index: $0) + SIMD3<Float>(sin(Float($0)) * 190, 0, 160)) }
            status = "Intercept three fighters. Follow the target bearing and fire; stronger guns do more damage."
        }
        return true
    }
    mutating func cancelMission() {
        mission = nil; waypointIndex = 0; missionComplete = false
        enemies = []; enemyBolts = []; fightersDestroyed = 0
        status = "Mission cancelled. Explore freely."
    }
    var missionTarget: SIMD3<Float>? {
        guard let mission, waypointIndex < mission.waypoints.count else { return nil }
        return mission.waypoints[waypointIndex]
    }
    var target: SIMD3<Float> {
        enemies.first?.position ?? missionTarget ?? (mission == .delivery ? FreeRoamSector.landing.center : destination.center)
    }
    var targetName: String {
        if mission == .patrol { return "Fighters down \(fightersDestroyed)/3" }
        if let mission {
            return missionTarget == nil ? "Supply delivery · land at academy" : "\(mission.name) · beacon \(waypointIndex + 1)/3"
        }
        return destination.name
    }
    mutating func advanceMission(from old: SIMD3<Float>, to new: SIMD3<Float>) -> Bool {
        guard let target = missionTarget else { return false }
        let segment = new - old
        let t = clamp(simd_dot(target - old, segment) / max(simd_length_squared(segment), 0.001), 0, 1)
        guard simd_distance(old + segment * t, target) < 180 else { return false }
        waypointIndex += 1
        if waypointIndex == 3 {
            if mission == .survey {
                completeMission()
            } else {
                destination = .landing
                status = "Beacons complete. Deliver supplies with a safe academy landing."
            }
        } else { status = "Beacon \(waypointIndex)/3 reached. Follow the next beacon." }
        return true
    }
    private mutating func completeMission() {
        completedMissions += 1; missionComplete = true; mission = nil
        status = "Mission complete! Return to the outpost for another assignment."
    }

    /// An explicit assist for sci-fi ships: throttle controls forward speed, pitch controls descent.
    mutating func advanceApproach(_ state: inout FlightState, input: FlightInput, dt: Float) {
        guard !landed else { state.velocity = .zero; state.airspeed = 0; return }
        state.heading += (input.roll * 0.65 + input.yaw * 0.5) * dt
        let response = 1 - exp(-dt * 4)
        state.pitch += (input.pitch * 0.12 - state.pitch) * response
        state.roll += (input.roll * 0.18 - state.roll) * response
        let direction = SIMD3<Float>(sin(state.heading), 0, -cos(state.heading))
        let desired = direction * (input.throttle * 65) + SIMD3<Float>(0, input.pitch * 12, 0)
        state.velocity += (desired - state.velocity) * response
        state.position += state.velocity * dt
        state.airspeed = simd_length(state.velocity); state.stalled = false
    }

    mutating func contact(from old: FlightState, to state: inout FlightState, bodyRadius: Float, probes: [SIMD3<Float>] = []) -> LandingResult {
        guard !landed else { return .none }
        let lowest = probes.map { state.orientation.act($0).y }.min() ?? -bodyRadius
        let y = Self.padHeight + max(bodyRadius, -lowest) + 2
        guard state.position.y <= y, old.position.y >= y else { return .none }
        let t = clamp((old.position.y - y) / max(old.position.y - state.position.y, 0.001), 0, 1)
        let hit = old.position + (state.position - old.position) * t
        guard let pad = Self.pads.first(where: {
            abs(hit.x - $0.x) < Self.padHalfWidth - bodyRadius && abs(hit.z - $0.z) < Self.padHalfLength - bodyRadius
        }) else { return .none }
        let horizontal = simd_length(SIMD2<Float>(state.velocity.x, state.velocity.z))
        guard horizontal <= 22, state.velocity.y >= -6, abs(state.roll) < 0.2, abs(state.pitch) < 0.2 else { return .hardImpact }
        state.position = [hit.x, y, hit.z]; state.velocity = .zero; state.airspeed = 0
        state.pitch = 0; state.roll = 0; state.stalled = false
        landed = true; landings += 1; approachAssist = true
        status = "Safe landing! Choose Take off when you're ready."
        if mission == .delivery, waypointIndex == 3, pad.z > 0 { completeMission() }
        return .landed
    }
    private func stateSafeFighterPosition(index: Int) -> SIMD3<Float> {
        [1500 + Float(index - 1) * 220, 750 + Float(index) * 40, -2150 - Float(index) * 250]
    }
    /// Swept projectile checks respect each aircraft's weapon damage and prevent fast bolts tunnelling.
    mutating func advanceCombat(ship: FlightState, bolts: [PlayerBolt], dt: Float) -> (consumed: Set<Int>, damage: Float, completed: Bool) {
        guard mission == .patrol else { return ([], 0, false) }
        combatTime += dt
        var consumed = Set<Int>()
        var damage: Float = 0
        for index in enemies.indices {
            let old = enemies[index].position
            let base = stateSafeFighterPosition(index: enemies[index].id)
            enemies[index].position = base + [sin(combatTime * 0.23 + Float(enemies[index].id)) * 190, sin(combatTime * 0.31) * 35, cos(combatTime * 0.23) * 160]
            enemies[index].velocity = (enemies[index].position - old) / max(dt, 0.001)
            for boltIndex in bolts.indices where !consumed.contains(boltIndex) {
                let bolt = bolts[boltIndex]
                let from = bolt.position - bolt.velocity * dt
                let segment = bolt.position - from
                let t = clamp(simd_dot(enemies[index].position - from, segment) / max(simd_length_squared(segment), 0.001), 0, 1)
                if simd_distance(from + segment * t, enemies[index].position) < 24 {
                    enemies[index].health -= bolt.damage; consumed.insert(boltIndex)
                }
            }
            enemies[index].fireCooldown -= dt
            let delta = ship.position - enemies[index].position
            if enemies[index].fireCooldown <= 0, simd_length(delta) > 100, simd_length(delta) < 1200, enemyBolts.count < 12 {
                enemyBolts.append(TurretBolt(position: enemies[index].position, velocity: simd_normalize(delta) * 135, fromPursuer: true))
                enemies[index].fireCooldown = 4.5
            }
        }
        let destroyed = enemies.filter { $0.health <= 0 }.count
        enemies.removeAll { $0.health <= 0 }; fightersDestroyed += destroyed
        for index in enemyBolts.indices {
            let old = enemyBolts[index].position
            enemyBolts[index].position += enemyBolts[index].velocity * dt
            enemyBolts[index].age += dt
            let segment = enemyBolts[index].position - old
            let t = clamp(simd_dot(ship.position - old, segment) / max(simd_length_squared(segment), 0.001), 0, 1)
            if simd_distance(old + segment * t, ship.position) < 8 { damage += 4; enemyBolts[index].age = 10 }
        }
        enemyBolts.removeAll { $0.age > 7 }
        let completed = enemies.isEmpty
        if completed { enemyBolts = []; completeMission() }
        return (consumed, damage, completed)
    }

    mutating func takeOff(_ state: inout FlightState, cruiseSpeed: Float) {
        guard landed else { return }
        landed = false; approachAssist = false
        state.position.y += 90; state.pitch = 0.08; state.roll = 0
        state.velocity = state.forward * cruiseSpeed; state.airspeed = cruiseSpeed
        status = "Cleared for takeoff. Choose your next sector."
    }
}

struct MissionFighter: Identifiable {
    let id: Int
    var position: SIMD3<Float>
    var velocity = SIMD3<Float>.zero
    var health: Float = 24
    var fireCooldown: Float = 4.5
}
