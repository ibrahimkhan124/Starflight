import Foundation
import simd

struct TileKey: Hashable, Sendable {
    let x: Int
    let z: Int
}

struct TerrainMeshData: Sendable {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var textureCoordinates: [SIMD2<Float>] = []
    var indices: [UInt32] = []
    var materials: [UInt32] = []
}

/// Immutable seeded height field shared by rendering, route placement, and collision.
struct TerrainGenerator: Sendable {
    static let tileSize: Float = 600
    static let collisionSpacing: Float = 25
    var seed: UInt32 = 7319
    var level: FlightLevel = .alpine
    var customLevel: CustomLevelDefinition?

    func difficulty(at z: Float) -> Float {
        if level.isFreeRoam { return 0.25 }
        return clamp(-z / level.routeLength, 0, 1)
    }
    func valleyCenter(at z: Float) -> Float {
        if level == .deathStar {
            let distance = -z + 250
            return 250 * sin(distance * 0.00115) + 70 * sin(distance * 0.0021)
        }
        if level.isPodRaceTrack {
            let distance = -z
            // Smooth alternating hairpins with long straights; tanh keeps each U bend rounded.
            let spacing = level.routeLength / Float(max(3, level.gateCount - 1))
            let phase = distance / max(spacing * 0.72, 1)
            let uTurn = tanh(5 * sin(phase))
            return level.raceTurnRadius * uTurn
        }
        let frequency = level.bendFrequency * (customLevel?.bends ?? 1)
        return 290 * sin(-z * frequency) + 115 * sin(-z * frequency * 2.2353)
    }

    static let podGroundClearance: Float = 10
    func hoverHeight(at z: Float) -> Float {
        92 + Self.podGroundClearance
    }

    func height(x: Float, z: Float) -> Float {
        if level.isFreeRoam {
            // Periodic authored region: Blender tiles and collision repeat seamlessly in every direction.
            let u = x * (2 * Float.pi / 4800), v = z * (2 * Float.pi / 4800)
            let ridges = pow(abs(sin(u) * cos(v) + 0.28 * sin(3 * u + 2 * v)), 2)
            let natural = 95 + 460 * ridges + 32 * (1 + sin(2 * u - v))
            // Clearings must repeat with the same tile period as the mountain rule.
            let nearestPad: Float = FreeRoamActivities.pads.map { pad -> Float in
                let dx = abs((x - pad.x).remainder(dividingBy: 4800))
                let dz = abs((z - pad.z).remainder(dividingBy: 4800))
                return simd_length(SIMD2<Float>(max(0, dx - 420), max(0, dz - 1600)))
            }.min() ?? 10000
            let blend = clamp(nearestPad / 350, 0, 1)
            let smooth = blend * blend * (3 - 2 * blend)
            return 190 + (natural - 190) * smooth
        }
        if level == .deathStar {
            // A broad armoured station surface with a recessed trench, rather than mountain ridges.
            let across = abs(x - valleyCenter(at: z))
            let innerWidth = 170 - difficulty(at: z) * 40
            let wall = clamp((across - innerWidth) / 94, 0, 1)
            let bevel = wall * wall * (3 - 2 * wall)
            let floor = 92 + 3 * sin(z * 0.008)
            let plating = 5 * pow(abs(sin(x * 0.043) * sin(z * 0.039)), 3)
            return floor + (410 - floor) * bevel + plating * bevel
        }
        let difficulty = difficulty(at: z)
        if level.isPodRaceTrack {
            let across = RaceCircuit(level: level).roadOffset([x, 204, z])
            let width = level.valleyWidth * 0.48
            let shoulder = 1 - exp(-pow(across / width, 4))
            return 92 + shoulder * 205

        }
        let width = (level.valleyWidth - difficulty * (level == .canyon ? 100 : 150)) * (customLevel?.valleyWidth ?? 1)
        let across = abs(x - valleyCenter(at: z))
        let ridge = 1 - exp(-pow(across / width, 1.65))
        let mountainNoise = fractal(x * 0.0018, z * 0.0018)
        let valleyFloor = 95 + 55 * sin(z * 0.00055) + 42 * fractal(x * 0.003, z * 0.003)
        // Cross-valley saddles force climbs between the checkpoint basins.
        let saddles = pow(max(0, sin(-z * 0.0021 - 0.8)), 4) * (120 + difficulty * 230) * level.saddleScale * (customLevel?.saddles ?? 1)
        return valleyFloor + ridge * (480 + mountainNoise * 680 + difficulty * 490) * level.mountainScale * (customLevel?.mountainScale ?? 1) + saddles
    }

    /// Barycentric height of the actual near-LOD triangles, rather than the smooth noise surface.
    func surfaceHeight(x: Float, z: Float) -> Float {
        let s = Self.collisionSpacing
        let x0 = floor(x / s) * s, z0 = floor(z / s) * s
        let u = (x - x0) / s, v = (z - z0) / s
        let a = height(x: x0, z: z0), b = height(x: x0 + s, z: z0)
        let c = height(x: x0, z: z0 + s), d = height(x: x0 + s, z: z0 + s)
        return u + v <= 1 ? a + (b - a) * u + (c - a) * v :
            d + (c - d) * (1 - u) + (b - d) * (1 - v)
    }

    func mesh(key: TileKey, divisions: Int) -> TerrainMeshData {
        var result = TerrainMeshData()
        let step = Self.tileSize / Float(divisions)
        let origin = SIMD2<Float>(Float(key.x) * Self.tileSize, Float(key.z) * Self.tileSize)
        // Sample once, including a shared border for continuous normals at tile edges.
        let stride = divisions + 3
        var grid: [SIMD3<Float>] = []
        for z in -1...(divisions+1) {
            for x in -1...(divisions+1) {
                let wx = origin.x+Float(x)*step, wz = origin.y+Float(z)*step
                grid.append([wx,height(x:wx,z:wz),wz])
            }
        }
        func point(_ x: Int, _ z: Int) -> SIMD3<Float> { grid[(z+1)*stride+x+1] }
        var vertexNormals: [SIMD3<Float>] = []
        for z in 0...divisions {
            for x in 0...divisions {
                vertexNormals.append(simd_normalize([point(x-1,z).y-point(x+1,z).y,2*step,point(x,z-1).y-point(x,z+1).y]))
            }
        }
        func shadingNormal(_ p: SIMD3<Float>) -> SIMD3<Float> {
            let x = Int(round((p.x-origin.x)/step)), z = Int(round((p.z-origin.y)/step))
            return vertexNormals[z*(divisions+1)+x]
        }
        func triangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, smooth: Bool = true) {
            let normal = simd_normalize(simd_cross(b - a, c - a))
            let base = UInt32(result.positions.count)
            result.positions.append(contentsOf: [a, b, c])
            result.normals.append(contentsOf:smooth ? [shadingNormal(a),shadingNormal(b),shadingNormal(c)] : [normal,normal,normal])
            // World-space projection keeps strata and surface detail continuous across tiles.
            for p in [a,b,c] {
                result.textureCoordinates.append(level == .deathStar ? SIMD2<Float>(p.x,p.z) / 120 : SIMD2<Float>(p.x + p.z * 0.24,p.y * 1.4 + p.z * 0.18) / 160)
            }
            result.indices.append(contentsOf: [base, base + 1, base + 2])
            let altitude = (a.y + b.y + c.y) / 3
            let slope = smooth ? (shadingNormal(a).y+shadingNormal(b).y+shadingNormal(c).y)/3 : normal.y
            // Hoth has continuous snow cover. Assigning altitude bands per triangle
            // drew repeated stair-step stripes across otherwise smooth snow slopes.
            let material: UInt32 = level == .alpine ? 4 : altitude > level.snowLine ? 4 : slope < 0.35 ? 3 : altitude > 570 ? 2 : altitude > 240 ? 1 : 0
            result.materials.append(material)
        }
        for z in 0..<divisions {
            for x in 0..<divisions {
                let a = point(x, z), b = point(x + 1, z), c = point(x, z + 1), d = point(x + 1, z + 1)
                triangle(a, c, b)
                triangle(b, c, d)
            }
        }
        // Downward skirts conceal T-junctions between the 25 m and 75 m grids.
        for i in 0..<divisions {
            for (a, b) in [(point(i, 0), point(i + 1, 0)), (point(divisions, i), point(divisions, i + 1)),
                           (point(i + 1, divisions), point(i, divisions)), (point(0, i + 1), point(0, i))] {
                let down = SIMD3<Float>(0, 160, 0)
                triangle(a, b, a - down, smooth:false)
                triangle(b, b - down, a - down, smooth:false)
            }
        }
        return result
    }

    private func hash(_ x: Int32, _ z: Int32) -> Float {
        var n = UInt32(bitPattern: x) &* 374761393 &+ UInt32(bitPattern: z) &* 668265263 &+ seed
        n = (n ^ (n >> 13)) &* 1274126177
        return Float((n ^ (n >> 16)) & 0x00ffffff) / Float(0x00ffffff)
    }
    private func noise(_ x: Float, _ z: Float) -> Float {
        let ix = Int32(floor(x)), iz = Int32(floor(z))
        let fx = x - floor(x), fz = z - floor(z)
        let u = fx * fx * (3 - 2 * fx), v = fz * fz * (3 - 2 * fz)
        let a = hash(ix, iz) * (1 - u) + hash(ix + 1, iz) * u
        let b = hash(ix, iz + 1) * (1 - u) + hash(ix + 1, iz + 1) * u
        return a * (1 - v) + b * v
    }
    private func fractal(_ x: Float, _ z: Float) -> Float {
        noise(x, z) * 0.57 + noise(x * 2, z * 2) * 0.28 + noise(x * 4, z * 4) * 0.15
    }
}

/// A closed racing circuit with smooth chicanes and true semicircular 180-degree hairpins.
struct RaceCircuit: Sendable {
    let radius: Float
    let straight: Float
    let chicaneAmplitude: Float
    let chicaneCount: Int
    let chicanePhase: Float
    let checkpointCount: Int
    let detourAmplitude: Float
    init(level: FlightLevel) {
        checkpointCount = max(1, level.gateCount)
        detourAmplitude = level.valleyWidth * 0.85
        radius = max(600, level.valleyWidth * 1.7)
        straight = max(1400, level.routeLength / 2 - .pi * radius)
        let raceIndex = max(0, FlightLevel.allCases.filter(\.isPodRace).firstIndex(of: level) ?? 0)
        let trackWidthScale: Float = level == .narShaddaa ? 0.40 : 0.42
        chicaneAmplitude = min(level.valleyWidth * trackWidthScale, 72 + Float(raceIndex) * 11)
        chicaneCount = 2 + raceIndex / 2
        chicanePhase = Float(level.seed % 360) * (.pi / 180)
    }
    var length: Float { 2 * straight + 2 * .pi * radius }

    // Both ends rejoin before the first checkpoint; no gate can be skipped.
    var shortcutStart: Float { 180 }
    var shortcutEnd: Float { min(straight - 80, length / Float(checkpointCount) - 80) }
    var hasShortcut: Bool { shortcutEnd > shortcutStart + 200 }
    func shortcutPoint(_ fraction: Float) -> SIMD3<Float> {
        let a = point(at: shortcutStart), b = point(at: shortcutEnd)
        return a + (b - a) * clamp(fraction, 0, 1)
    }
    func shortcutOffset(_ position: SIMD3<Float>) -> Float {
        guard hasShortcut else { return .greatestFiniteMagnitude }
        let a = shortcutPoint(0), delta = shortcutPoint(1) - a
        let t = clamp(simd_dot(position - a, delta) / max(1, simd_length_squared(delta)), 0, 1)
        let offset = position - (a + delta * t)
        return simd_length(SIMD2<Float>(offset.x, offset.z))
    }
    func roadOffset(_ position: SIMD3<Float>) -> Float {
        min(projection(position).offset, shortcutOffset(position) * 3.4)
    }

    private func chicane(_ progress: Float, returning: Bool) -> Float {
        let u = clamp(progress, 0, 1)
        let envelope = pow(sin(.pi * u), 2)
        let cycles = 2 * .pi * Float(chicaneCount) * u
        let phase = returning ? chicanePhase + 1.17 : chicanePhase
        let wave = sin(cycles + phase) + 0.34 * sin(cycles * 1.73 - phase * 0.6)
        return chicaneAmplitude * envelope * wave
    }

    func point(at distance: Float) -> SIMD3<Float> {
        var d = distance.truncatingRemainder(dividingBy: length)
        if d < 0 { d += length }
        if d < straight {
            let u = d / straight
            let t = clamp((d-shortcutStart)/max(1,shortcutEnd-shortcutStart),0,1)
            let detour = hasShortcut ? detourAmplitude * pow(sin(.pi*t),2) : 0
            return [-radius + chicane(u, returning: false) - detour, 204, -d]
        }
        d -= straight
        if d < .pi * radius {
            let a = d / radius
            return [-radius * cos(a), 204, -straight - radius * sin(a)]
        }
        d -= .pi * radius
        if d < straight {
            let u = d / straight
            return [radius + chicane(u, returning: true), 204, -straight + d]
        }
        d -= straight
        let a = d / radius
        return [radius * cos(a), 204, radius * sin(a)]
    }
    func tangent(at distance: Float) -> SIMD3<Float> {
        simd_normalize(point(at: distance + 0.5) - point(at: distance - 0.5))
    }
    func projection(_ position: SIMD3<Float>) -> (distance: Float, offset: Float) {
        func gapSquared(_ d: Float) -> Float {
            let p = point(at: d)
            let dx = position.x - p.x, dz = position.z - p.z
            return dx * dx + dz * dz
        }
        let topAngle = clamp(atan2(-(position.z + straight), -position.x), 0, .pi)
        let bottomAngle = clamp(atan2(position.z, position.x), 0, .pi)
        let candidates: [Float] = [
            clamp(-position.z, 0, straight),
            straight + topAngle * radius,
            straight + .pi * radius + clamp(position.z + straight, 0, straight),
            2 * straight + .pi * radius + bottomAngle * radius
        ]
        var best = candidates[0]
        var bestGap = gapSquared(best)
        for d in candidates.dropFirst() {
            let gap = gapSquared(d)
            if gap < bestGap { bestGap = gap; best = d }
        }
        let searchWindow = max(90, straight / Float(max(1, chicaneCount * 8)))
        var low = best - searchWindow, high = best + searchWindow
        for _ in 0..<18 {
            let third = (high - low) / 3
            let a = low + third, b = high - third
            if gapSquared(a) < gapSquared(b) { high = b } else { low = a }
        }
        var refined = ((low + high) * 0.5).truncatingRemainder(dividingBy: length)
        if refined < 0 { refined += length }
        return (refined, sqrt(gapSquared(refined)))
    }
}
