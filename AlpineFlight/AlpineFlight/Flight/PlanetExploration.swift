import Foundation
import simd

/// One deterministic map supplies both the prepared scenery and collision queries.
struct PlanetExploration {
    struct Obstacle {
        let center: SIMD3<Float>
        let size: SIMD3<Float>
        let style: Int
        var yaw: Float = 0
        func hits(_ point: SIMD3<Float>, radius: Float) -> Bool {
            let delta = point-center
            let local = SIMD3<Float>(cos(yaw)*delta.x-sin(yaw)*delta.z,delta.y,sin(yaw)*delta.x+cos(yaw)*delta.z)
            let closest = simd_clamp(local,-size/2,size/2)
            return simd_distance_squared(local,closest) <= radius*radius
        }
    }
    struct CityTunnel {
        let center: SIMD3<Float>
        let buildingSize: SIMD3<Float>
        let openingWidth: Float
        let openingBottom: Float = 60
        let openingHeight: Float = 100
        var flightCenter: SIMD3<Float> { [center.x,openingBottom+openingHeight/2,center.z] }
        static let depth: Float = 820
        static let segments = 32
        /// A smooth S bend with straight, level mouths at both ends.
        var path: [SIMD3<Float>] {
            (0...Self.segments).map { index in
                let t = Float(index)/Float(Self.segments)
                return flightCenter+SIMD3<Float>(170*sin(t*2 * .pi)*pow(sin(t * .pi),2),0,(0.5-t)*Self.depth)
            }
        }
        var routeLength: Float { zip(path,path.dropFirst()).reduce(0) { $0+simd_distance($1.0,$1.1) } }
        /// Every wall segment is an oriented box shared by rendering and collision.
        var solids: [Obstacle] {
            let points = path, low = center.y-buildingSize.y/2, high = center.y+buildingSize.y/2
            let side = (buildingSize.x-openingWidth)/2
            var result: [Obstacle] = []
            for (a,b) in zip(points,points.dropFirst()) {
                let middle = (a+b)/2, yaw = atan2(b.x-a.x,b.z-a.z)
                let length = simd_distance(a,b)+4
                let right = SIMD3<Float>(cos(yaw),0,-sin(yaw))
                result.append(Obstacle(center:[middle.x,(low+openingBottom)/2,middle.z],size:[buildingSize.x,openingBottom-low,length],style:4,yaw:yaw))
                result.append(Obstacle(center:[middle.x,(openingBottom+openingHeight+high)/2,middle.z],size:[buildingSize.x,high-openingBottom-openingHeight,length],style:4,yaw:yaw))
                for sign:Float in [-1,1] {
                    result.append(Obstacle(center:middle+right*sign*(openingWidth+side)/2,size:[side,openingHeight,length],style:4,yaw:yaw))
                }
            }
            return result
        }
    }
    static let cityTunnels: [CityTunnel] = {
        var tunnels: [CityTunnel] = []
        for i in stride(from:-16,through:16,by:8) {
            for j in Array(stride(from:-18,through:18,by:6))+[16] {
                let x = (Float(i)+0.5)*spacing, z = (Float(j)+0.5)*spacing
                let variation = abs(sin(Float(i*127+j*311)))
                let district = 0.5+0.5*cos(x*0.0004)*sin(z*0.0003)
                let height = max(300,100+variation*520+district*160)
                let width = max(220,150+variation*100)
                tunnels.append(CityTunnel(center:[x,height/2-6,z],buildingSize:[width,height,width],openingWidth:150))
            }
        }
        return tunnels.filter { !CityPlot.clears(center:$0.center,size:$0.buildingSize+[400,0,600]) }
    }()
    var tunnels: [CityTunnel] { planet == .coruscant ? Self.cityTunnels : [] }
    struct Landmark {
        let name: String
        let position: SIMD3<Float>
    }
    let planet: SpacePlanet
    static let extent: Float = 12000
    static let grid = 160
    static let spacing: Float = 480
    static let step = extent * 2 / Float(grid)

    var name: String {
        switch planet {
        case .coruscant: return "Neon skyline run"
        case .tatooine: return "Dune explorer"
        case .hoth: return "Ice reconnaissance"
        case .endor: return "Forest scout"
        }
    }
    var landmarks: [Landmark] {
        let names: [String]
        switch planet {
        case .coruscant: names = ["Spaceport", "Neon avenue", "Senate district", "Reactor towers", "Skyline overlook", "Market district"]
        case .tatooine: names = ["Jawa trading camp", "Dune sea", "Canyon lookout", "Rock spires", "Remote settlement", "Sunset basin"]
        case .hoth: names = ["Wampa territory", "Ice shelf", "Frozen pass", "Glacier ridge", "Research outpost", "Snow basin"]
        case .endor: names = ["Ewok village", "Canopy trail", "Woodland ridge", "Ancient grove", "Scout camp", "Forest overlook"]
        }
        let route: [SIMD2<Float>] = [[0, 4800], [1920, 4800], [1920, -1920], [-1920, -1920], [-1920, 6720], [0, 6720]]
        var destinations = zip(names, route).map { name, point in
            Landmark(name: name, position: [point.x, groundHeight(x: point.x, z: point.y) + 260, point.y])
        }
        if planet == .coruscant, let tunnel = tunnels.min(by:{ simd_distance($0.flightCenter,[0,110,8400]) < simd_distance($1.flightCenter,[0,110,8400]) }) {
            destinations[1] = Landmark(name:"Neon tower tunnel",position:tunnel.flightCenter)
        }
        return destinations
    }
    // Endor enters between the high crowns in the cleared arrival corridor;
    // giant trunks frame the approach without placing the aircraft inside a tree.
    var arrival: SIMD3<Float> { [0, groundHeight(x: 0, z: 8400) + (planet == .endor ? 480:320), 8400] }

    /// Broad, non-repeating landforms. The renderer and contact checks sample this
    /// same field; visual canyons, glacier rifts and approaches cannot drift apart.
    func canyonCenter(z: Float) -> Float {
        let bend = 1420 * sin(z * 0.00032) + 560 * sin(z * 0.00071 + 0.7)
        return bend * (1 - exp(-pow((z - 8400) / 1800, 2)))
    }
    func glacierCenter(z: Float) -> Float {
        850 * sin(z * 0.00027 + 0.4) + 280 * sin(z * 0.00061)
    }
    /// A shallow branching crevasse field, also available to the surface palette.
    func glacierRift(x: Float, z: Float) -> Float {
        let across = x - glacierCenter(z: z)
        let valley = exp(-pow(across / 1300, 4))
        var rift: Float = 0
        for (index, center): (Int, Float) in [-6300, -2850, 1650, 5100].enumerated() {
            let diagonal = center + across * (index.isMultiple(of: 2) ? 0.28 : -0.22)
            let bend = 95 * sin(across * 0.0021 + Float(index))
            let distance = (z - diagonal - bend) / 170
            rift = max(rift, exp(-distance * distance) * valley)
        }
        return rift
    }
    private func landNoise(_ x: Float, _ z: Float, seed: Float) -> Float {
        let ix = floor(x), iz = floor(z), u = x - ix, v = z - iz
        let sx = u * u * (3 - 2 * u), sz = v * v * (3 - 2 * v)
        func hash(_ a: Float, _ b: Float) -> Float {
            let value = sin(a * 127.1 + b * 311.7 + seed * 17.17) * 43758.5453
            return (value - floor(value)) * 2 - 1
        }
        let lower = hash(ix, iz) * (1 - sx) + hash(ix + 1, iz) * sx
        let upper = hash(ix, iz + 1) * (1 - sx) + hash(ix + 1, iz + 1) * sx
        return lower * (1 - sz) + upper * sz
    }
    private func ridgedRelief(x: Float, z: Float, scale: Float) -> Float {
        let wx = x + landNoise(x / 4900 + 17, z / 4900 - 9, seed: 41) * 650
        let wz = z + landNoise(x / 4900 - 23, z / 4900 + 31, seed: 53) * 650
        let broad = pow(1 - abs(landNoise(wx / scale, wz / scale, seed: 11)), 3)
        let branch = pow(1 - abs(landNoise(wx / scale * 2.03 + 7, wz / scale * 2.03 - 5, seed: 29)), 3)
        return broad * 0.74 + branch * 0.26
    }
    private func smoothEdge(_ low: Float, _ high: Float, _ value: Float) -> Float {
        let t = clamp((value - low) / (high - low), 0, 1)
        return t * t * (3 - 2 * t)
    }

    /// Terrain vertices. Coruscant stays flat for its existing jobs and tunnels.
    func vertexHeight(x: Float, z: Float) -> Float {
        guard planet != .coruscant else { return 0 }
        let wx = x + landNoise(x / 4300 + 13, z / 4300 - 7, seed: 47) * 420
        let wz = z + landNoise(x / 4300 - 19, z / 4300 + 23, seed: 59) * 420
        let broad = landNoise(wx / 2600, wz / 2600, seed: 3)
        let folds = landNoise(wx / 980, wz / 980, seed: 17)
        let detail = landNoise(wx / 370, wz / 370, seed: 31)
        let height: Float
        switch planet {
        case .coruscant: return 0
        case .tatooine:
            let across = abs(x - canyonCenter(z: z))
            let width = 580 + 110 * landNoise(z / 2000, 1, seed: 5)
            let wall = smoothEdge(width, width + 640, across)
            // Rounded erosion terraces rather than square steps on the canyon walls.
            let terrace = 0.055 * sin(wall * .pi * 8) * sin(wall * .pi)
            let mesa = 820 + 390 * (broad + 1) * 0.5 + 190 * ridgedRelief(x: x, z: z, scale: 2800) + folds * 65
            let dunes = 28 * sin(x * 0.0016 + sin(z * 0.00052))
                + 13 * sin(z * 0.0012 + x * 0.00065) + detail * 14
            height = 95 + (wall + terrace) * mesa + dunes * (1 - wall * 0.65)
        case .hoth:
            let across = abs(x - glacierCenter(z: z))
            let shoulder = smoothEdge(760, 2250, across)
            let ranges = 570 + 1000 * ridgedRelief(x: x, z: z, scale: 2600) + 380 * (broad + 1) * 0.5
            let iceFlow = 28 * sin(z * 0.00031 + x * 0.00015) + detail * 15
            height = 150 + shoulder * ranges + iceFlow - 92 * glacierRift(x: x, z: z)
        case .endor:
            let valley = exp(-pow((x - 1000 * sin(z * 0.00025)) / 1500, 2))
            let hills = 320 * (broad + 1) * 0.5 + 150 * folds + detail * 24
            let distantRidges = smoothEdge(2600, 6300, abs(x)) * (590 + 490 * ridgedRelief(x: x, z: z, scale: 3200) + 110 * (broad + 1) * 0.5)
            height = 135 + hills + distantRidges - valley * 85
        }
        // A local cleared arrival preserves a gentle first approach without making
        // an artificial flat stripe all the way across the region.
        let arrival = exp(-pow(x / 620, 2) - pow((z - 8400) / 1300, 2))
        return max(38, height * (1 - arrival) + 70 * arrival)
    }
    var orbitAltitude: Float { planet == .coruscant ? 1400 : 3200 }

    /// Exactly the same two triangles used by the visible ground mesh.
    func groundHeight(x: Float, z: Float) -> Float {
        let gx = clamp((x + Self.extent) / Self.step, 0, Float(Self.grid))
        let gz = clamp((z + Self.extent) / Self.step, 0, Float(Self.grid))
        let i = min(floor(gx), Float(Self.grid - 1)), j = min(floor(gz), Float(Self.grid - 1))
        let u = gx - i, v = gz - j
        let x0 = -Self.extent + i * Self.step, z0 = -Self.extent + j * Self.step
        let a = vertexHeight(x: x0, z: z0), b = vertexHeight(x: x0, z: z0 + Self.step)
        let c = vertexHeight(x: x0 + Self.step, z: z0 + Self.step), d = vertexHeight(x: x0 + Self.step, z: z0)
        return v >= u ? a * (1 - v) + b * (v - u) + c * u : a * (1 - u) + c * v + d * (u - v)
    }
    private static let cachedObstacles = Dictionary(uniqueKeysWithValues:
        SpacePlanet.allCases.map { ($0, PlanetExploration(planet: $0).generateObstacles()) })
    var obstacles: [Obstacle] { Self.cachedObstacles[planet] ?? [] }
    // A spatial hash bounds collision work as the map grows.
    private static let obstacleBins: [SpacePlanet: [SIMD2<Int>: [Obstacle]]] = Dictionary(uniqueKeysWithValues:
        SpacePlanet.allCases.map { planet in
            let groups = Dictionary(grouping: cachedObstacles[planet] ?? []) {
                SIMD2<Int>(Int(floor($0.center.x / spacing)), Int(floor($0.center.z / spacing)))
            }
            return (planet, groups)
        })
    private func generateObstacles() -> [Obstacle] {
        var result: [Obstacle] = []
        let clearings = landmarks.map { SIMD2<Float>($0.position.x, $0.position.z) }
        for i in -24..<24 {
            for j in -24..<24 {
                // Break the forest's planting grid while keeping every tree in a
                // deterministic cell, so preparation and collision share positions.
                let jitterX = planet == .endor ? landNoise(Float(i) * 1.73, Float(j) * 2.31, seed: 61) * 100 : 0
                let jitterZ = planet == .endor ? landNoise(Float(i) * 2.47, Float(j) * 1.19, seed: 83) * 100 : 0
                let x = (Float(i) + 0.5) * Self.spacing + jitterX
                let z = (Float(j) + 0.5) * Self.spacing + jitterZ
                if planet == .coruscant && Self.cityTunnels.contains(where:{ abs($0.center.x-x)<600 && abs($0.center.z-z)<CityTunnel.depth/2+240 }) { continue }
                let variation = abs(sin(Float(i * 127 + j * 311)))
                if planet != .coruscant {
                    let threshold: Float = planet == .endor ? 0.38 : planet == .hoth ? 0.62 : 0.7
                    if variation < threshold { continue }
                    // Clear the initial descent and the six activity beacons. Their
                    // pads and markers remain useful places to turn or descend.
                    if abs(x) < 700 && abs(z - 8400) < 1350 { continue }
                    if clearings.contains(where: { simd_distance(SIMD2<Float>(x, z), $0) < 300 }) { continue }
                    if planet == .tatooine && abs(x - canyonCenter(z: z)) < 1050 { continue }
                }
                let height: Float, width: Float
                switch planet {
                case .coruscant:
                    let district = 0.5 + 0.5 * cos(x * 0.0004) * sin(z * 0.0003)
                    height = 100 + variation * 520 + district * 160; width = 150 + variation * 100
                case .tatooine: height = 55 + variation * 175; width = 100 + variation * 80
                case .hoth:
                    let inGlacier = abs(x - glacierCenter(z: z)) < 1200
                    height = inGlacier ? 24 + variation * 75 : 65 + variation * 180
                    width = inGlacier ? 65 + variation * 55 : 110 + variation * 70
                case .endor: height = 430 + variation * 250; width = 100 + variation * 60
                }
                if planet == .coruscant && CityPlot.clears(center:[x,0,z],size:[width,height,width]) { continue }
                // Seat the base into the highest corner, keeping the whole obstacle above terrain.
                let half = width / 2
                let ground = max(groundHeight(x: x - half, z: z - half), groundHeight(x: x + half, z: z + half),
                                 groundHeight(x: x - half, z: z + half), groundHeight(x: x + half, z: z - half))
                result.append(Obstacle(center: [x, ground + height / 2 - 6, z], size: [width, height, width], style: abs(i + j) % 3))
            }
        }
        if planet == .coruscant { result.append(contentsOf:Self.cityTunnels.flatMap(\.solids)) }
        for landmark in landmarks {
            let p = landmark.position
            let ground = groundHeight(x:p.x,z:p.z)
            for side: Float in [-1,1] {
                result.append(Obstacle(center:[p.x+side*65,ground+18,p.z],size:[35,36,45],style:3))
            }
        }
        return result
    }
    func clearance(at point: SIMD3<Float>) -> Float { point.y - groundHeight(x: point.x, z: point.z) }
    func hitsObstacle(at point: SIMD3<Float>, radius: Float) -> Bool {
        let bx = Int(floor(point.x / Self.spacing)), bz = Int(floor(point.z / Self.spacing))
        let reach = max(1, Int(ceil((radius + 130) / Self.spacing)))
        for x in (bx - reach)...(bx + reach) {
            for z in (bz - reach)...(bz + reach) {
                for obstacle in Self.obstacleBins[planet]?[SIMD2<Int>(x, z)] ?? [] {
                    if obstacle.hits(point,radius:radius) { return true }
                }
            }
        }
        return false
    }
}
