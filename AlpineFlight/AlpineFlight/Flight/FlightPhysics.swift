import Foundation
import simd

func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}

/// Session score rewards moving aircraft, never parked craft or hover pods.
struct LowFlightScore {
    private(set) var total: Float = 0
    var points: Int { Int(total) }
    mutating func advance(clearance: Float, speed: Float, eligible: Bool, dt: Float) {
        guard eligible, clearance.isFinite, speed.isFinite, dt.isFinite,
              clearance >= 8, clearance < 60, speed >= 45, dt > 0 else { return }
        total += (1 - clearance / 60) * 20 * min(dt, 0.1)
    }
}

struct FlightInput {
    var pitch: Float = 0
    var roll: Float = 0
    var yaw: Float = 0
    var throttle: Float = 0.65
    var boost = false
    var skid = false
}

enum FreeRoamZone: Equatable {
    case atmosphere
    case hyperspace
    case asteroidField
}

enum SpaceChallenge: Int, CaseIterable, Identifiable {
    case asteroidBelt
    case crystalNebula
    case cometStorm
    case shatteredMoon

    var id: Int { rawValue }
    var name: String {
        switch self {
        case .asteroidBelt: return "Asteroid Belt"
        case .crystalNebula: return "Crystal Nebula"
        case .cometStorm: return "Comet Storm"
        case .shatteredMoon: return "Shattered Moon"
        }
    }
    var asteroidCount: Int { 26 + rawValue * 5 }
    var speedMultiplier: Float { 1 + Float(rawValue) * 0.24 }
    var spread: Float { 900 - Float(rawValue) * 90 }
}

struct FreeRoamPortal: Identifiable {
    let id: Int
    let destination: SpaceChallenge
    let position: SIMD3<Float>
}

/// Compact, explorable worlds. Rendering and hull collision share this surface rule.
enum SpacePlanet: String, CaseIterable, Identifiable {
    case tatooine, hoth, endor, coruscant
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var position: SIMD3<Float> {
        switch self {
        case .tatooine: return [-1700, 650, -2900]
        case .hoth: return [1900, -450, -3300]
        case .endor: return [1100, 1200, 2800]
        case .coruscant: return [-2400, 400, 1900]
        }
    }
    var radius: Float {
        switch self { case .tatooine: return 380; case .hoth: return 300; case .endor: return 300; case .coruscant: return 450 }
    }
    var description: String {
        switch self {
        case .tatooine: return "Desert dunes and rocky ridges"
        case .hoth: return "Ice fields and frozen peaks"
        case .endor: return "Green hills and forest canopy"
        case .coruscant: return "City towers and dense districts"
        }
    }
    // Sampled at the same grid vertices by the renderer and the collision height query.
    static let latitudeSegments = 64
    static let longitudeSegments = 128
    func height(latitude: Int, longitude: Int) -> Float {
        let lat = Float(latitude) * .pi / Float(Self.latitudeSegments)
        let lon = Float(longitude % Self.longitudeSegments) * 2 * .pi / Float(Self.longitudeSegments)
        let variation = sin(lon * 9 + sin(lat * 7)) * sin(lat * 13) * sin(lat)
        switch self {
        case .tatooine: return 12 + variation * 10
        case .hoth: return 8 + abs(variation) * 32
        case .endor: return 12 + variation * 9 + abs(sin(lon * 23) * sin(lat * 31)) * sin(lat) * 9
        case .coruscant:
            let district = abs(sin(Float(latitude * 127 + (longitude % Self.longitudeSegments) * 311)))
            return sin(lat) * (5 + (district > 0.66 ? district * 42 : 0))
        }
    }
    func surfaceRadius(direction: SIMD3<Float>) -> Float {
        let unit = simd_normalize(direction)
        let lat = acos(max(-1, min(1, unit.y))) / .pi * Float(Self.latitudeSegments)
        var lon = atan2(unit.z, unit.x) / (2 * .pi) * Float(Self.longitudeSegments)
        if lon < 0 { lon += Float(Self.longitudeSegments) }
        let i = min(Self.latitudeSegments - 1, Int(lat)), j = Int(lon)
        let a = height(latitude: i, longitude: j), b = height(latitude: i, longitude: j + 1)
        let c = height(latitude: i + 1, longitude: j), d = height(latitude: i + 1, longitude: j + 1)
        // Conservative envelope covers the planar triangles as well as their edges.
        return radius + max(a, b, c, d)
    }
    func clearance(at point: SIMD3<Float>) -> Float {
        let delta = point - position
        guard simd_length_squared(delta) > 0.001 else { return -radius - 50 }
        return simd_length(delta) - surfaceRadius(direction: delta)
    }
}

enum HyperspaceEvent: Equatable {
    case none
    case beganHyperspace
    case enteredSpace
    case planetImpact(SpacePlanet)
    case surfaceBeacon
    case returnedToAtmosphere
    case asteroidImpact(damage: Float)
}

struct SpaceAsteroid: Identifiable {
    let id: Int
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    let radius: Float
    let spin: SIMD3<Float>
    let attackPhase: Float
    let aggression: Float
    var ore: TradeMineral {
        let seed = UInt64(UInt32(truncatingIfNeeded: id)) &* 6364136223846793005 &+ 1442695040888963407
        return TradeMineral.draw(tierRoll: Int((seed >> 17) % UInt64(MineralRarity.totalWeight)), materialRoll: Int(seed % 840))
    }
}

/// Owns the two-way free-roam portal and a bounded, recyclable asteroid field.
struct HyperspaceManager {
    let portals: [FreeRoamPortal]
    let returnPortal = SIMD3<Float>(0, 0, -7_200)
    private(set) var selectedPlanet: SpacePlanet? = .tatooine
    private(set) var surfaceBeacons = 0
    private(set) var surfacePoints = 0
    private(set) var surfacePlanet: SpacePlanet?
    private(set) var surfaceTime:Float = 0
    private(set) var relaxedSpace = false
    private(set) var zone: FreeRoamZone = .atmosphere
    private(set) var challenge: SpaceChallenge = .asteroidBelt
    private(set) var asteroids: [SpaceAsteroid] = []
    private(set) var destroyedAsteroids = 0
    private(set) var salvageableHits = 0
    private(set) var salvageableOre: [TradeMineral] = []
    private(set) var jumpTimeRemaining: Float = 0
    private var portalCooldown: Float = 0
    private var impactCooldown: Float = 0
    private var departurePortal = SIMD3<Float>.zero
    private var asteroidTime: Float = 0

    init(terrain: TerrainGenerator) {
        let centerZ = FreeRoamSector.portals.center.z
        let centerX = FreeRoamSector.portals.center.x
        let offsets: [SIMD2<Float>] = [[-620, -420], [620, -420], [-620, 420], [620, 420]]
        portals = zip(SpaceChallenge.allCases, offsets).map { challenge, offset in
            let x = centerX + offset.x
            let z = centerZ + offset.y
            let y = terrain.surfaceHeight(x: x, z: z) + 390
            return FreeRoamPortal(id: challenge.rawValue, destination: challenge, position: [x, y, z])
        }
        asteroids = (0..<SpaceChallenge.asteroidBelt.asteroidCount).map {
            Self.makeAsteroid(id: $0, aheadOf: .zero, challenge: .asteroidBelt)
        }
    }

    mutating func reset() {
        surfaceBeacons = 0; surfacePoints = 0; surfaceTime = 0
        surfacePlanet = nil
        relaxedSpace = false
        zone = .atmosphere
        challenge = .asteroidBelt
        jumpTimeRemaining = 0
        portalCooldown = 0
        impactCooldown = 0
        asteroidTime = 0
        destroyedAsteroids = 0
        departurePortal = .zero
        asteroids = (0..<challenge.asteroidCount).map { Self.makeAsteroid(id: $0, aheadOf: .zero, challenge: challenge) }
    }

    mutating func beginRelaxedSpace(state: inout FlightState, speed: Float) {
        reset(); selectedPlanet = .tatooine; relaxedSpace = true; zone = .asteroidField; asteroids = []
        state.position = [0, 0, 260]; state.pitch = 0; state.roll = 0; state.heading = 0
        state.airspeed = max(speed, 90); state.velocity = [0, 0, -state.airspeed]
    }

    mutating func enterPlanet(_ planet: SpacePlanet, state: inout FlightState) {
        guard relaxedSpace else { return }
        surfacePlanet = planet; selectedPlanet = planet
        surfaceBeacons = 0; surfacePoints = 0; surfaceTime = 0
        state.position = PlanetExploration(planet: planet).arrival; state.pitch = 0; state.roll = 0; state.heading = 0
        state.airspeed = 100; state.velocity = [0, 0, -100]
    }
    mutating func returnToOrbit(state: inout FlightState) {
        guard let planet = surfacePlanet else { return }
        surfacePlanet = nil
        state.position = planet.position + SIMD3<Float>(0, 0, planet.radius + 700)
        state.heading = .pi; state.pitch = 0; state.roll = 0
        state.velocity = state.forward * state.airspeed
    }

    mutating func selectPlanet(_ planet: SpacePlanet?) { selectedPlanet = planet }

    func nearestPortal(to position: SIMD3<Float>) -> FreeRoamPortal {
        portals.min(by: { simd_distance($0.position, position) < simd_distance($1.position, position) }) ?? portals[0]
    }
    func targetPortal(to position: SIMD3<Float>) -> SIMD3<Float> {
        if let planet = surfacePlanet {
            let route = PlanetExploration(planet: planet).landmarks
            return surfaceBeacons < route.count ? route[surfaceBeacons].position : [0, PlanetExploration(planet:planet).orbitAltitude + 100, 0]
        }
        if relaxedSpace, let selectedPlanet { return selectedPlanet.position }
        return zone == .atmosphere ? nearestPortal(to: position).position : returnPortal
    }
    func targetName(to position: SIMD3<Float>) -> String {
        if let surfacePlanet {
            let surface = PlanetExploration(planet: surfacePlanet)
            let area = surfacePlanet == .tatooine && MirageBasin.enabled && MirageBasin.contains(x:position.x,z:position.z,margin:800) ? "Mirage Basin" : surfacePlanet.name
            return surfaceBeacons < surface.landmarks.count
                ? "\(area) · \(surface.landmarks[surfaceBeacons].name) · \(surfaceBeacons)/6 · \(surfacePoints) pts"
                : "\(area) · scout run complete · \(surfacePoints) pts · explore freely"
        }
        switch zone {
        case .atmosphere: return nearestPortal(to: position).destination.name
        case .hyperspace: return "Hyperspace · \(challenge.name)"
        case .asteroidField:
            guard relaxedSpace, let planet = selectedPlanet else { return "Return portal" }
            let clearance = max(0, Int(planet.clearance(at: position)))
            return "\(planet.name) · surface \(clearance) m"
        }
    }

    func nearestAsteroid(to position: SIMD3<Float>) -> Float? {
        guard zone == .asteroidField else { return nil }
        return asteroids.map { max(0, simd_distance($0.position, position) - $0.radius) }.min()
    }

    mutating func advance(state: inout FlightState, collisionRadius: Float, cityCollisionRadius: Float? = nil, dt: Float, mining: Bool = false, planetAccess:Bool = true) -> HyperspaceEvent {
        portalCooldown = max(0, portalCooldown - dt)
        impactCooldown = max(0, impactCooldown - dt)

        if zone == .atmosphere {
            guard portalCooldown == 0,
                  let portal = portals.first(where: { simd_distance(state.position, $0.position) < 120 }) else { return .none }
            zone = .hyperspace
            challenge = portal.destination
            departurePortal = portal.position
            jumpTimeRemaining = 5
            portalCooldown = 2
            state.pitch = 0
            state.roll = 0
            state.velocity = state.forward * max(state.airspeed, 180)
            return .beganHyperspace
        }

        if zone == .hyperspace {
            jumpTimeRemaining = max(0, jumpTimeRemaining - dt)
            if jumpTimeRemaining == 0 {
                zone = .asteroidField
                state.position = [0, 0, 260]
                state.pitch = 0
                state.roll = 0
                state.heading = 0
                state.velocity = [0, 0, -max(state.airspeed, 90)]
                asteroids = (0..<challenge.asteroidCount).map { Self.makeAsteroid(id: $0, aheadOf: state.position, challenge: challenge) }
                destroyedAsteroids = 0
                return .enteredSpace
            }
            return .none
        }

        if relaxedSpace {
            if let planet = surfacePlanet {
                asteroids.removeAll(keepingCapacity:true)
                surfaceTime += dt
                let surface = PlanetExploration(planet: planet)
                let obstacleRadius = planet == .coruscant ? (cityCollisionRadius ?? collisionRadius) : collisionRadius
                if surface.clearance(at: state.position,time:surfaceTime) <= collisionRadius || surface.hitsObstacle(at: state.position, radius: obstacleRadius,time:surfaceTime)
                    || (planet == .tatooine && MirageBasin.enabled && MirageBasin.impact(from:state.position-state.velocity*dt,to:state.position,radius:obstacleRadius,start:surfaceTime-dt,end:surfaceTime)) {
                    return .planetImpact(planet)
                }
                if state.position.y > surface.orbitAltitude || abs(state.position.x) > PlanetExploration.extent - 200 || abs(state.position.z) > PlanetExploration.extent - 200 {
                    returnToOrbit(state: &state); return .enteredSpace
                }
                if surfaceBeacons < surface.landmarks.count {
                    let target = surface.landmarks[surfaceBeacons].position
                    let previous = state.position - state.velocity * dt
                    let segment = state.position - previous
                    let t = clamp(simd_dot(target - previous, segment) / max(0.001, simd_length_squared(segment)), 0, 1)
                    if simd_distance(previous + segment * t, target) < 200 {
                        surfaceBeacons += 1; surfacePoints += surfaceBeacons == surface.landmarks.count ? 750 : 250
                        return .surfaceBeacon
                    }
                }
                return .none
            }
            if planetAccess, let planet = SpacePlanet.allCases.first(where: { $0.clearance(at: state.position) > 0 && $0.clearance(at: state.position) < 220 }) {
                enterPlanet(planet, state: &state); return .enteredSpace
            }
            if planetAccess, let planet = SpacePlanet.allCases.first(where: { $0.clearance(at: state.position) <= collisionRadius }) {
                return .planetImpact(planet)
            }
            if planetAccess && simd_distance(state.position, returnPortal) < 150 {
                reset(); state.position = portals[0].position + SIMD3<Float>(0, 0, 260)
                state.velocity = state.forward * max(state.airspeed, 90)
                portalCooldown = 3
                return .returnedToAtmosphere
            }
            if mining {
                if asteroids.isEmpty { asteroids = (0..<26).map { Self.makeMiningAsteroid(id:$0,ship:state) } }
                for index in asteroids.indices {
                    asteroids[index].position += asteroids[index].velocity*dt
                    let position = asteroids[index].position
                    if simd_distance(position,state.position) > 4500 || (planetAccess && SpacePlanet.allCases.contains(where:{simd_distance(position,$0.position) < $0.radius+500})) {
                        asteroids[index] = Self.makeMiningAsteroid(id:asteroids[index].id+41,ship:state)
                    }
                }
                if impactCooldown == 0, let rock = asteroids.first(where:{simd_distance($0.position,state.position) < $0.radius+collisionRadius}) {
                    impactCooldown = 1.2
                    if let index = asteroids.firstIndex(where:{$0.id == rock.id}) { asteroids[index] = Self.makeMiningAsteroid(id:rock.id+67,ship:state) }
                    return .asteroidImpact(damage:12)
                }
            } else { asteroids.removeAll(keepingCapacity:true) }
            return .none
        }

        asteroidTime += dt
        for index in asteroids.indices {
            // Incoming rocks hunt the player's projected position only while they are ahead.
            // The weave prevents every attack from collapsing into one predictable line.
            let deltaZ = state.position.z - asteroids[index].position.z
            if deltaZ > 120 {
                let lead = state.position + state.velocity * 0.38
                let toLead = lead - asteroids[index].position
                if simd_length_squared(toLead) > 1 {
                    let attackSpeed = max(simd_length(asteroids[index].velocity), 115)
                    let desired = simd_normalize(toLead) * attackSpeed
                    let steer = min(1, dt * asteroids[index].aggression)
                    asteroids[index].velocity += (desired - asteroids[index].velocity) * steer
                }
                let weave = sin(asteroidTime * (2.1 + asteroids[index].aggression) + asteroids[index].attackPhase)
                let verticalWeave = cos(asteroidTime * 1.7 + asteroids[index].attackPhase * 0.73)
                asteroids[index].velocity.x += weave * (18 + 9 * asteroids[index].aggression) * dt
                asteroids[index].velocity.y += verticalWeave * (12 + 6 * asteroids[index].aggression) * dt
            }
            asteroids[index].position += asteroids[index].velocity * dt
            if asteroids[index].position.z > state.position.z + 450 {
                asteroids[index] = Self.makeAsteroid(id: asteroids[index].id + 41, aheadOf: state.position, challenge: challenge)
            }
        }

        if portalCooldown == 0, simd_distance(state.position, returnPortal) < 130 {
            zone = .atmosphere
            portalCooldown = 2
            state.position = departurePortal + SIMD3<Float>(0, 0, -260)
            state.pitch = 0
            state.roll = 0
            state.heading = .pi
            state.velocity = state.forward * max(state.airspeed, 70)
            return .returnedToAtmosphere
        }

        if impactCooldown == 0,
           let index = asteroids.firstIndex(where: { simd_distance($0.position, state.position) < $0.radius + collisionRadius }) {
            let away = simd_normalize(state.position - asteroids[index].position + SIMD3<Float>(0.01, 0.01, 0.01))
            state.velocity += away * 34
            asteroids[index] = Self.makeAsteroid(id: asteroids[index].id + 67, aheadOf: state.position, challenge: challenge)
            impactCooldown = 0.8
            return .asteroidImpact(damage: 34)
        }
        return .none
    }

    /// Recycles shot asteroids into a later attack wave and returns the bolts that hit them.
    mutating func resolvePlayerFire(_ bolts: [PlayerBolt], shipPosition: SIMD3<Float>) -> Set<Int> {
        salvageableHits = 0; salvageableOre = []
        guard zone == .asteroidField else { return [] }
        var consumed: Set<Int> = []
        for boltIndex in bolts.indices where !consumed.contains(boltIndex) {
            guard let asteroidIndex = asteroids.firstIndex(where: {
                let end = bolts[boltIndex].position
                let start = end-bolts[boltIndex].velocity*FlightPhysics.step
                let segment = end-start
                let t = max(0,min(1,simd_dot($0.position-start,segment)/max(0.001,simd_length_squared(segment))))
                return simd_distance($0.position,start+segment*t) < $0.radius+7
            }) else { continue }
            consumed.insert(boltIndex)
            destroyedAsteroids += 1
            if simd_distance(asteroids[asteroidIndex].position,shipPosition) <= 900 {
                salvageableHits += 1
                salvageableOre.append(asteroids[asteroidIndex].ore)
            }
            if relaxedSpace {
                var spawn = FlightState(); spawn.position = shipPosition
                asteroids[asteroidIndex] = Self.makeMiningAsteroid(id:asteroids[asteroidIndex].id+101,ship:spawn)
            } else {
                asteroids[asteroidIndex] = Self.makeAsteroid(id:asteroids[asteroidIndex].id+101,aheadOf:shipPosition-SIMD3<Float>(0,0,1500),challenge:challenge)
            }
        }
        return consumed
    }

    func oreSurvey(from state: FlightState) -> OreSurvey? {
        guard relaxedSpace, surfacePlanet == nil, zone == .asteroidField else { return nil }
        return asteroids.filter {
            let delta = $0.position - state.position
            return simd_length(delta) < 1800 && simd_length(delta) > 1 && simd_dot(simd_normalize(delta), state.forward) > 0.5
        }.min { simd_distance($0.position,state.position) < simd_distance($1.position,state.position) }.map {
            OreSurvey(asteroidID: $0.id, mineral: $0.ore, position: $0.position,
                      distance: simd_distance($0.position,state.position), hazardous: $0.radius > 42)
        }
    }

    func miningTarget(from state: FlightState) -> SIMD3<Float>? {
        guard relaxedSpace, surfacePlanet == nil else { return nil }
        var target: SIMD3<Float>?
        var closest: Float = 700*700
        let threshold = cos(Float.pi*8/180)
        for rock in asteroids {
            let delta = rock.position-state.position, squared = simd_length_squared(delta)
            guard squared > 1, squared < closest else { continue }
            if simd_dot(delta/sqrt(squared),state.forward) > threshold {
                closest = squared; target = rock.position
            }
        }
        return target
    }

    private static func makeMiningAsteroid(id: Int, ship: FlightState) -> SpaceAsteroid {
        let slot = abs(id)%26
        let offset: SIMD3<Float> = slot == 0 ? [0,0,-550] : [Float((slot%5)-2)*145,Float((slot/5)%3-1)*100,-Float(650+slot*95)]
        let rock = SpaceAsteroid(id:id,position:ship.position+ship.orientation.act(offset),velocity:[sin(Float(id))*2,cos(Float(id))*1.2,0],radius:Float(25+(slot*7)%25),spin:[0.1,0.15,0.08],attackPhase:Float(id),aggression:0)
        let rarity = MineralRarity.allCases.firstIndex(of:rock.ore.rarity) ?? 0
        return SpaceAsteroid(id:id,position:rock.position,velocity:rock.velocity,radius:rock.radius+(rarity >= 3 ? 12:0),
                             spin:rock.spin*(1+Float(rarity)*0.6),attackPhase:rock.attackPhase,aggression:0)
    }

    private static func makeAsteroid(id: Int, aheadOf ship: SIMD3<Float>, challenge: SpaceChallenge) -> SpaceAsteroid {
        let seed = UInt32(truncatingIfNeeded: id &* 1_103_515_245 &+ 12_345)
        let x = ship.x + (Float(seed % 2_001) / 1_000 - 1) * challenge.spread
        let y = ship.y + (Float((seed >> 9) % 2_001) / 1_000 - 1) * challenge.spread * 0.52
        let wave = abs(id) % 7
        let member = abs(id) % 4
        let z = ship.z - Float(720 + wave * 540 + member * 72)
        let radius = Float(28 + abs(id * 17) % 70)
        let speed = Float(112 + abs(id * 13) % 82) * challenge.speedMultiplier
        let target = ship + SIMD3<Float>(Float((id % 3) - 1) * 55, Float((id % 5) - 2) * 24, 0)
        let direction = simd_normalize(target - SIMD3<Float>(x, y, z))
        return SpaceAsteroid(id: id, position: [x, y, z], velocity: direction * speed, radius: radius,
                             spin: [Float(id % 5 + 1) * 0.19, Float(id % 7 + 1) * 0.16, Float(id % 3 + 1) * 0.23],
                             attackPhase: Float(seed % 628) * 0.01,
                             aggression: 1.25 + Float(challenge.rawValue) * 0.24 + Float(abs(id) % 3) * 0.12)
    }
}

struct FlightState {
    var position = SIMD3<Float>(0, 430, 250)
    var velocity = SIMD3<Float>(0, 0, -52)
    var pitch: Float = 0
    var roll: Float = 0
    var heading: Float = 0
    var airspeed: Float = 52
    var stalled = false
    var lateralDrift: Float = 0
    var podSteering: Float = 0
    var podTurnRate: Float = 0
    var driftCharge: Float = 0
    var driftBoostRemaining: Float = 0
    var wasDrifting = false
    var rudderResponse: Float = 0
    var pitchRate: Float = 0

    /// Display-only interpolation; the authoritative physics state still drives every collision.
    static func rendered(from previous: FlightState, to current: FlightState, fraction: Float) -> FlightState {
        guard fraction.isFinite else { return current }
        // Transfers and hyperspace arrivals must snap instead of sweeping the view across the map.
        let maximumStepDistance = max(100, max(previous.airspeed, current.airspeed) * FlightPhysics.step * 4)
        guard simd_distance(previous.position, current.position) <= maximumStepDistance else { return current }
        let t = clamp(fraction, 0, 1)
        func angle(_ a: Float, _ b: Float) -> Float { a + atan2(sin(b - a), cos(b - a)) * t }
        var result = current
        result.position = previous.position + (current.position - previous.position) * t
        result.velocity = previous.velocity + (current.velocity - previous.velocity) * t
        result.pitch = angle(previous.pitch, current.pitch)
        result.roll = angle(previous.roll, current.roll)
        result.heading = angle(previous.heading, current.heading)
        result.airspeed = previous.airspeed + (current.airspeed - previous.airspeed) * t
        return result
    }

    /// Short, responsive easing removes the full-rate yaw step from keys and touch rudder buttons.
    mutating func easedRudder(_ requested: Float, dt: Float) -> Float {
        guard dt.isFinite, dt > 0 else { return rudderResponse }
        let target = requested.isFinite ? clamp(requested, -1, 1) : 0
        let recovering = target * rudderResponse < 0 || abs(target) < 0.01
        let rate: Float = recovering ? 24 : 16
        rudderResponse += (target - rudderResponse) * (1 - exp(-min(dt, 0.1) * rate))
        return rudderResponse
    }

    var orientation: simd_quatf {
        simd_quatf(angle: -heading, axis: [0, 1, 0]) *
        simd_quatf(angle: pitch, axis: [1, 0, 0]) *
        simd_quatf(angle: -roll, axis: [0, 0, 1])
    }
    var forward: SIMD3<Float> { orientation.act([0, 0, -1]) }
}

/// SI units, +Y up, north = -Z. A forgiving aerodynamic model, not a training simulator.
struct FlightPhysics {
    static let step: Float = 1 / 120
    var aircraft: AircraftType = .kestrel

    func advance(_ state: inout FlightState, input: FlightInput, wind: SIMD3<Float>, dt: Float, raceSpeedMultiplier: Float = 1, draftStrength: Float = 0) {
        let racingPod = aircraft.isPodracer
        if racingPod {
            advancePodracer(&state, input: input, wind: wind, dt: dt, pace: raceSpeedMultiplier, draft: draftStrength)
            return
        }
        let oldPitch = state.pitch
        advancePitch(&state, input: input.pitch, dt: dt)
        advanceBank(&state, input: input.roll, dt: dt)
        // Bounded through 90°: tan(bank) has a pole that flung a rolling ship off course.
        let bankTurn = 9.81 * sin(state.roll) * 1.8 / max(state.airspeed, 22)
        let oldHeading = state.heading
        let rudder = state.easedRudder(input.yaw, dt: dt)
        state.heading += (bankTurn + rudder * aircraft.yawAuthority) * dt
        state.heading = state.heading.truncatingRemainder(dividingBy: 2 * .pi)

        // Turn the air-relative momentum with the ship. Otherwise the nose can complete
        // a 180° turn while the craft keeps sliding along its old course, appearing to fly backward.
        let turn = simd_quatf(angle: -(state.heading - oldHeading), axis: [0, 1, 0])
        let pitchAxis = simd_quatf(angle: -oldHeading, axis: [0,1,0]).act(SIMD3<Float>(1,0,0))
        let pitchTurn = simd_quatf(angle: state.pitch - oldPitch, axis: pitchAxis)
        state.velocity = turn.act(pitchTurn.act(state.velocity - wind)) + wind
        let relativeVelocity = state.velocity - wind
        let speed = max(simd_length(relativeVelocity), 0.1)
        let direction = relativeVelocity / speed
        let bodyVelocity = state.orientation.inverse.act(relativeVelocity)
        let angleOfAttack = atan2(-bodyVelocity.y, -bodyVelocity.z)
        state.stalled = speed < aircraft.cruiseSpeed * (25 / 52) || abs(angleOfAttack) > 0.34
        var coefficient = clamp(0.32 + 4.2 * angleOfAttack, -0.6, 1.4)
        if abs(angleOfAttack) > 0.34 { coefficient *= 0.38 }
        let right = state.orientation.act(SIMD3<Float>(1, 0, 0))
        let liftAxis = simd_cross(right, direction)
        let liftDirection = simd_length(liftAxis) > 0.001 ? simd_normalize(liftAxis) : SIMD3<Float>(0, 1, 0)
        let dynamicPressure = 0.5 * 1.225 * speed * speed
        // Scale wing loading to trim each airframe near its intended cruise speed.
        let wingLoading = (16.2 / 850) * pow(52 / aircraft.cruiseSpeed, 2)
        let enginePower = sqrt(aircraft.cruiseSpeed / 52)
        let lift = liftDirection * (dynamicPressure * wingLoading * coefficient)
        // Match drag to 65% cruise thrust; the faster aircraft should not climb away at neutral input.
        let drag = -direction * (dynamicPressure * wingLoading * (0.124 + 0.06 * coefficient * coefficient) * enginePower)
        let thrust = state.forward * (clamp(input.throttle, 0, 1) * 6.3 * enginePower * (input.boost ? 2.25 : 1))
        // Mild coordinated-flight assistance damps sideslip without forcing a fixed airspeed.
        let lateral = -right * simd_dot(relativeVelocity, right) * 0.7
        state.velocity += (lift + drag + thrust + lateral + SIMD3<Float>(0, -9.81, 0)) * dt
        let horizontalForward = state.forward
        let backwardAirspeed = simd_dot(state.velocity - wind, horizontalForward)
        if backwardAirspeed < 0 {
            state.velocity -= horizontalForward * backwardAirspeed
        }
        state.position += state.velocity * dt
        state.airspeed = simd_length(state.velocity - wind)
    }

    /// In space the controls keep their aircraft feel while lift and gravity are absent.
    func advanceSpace(_ state: inout FlightState, input: FlightInput, dt: Float, speedLimit: Float? = nil) {
        advancePitch(&state, input: input.pitch, dt: dt)
        advanceBank(&state, input: input.roll, dt: dt)
        let turnRate = state.easedRudder(input.yaw, dt: dt) * aircraft.yawAuthority + sin(state.roll) * 0.72
        state.heading += turnRate * dt
        state.heading.formTruncatingRemainder(dividingBy: 2 * .pi)
        let thrust = input.throttle.isFinite ? clamp(input.throttle,-1,1):0
        let normalSpeed = aircraft.cruiseSpeed * 1.45 * thrust * (input.boost && thrust > 0 ? 1.3:1)
        let targetSpeed = speedLimit.map { $0.isFinite ? clamp(normalSpeed,-max(0,$0),max(0,$0)):normalSpeed } ?? normalSpeed
        let desiredVelocity = state.forward * targetSpeed
        state.velocity += (desiredVelocity-state.velocity) * (1-exp(-dt*1.6))
        state.position += state.velocity*dt
        state.airspeed = simd_length(state.velocity)
        state.stalled = false
        state.lateralDrift = 0
    }

    /// Full deflection keeps rotating through vertical and inverted flight. Small inputs remain precise.
    private func advancePitch(_ state: inout FlightState, input: Float, dt: Float) {
        guard dt.isFinite, dt > 0 else { return }
        let stick = clamp(input, -1, 1)
        let neutralAngle = atan2(sin(state.pitch), cos(state.pitch))
        let target = abs(stick) > 0.04 ? stick * aircraft.maximumPitch * 1.6 : clamp(-neutralAngle * 0.7, -0.35, 0.35)
        state.pitchRate += (target - state.pitchRate) * (1 - exp(-dt * 7))
        state.pitch += state.pitchRate * dt
    }

    /// Bank toward a bounded angle. Holding a direction turns without rolling over.
    private func advanceBank(_ state: inout FlightState, input: Float, dt: Float) {
        guard dt.isFinite, dt > 0 else { return }
        let stick = input.isFinite ? clamp(input, -1, 1) : 0
        let limit = aircraft.maximumRoll
        state.roll = clamp(state.roll,-limit,limit)
        state.roll += (stick * limit - state.roll) * (1 - exp(-dt * aircraft.response))
    }

    private func advancePodracer(_ state: inout FlightState, input: FlightInput, wind: SIMD3<Float>, dt: Float, pace: Float, draft: Float) {
        let racing = pace > 1
        let rawSteer = clamp(input.roll + input.yaw * 0.8, -1, 1)
        let steer: Float
        if racing {
            // A progressive centre makes small thumb movements precise; full lock keeps its authority.
            let targetSteer = rawSteer * 0.72 + rawSteer * rawSteer * rawSteer * 0.28
            let countersteering = targetSteer * state.podSteering < 0
            let steeringResponse: Float = countersteering || abs(rawSteer) < 0.01 ? 24 : 18
            state.podSteering += (targetSteer - state.podSteering) * (1 - exp(-dt * steeringResponse))
            steer = state.podSteering
        } else {
            state.podSteering = rawSteer
            steer = rawSteer
        }
        state.driftBoostRemaining = max(0, state.driftBoostRemaining - dt)
        let drifting = racing && input.skid && abs(steer) > 0.25 && state.airspeed > aircraft.cruiseSpeed
        if drifting {
            state.driftCharge = min(1, state.driftCharge + dt * 0.75)
        } else if !input.skid {
            if state.wasDrifting && state.driftCharge >= 0.35 {
                state.driftBoostRemaining = 0.45 + state.driftCharge * 0.8
            }
            state.driftCharge = 0
        }
        // Releasing a charged slide gives an automatic corner-exit burst, without spending boost fuel.
        state.wasDrifting = racing && input.skid && state.driftCharge > 0
        let boostFactor: Float = input.boost ? (racing ? 1.65 : 1.3) : state.driftBoostRemaining > 0 ? 1.28 : 1
        let draftFactor: Float = racing ? 1 + clamp(draft,0,1) * 0.12 : 1
        let targetSpeed = aircraft.cruiseSpeed * pace * (0.62 + clamp(input.throttle, 0, 1) * 0.72) * boostFactor * draftFactor
        let acceleration: Float = racing ? (boostFactor > 1 ? 5.2 : 3.2) : input.boost ? 2.8 : 1.65
        state.airspeed += (targetSpeed - state.airspeed) * (1 - exp(-dt * acceleration))
        let driftTarget = steer * (input.skid ? (racing ? 160 : 105) : 22)
        state.lateralDrift += (driftTarget - state.lateralDrift) * (1 - exp(-dt * (input.skid ? 1.8 : 4.2)))
        let turnAuthority = racing ? 0.65 + max(0, aircraft.yawAuthority - 0.31) * 0.65 : aircraft.yawAuthority
        let turnRate = racing ? turnAuthority * (input.skid ? 2.6 : 1.5) * pace : aircraft.yawAuthority * (input.skid ? 2.2 : 1.35)
        let desiredTurnRate = steer * turnRate
        if racing {
            // Smooth the change in turn force too, especially when entering or releasing a skid.
            let response: Float = desiredTurnRate * state.podTurnRate < 0 || abs(rawSteer) < 0.01 ? 28 : 22
            state.podTurnRate += (desiredTurnRate - state.podTurnRate) * (1 - exp(-dt * response))
        } else { state.podTurnRate = desiredTurnRate }
        state.heading += state.podTurnRate * dt
        state.heading.formTruncatingRemainder(dividingBy: 2 * .pi)
        // Positive roll lowers the right side in FlightState.orientation.
        let rollTarget = steer * (input.skid ? 0.58 : 0.16)
        state.roll += (rollTarget - state.roll) * (racing ? 1 - exp(-dt * 18) : 1)
        state.pitch = 0
        let nose = SIMD3<Float>(sin(state.heading), 0, -cos(state.heading))
        let lateral = SIMD3<Float>(cos(state.heading), 0, sin(state.heading))
        let forwardSpeed = max(aircraft.cruiseSpeed * 0.35, state.airspeed)
        let desired = nose * forwardSpeed + lateral * state.lateralDrift + SIMD3<Float>(wind.x, 0, wind.z) * 0.08
        // Fast repulsor steering holds a corner at arcade speeds; skid adds a deliberate lateral slide.
        let grip: Float = racing ? (input.skid ? 7 : 5.5) * pace : (input.skid ? 2.8 : 1) * 1.7
        let response = 1 - exp(-dt * grip)
        state.velocity.x += (desired.x - state.velocity.x) * response
        state.velocity.z += (desired.z - state.velocity.z) * response
        state.position += state.velocity * dt
        state.velocity.y = 0
        state.stalled = false
    }
}
