import simd

struct FlightCrashAdvice {
    let cause: String
    var title: String {
        if cause == "Black hole event horizon" { return "Beyond the event horizon." }
        if cause.hasPrefix("Solar collision:") { return cause + "." }
        if cause.contains("building") || cause.contains("residence") { return "Building collision." }
        if cause.contains("ground") { return "Ground impact." }
        if cause == "Death Star exploded" { return "Time ran out." }
        if cause == "Comet impact" { return "Comet impact." }
        if cause == "Bounty target fire" { return "Shot down by bounty target." }
        if cause == "Asteroid impact" { return "Asteroid impact." }
        if ["Enemy fighter","Turret strike","Fighter interception"].contains(cause) { return "Shot down." }
        return cause + "."
    }
    var advice: String {
        if cause == "Black hole event horizon" { return "Your ship crossed the black hole's event horizon. On your next attempt, watch the gravity warning, turn away while the pull is weak, and use forward or reverse thrust to escape. Hyperspace is blocked in extreme gravity." }
        if cause.hasPrefix("Solar collision:") { return "Your ship struck a Solar System body. These are flyby models, without surface entry. Keep clear of the globe and select a new navigation bearing." }
        if cause.contains("building") || cause.contains("residence") { return "Your ship struck a building or tunnel wall on Coruscant. Follow the open avenues, bank earlier, and use approach assist near skyports." }
        if cause.contains("ground") { return "Your ship hit the ground. Watch the GROUND clearance readout and pull up before it reaches your ship's height." }
        if cause.contains("obstacle") { return "Your ship struck a surface obstacle. Leave more space around structures and check your bank before turning." }
        if cause == "Death Star exploded" { return "The countdown reached zero before the final gate. Reach the final checkpoint before detonation." }
        if cause == "Comet impact" { return "Comet strikes depleted your shields. Watch the crossing warning and change course before the bright head reaches your flight path." }
        if cause == "Bounty target fire" { return "The marked target depleted your shields. Its bolts are slow; turn away between firing passes instead of flying straight at it." }
        if cause == "Asteroid impact" { return "Asteroid strikes depleted your shields. Make small course changes early and fire to break incoming rocks." }
        if ["Enemy fighter","Turret strike","Fighter interception"].contains(cause) { return "Enemy fire depleted your shields. Change direction, watch the scanner and avoid a straight, predictable flight path." }
        if cause.hasPrefix("Impact with") { return "Your ship struck the planet in orbit. Use Enter in Flight tools or approach the planet's entry zone before touching its surface." }
        return "Your ship struck terrain. Leave more ground clearance and begin climbing before the ridge." }
}

struct CollisionSystem {
    let terrain: TerrainGenerator
    var aircraft: AircraftType {
        didSet { probes = aircraft.collisionProbes }
    }
    private var probes: [SIMD3<Float>]
    private let scenery: ScenicRegion
    private let raceCircuit: RaceCircuit?

    init(terrain: TerrainGenerator, aircraft: AircraftType = .kestrel) {
        self.terrain = terrain
        self.aircraft = aircraft
        probes = aircraft.collisionProbes
        scenery = ScenicRegion(terrain: terrain)
        raceCircuit = terrain.level.isPodRaceTrack ? RaceCircuit(level:terrain.level) : nil
    }

    func clearance(at position: SIMD3<Float>) -> Float {
        position.y - terrain.surfaceHeight(x: position.x, z: position.z)
    }

    func impact(from old: FlightState, to new: FlightState) -> SIMD3<Float>? {
        // Swept probes avoid tunnelling even when a frame spans a narrow ridge.
        let samples = max(1, Int(ceil(simd_distance(old.position, new.position) / 2)))
        for sample in 0...samples {
            let t = Float(sample) / Float(samples)
            let position = old.position + (new.position - old.position) * t
            let orientation = simd_slerp(old.orientation, new.orientation, t)
            let overTrack = aircraft.isPodracer && (raceCircuit.map { $0.roadOffset(position) < terrain.level.valleyWidth * 0.4 } ?? false)
            for probe in probes {
                let world = position + orientation.act(probe)
                if (clearance(at: world) <= 1 && !overTrack) || scenery.hits(world) { return position }
            }
        }
        return nil
    }

    func warning(for state: FlightState) -> String? {
        if clearance(at: state.position) < 45 { return "TERRAIN · PULL UP" }
        for seconds: Float in [0.5, 1, 2, 3] {
            if scenery.hits(state.position + state.velocity * seconds) { return "STRUCTURE AHEAD" }
            if clearance(at: state.position + state.velocity * seconds) < 28 { return "TERRAIN AHEAD" }
        }
        return state.stalled ? "STALL · LOWER NOSE" : nil
    }
}
