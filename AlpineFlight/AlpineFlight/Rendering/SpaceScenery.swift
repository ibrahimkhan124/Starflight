import RealityKit
import UIKit
import simd

/// Orbit scenery is prepared once. Stars and surface markings share meshes by material;
/// the only texture is a small, deterministic nebula map reused by every free-roam scene.
@MainActor
enum SpaceScenery {
    private static var nebulaTexture: TextureResource?
    private static var asteroidMeshes: [Int: MeshResource] = [:]

    private struct Batch {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        mutating func triangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
            let cross = simd_cross(b - a, c - a)
            guard simd_length_squared(cross) > 0.0000001 else { return }
            let first = UInt32(positions.count)
            positions += [a, b, c]
            normals += Array(repeating: simd_normalize(cross), count: 3)
            indices += [first, first + 1, first + 2]
        }

        mutating func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
            triangle(a, b, c)
            triangle(a, c, d)
        }

        @MainActor func mesh(name: String) -> MeshResource? {
            guard !positions.isEmpty else { return nil }
            var descriptor = MeshDescriptor(name: name)
            descriptor.positions = MeshBuffers.Positions(positions)
            descriptor.normals = MeshBuffers.Normals(normals)
            descriptor.primitives = .triangles(indices)
            return try? MeshResource.generate(from: [descriptor])
        }

        @MainActor func entity(name: String, material: any RealityKit.Material) -> ModelEntity? {
            guard let resource = mesh(name: name) else { return nil }
            let entity = ModelEntity(mesh: resource, materials: [material])
            entity.name = name
            return entity
        }
    }

    static func makeBackdrop() -> Entity {
        let root = Entity()
        root.name = "Prepared nebula and batched stars"
        var sky = UnlitMaterial(color: UIColor(red: 0.003, green: 0.006, blue: 0.019, alpha: 1))
        sky.faceCulling = .front
        if nebulaTexture == nil { nebulaTexture = makeNebulaTexture() }
        if let texture = nebulaTexture {
            sky.color = .init(tint: .white, texture: .init(texture))
        }
        let shell = ModelEntity(mesh: .generateSphere(radius: 50_000), materials: [sky])
        shell.name = "Distant violet nebula"
        root.addChild(shell)

        var batches = [Batch(), Batch(), Batch()]
        // A Fibonacci distribution avoids polar clumps and remains stable on every launch.
        for index in 0..<1_150 {
            let y = 1 - 2 * (Float(index) + 0.5) / 1_150
            let angle = Float(index) * 2.3999632
            let radial = sqrt(max(0, 1 - y * y))
            let direction = SIMD3<Float>(cos(angle) * radial, y, sin(angle) * radial)
            let center = direction * 46_500
            let reference: SIMD3<Float> = abs(y) > 0.9 ? [1, 0, 0] : [0, 1, 0]
            let right = simd_normalize(simd_cross(direction, reference))
            let up = simd_normalize(simd_cross(right, direction))
            let bright = index.isMultiple(of: 79)
            let size: Float = 10*(bright ? 8.4 : 1.3 + hash(index, 47) * 2.7)
            let group = index % 11 == 0 ? 1 : index % 17 == 0 ? 2 : 0
            batches[group].quad(center + up * size, center + right * size,
                                center - up * size, center - right * size)
            if bright {
                batches[group].quad(center + up * size * 2.8, center + right * size * 0.14,
                                    center - up * size * 2.8, center - right * size * 0.14)
                batches[group].quad(center + right * size * 2.1, center + up * size * 0.14,
                                    center - right * size * 2.1, center - up * size * 0.14)
            }
        }
        let colors = [UIColor(red:0.92,green:0.95,blue:1,alpha:1),
                      UIColor(red:0.65,green:0.8,blue:1,alpha:1),
                      UIColor(red:1,green:0.65,blue:0.35,alpha:1)]
        for index in batches.indices {
            var material = UnlitMaterial(color: colors[index])
            material.faceCulling = .none
            if let stars = batches[index].entity(name: "Batched stars \(index)", material: material) {
                root.addChild(stars)
            }
        }
        return root
    }

    /// Prebuilt white coma and soft, fading ice/dust ribbons. Only transforms change in flight.
    static func makePlanetComets(reducedDetail:Bool) -> Entity {
        let root = Entity(); root.name = "Planet comet pool"
        let headMesh = MeshResource.generateSphere(radius:PlanetComet.radius)
        for _ in 0..<(reducedDetail ? 2:3) {
            let comet = Entity()
            let core = ModelEntity(mesh:headMesh,materials:[UnlitMaterial(color:.white)])
            comet.addChild(core)
            // Narrow blue ion tail and a curved dust fan fade across four prepared bands.
            for band in 0..<4 {
                var batch = Batch()
                let t0 = Float(band)/4, t1 = Float(band+1)/4
                for layer in 0..<2 {
                    let length:Float = layer == 0 ? 230:170
                    let width:Float = layer == 0 ? 10:24
                    let bend:Float = layer == 0 ? 0:42
                    let a = SIMD3<Float>(bend*t0*t0,0,t0*length)
                    let b = SIMD3<Float>(bend*t1*t1,0,t1*length)
                    let wa = (1-t0)*width, wb = max(0.2,(1-t1)*width)
                    batch.quad(a+[-wa,0,0],a+[wa,0,0],b+[wb,0,0],b+[-wb,0,0])
                    batch.quad(a+[0,-wa,0],a+[0,wa,0],b+[0,wb,0],b+[0,-wb,0])
                }
                var material = UnlitMaterial(color:UIColor(red:0.35+CGFloat(band)*0.08,green:0.7,blue:1,alpha:1))
                material.faceCulling = .none
                material.blending = .transparent(opacity:.init(floatLiteral:0.32-Float(band)*0.075))
                if let tail = batch.entity(name:"Fading comet tail",material:material) { comet.addChild(tail) }
            }
            var halo = UnlitMaterial(color:.cyan)
            halo.blending = .transparent(opacity:.init(floatLiteral:0.12)); halo.faceCulling = .none
            let coma = ModelEntity(mesh:.generateSphere(radius:12),materials:[halo]); comet.addChild(coma)
            comet.isEnabled = false; root.addChild(comet)
        }
        return root
    }

    static func updatePlanetComets(_ root:Entity,comets:[PlanetComet]) {
        for (index,entity) in root.children.enumerated() {
            entity.isEnabled = index<comets.count
            guard index<comets.count else { continue }
            let comet = comets[index]
            entity.position = comet.position
            if simd_length_squared(comet.velocity)>0.01 { entity.orientation = simd_quatf(from:[0,0,-1],to:simd_normalize(comet.velocity)) }
        }
    }

    /// Colored strata, polar ice, cloud wisps and city lights sit on the same grid
    /// as PlanetSurfaceMesh. They introduce no unmodelled solid obstacles in orbit.
    static func decoratePlanet(_ planet: SpacePlanet, root: Entity) {
        let decoration = Entity()
        decoration.name = planet.name + " orbital detail"
        var dark = Batch(), light = Batch(), accent = Batch(), clouds = Batch()
        var cyan = Batch(), amber = Batch()
        let latitudeCount = SpacePlanet.latitudeSegments
        let longitudeCount = SpacePlanet.longitudeSegments

        for latitude in 1..<(latitudeCount - 1) {
            let lat = Float(latitude) / Float(latitudeCount) * .pi
            for longitude in 0..<longitudeCount {
                let lon = Float(longitude) / Float(longitudeCount) * 2 * .pi
                let corners = surfaceCell(planet, latitude: latitude, longitude: longitude)
                let drift = sin(lon * 3 + sin(lat * 4) * 1.7)
                    + 0.48 * sin(lon * 7 - lat * 9) + 0.23 * cos(lon * 13 + lat * 17)

                if planet == .coruscant {
                    // A few district sizes and warm/cool light runs break up the uniform globe.
                    if (latitude + longitude).isMultiple(of: 3) {
                        patch(&dark, corners, u0: 0.08, v0: 0.08, u1: 0.92, v1: 0.92)
                    }
                    if latitude.isMultiple(of: 3) || longitude.isMultiple(of: 5) {
                        patch(&cyan, corners, u0: 0.12, v0: 0.42, u1: 0.86, v1: 0.49)
                    }
                    if (latitude * 11 + longitude * 7).isMultiple(of: 8) {
                        patch(&amber, corners, u0: 0.43, v0: 0.14, u1: 0.53, v1: 0.86)
                        patch(&amber, corners, u0: 0.25, v0: 0.65, u1: 0.34, v1: 0.76)
                    }
                    if latitude.isMultiple(of: 7) && longitude.isMultiple(of: 7) {
                        patch(&cyan, corners, u0: 0.3, v0: 0.28, u1: 0.72, v1: 0.7)
                    }
                } else {
                    switch planet {
                    case .tatooine:
                        if drift > 0.35 { patch(&dark, corners) }
                        else if drift < -0.45 { patch(&light, corners) }
                        let ripples = sin(lon * 19 + lat * 31 + drift * 3)
                        if ripples > 0.64 && drift > -0.65 {
                            patch(&accent, corners, u0: 0, v0: 0.38, u1: 1, v1: 0.62)
                        }
                    case .hoth:
                        if abs(cos(lat)) > 0.53 || drift > 0.5 { patch(&light, corners) }
                        else if drift < -0.25 { patch(&dark, corners) }
                        if sin(lon * 13 + lat * 17 + drift * 0.8) > 0.9 {
                            patch(&accent, corners, u0: 0, v0: 0.3, u1: 1, v1: 0.48)
                        }
                    case .endor:
                        if drift > 0.2 { patch(&dark, corners) }
                        else if drift < -0.55 { patch(&light, corners) }
                        if abs(sin(lon * 5 - lat * 9)) > 0.94 && drift < 0.7 {
                            patch(&accent, corners, u0: 0.15, v0: 0.15, u1: 0.85, v1: 0.85)
                        }
                    case .coruscant: break
                    }

                    // Only a small fraction of cells carry translucent cloud wisps.
                    // These are atmosphere rather than new collision geometry.
                    let cloud = sin(lon * 4 + lat * 9) + 0.38 * sin(lon * 11 - lat * 19)
                    if planet != .tatooine && cloud > 1.08 && latitude % 2 == 0 {
                        let raised = corners.map { $0 + simd_normalize($0) * 7 }
                        patch(&clouds, raised, u0: 0.02, v0: 0.1, u1: 0.98, v1: 0.85)
                    }
                }
            }
        }

        let palette: [UIColor]
        switch planet {
        case .tatooine:
            palette = [UIColor(red: 0.47, green: 0.23, blue: 0.1, alpha: 1),
                       UIColor(red: 0.91, green: 0.69, blue: 0.34, alpha: 1),
                       UIColor(red: 0.7, green: 0.39, blue: 0.17, alpha: 1)]
        case .hoth:
            palette = [UIColor(red: 0.29, green: 0.49, blue: 0.65, alpha: 1),
                       UIColor(red: 0.92, green: 0.97, blue: 1, alpha: 1),
                       UIColor(red: 0.43, green: 0.7, blue: 0.82, alpha: 1)]
        case .endor:
            palette = [UIColor(red: 0.035, green: 0.18, blue: 0.09, alpha: 1),
                       UIColor(red: 0.24, green: 0.43, blue: 0.17, alpha: 1),
                       UIColor(red: 0.35, green: 0.35, blue: 0.24, alpha: 1)]
        case .coruscant:
            palette = [UIColor(red: 0.08, green: 0.1, blue: 0.18, alpha: 1), .gray, .gray]
        }
        for (index, batch) in [dark, light, accent].enumerated() {
            var material = SimpleMaterial(color: palette[index], roughness: 1, isMetallic: false)
            material.faceCulling = .none
            if let entity = batch.entity(name: planet.name + " surface region \(index)", material: material) {
                decoration.addChild(entity)
            }
        }
        if planet == .coruscant {
            for (index, batch) in [cyan, amber].enumerated() {
                var material = UnlitMaterial(color: index == 0
                    ? UIColor(red: 0.12, green: 0.76, blue: 1, alpha: 1)
                    : UIColor(red: 1, green: 0.58, blue: 0.16, alpha: 1))
                material.faceCulling = .none
                if let lights = batch.entity(name: "Coruscant district lights \(index)", material: material) {
                    decoration.addChild(lights)
                }
            }
        } else {
            var cloudMaterial = UnlitMaterial(color: UIColor(white: 0.91, alpha: 0.28))
            cloudMaterial.faceCulling = .none
            if let cloudLayer = clouds.entity(name: planet.name + " cloud wisps", material: cloudMaterial) {
                decoration.addChild(cloudLayer)
            }
        }
        root.addChild(decoration)
    }

    /// All six rocks are closed icospheres, sculpted inside the physical unit sphere.
    /// Flat face normals expose the craters without increasing runtime entity count.
    static func asteroidMesh(variant: Int) -> MeshResource {
        let key = ((variant % 6) + 6) % 6
        if let resource = asteroidMeshes[key] { return resource }
        let golden: Float = (1 + sqrt(5)) / 2
        var vertices: [SIMD3<Float>] = [
            [-1, golden, 0], [1, golden, 0], [-1, -golden, 0], [1, -golden, 0],
            [0, -1, golden], [0, 1, golden], [0, -1, -golden], [0, 1, -golden],
            [golden, 0, -1], [golden, 0, 1], [-golden, 0, -1], [-golden, 0, 1]
        ].map(simd_normalize)
        var faces: [[Int]] = [[0,11,5], [0,5,1], [0,1,7], [0,7,10], [0,10,11],
                             [1,5,9], [5,11,4], [11,10,2], [10,7,6], [7,1,8],
                             [3,9,4], [3,4,2], [3,2,6], [3,6,8], [3,8,9],
                             [4,9,5], [2,4,11], [6,2,10], [8,6,7], [9,8,1]]
        for _ in 0..<2 {
            var midpointCache: [UInt64: Int] = [:]
            func midpoint(_ a: Int, _ b: Int) -> Int {
                let edge = UInt64(min(a, b)) << 32 | UInt64(max(a, b))
                if let index = midpointCache[edge] { return index }
                let index = vertices.count
                vertices.append(simd_normalize(vertices[a] + vertices[b]))
                midpointCache[edge] = index
                return index
            }
            var subdivided: [[Int]] = []
            for face in faces {
                let a = face[0], b = face[1], c = face[2]
                let ab = midpoint(a, b), bc = midpoint(b, c), ca = midpoint(c, a)
                subdivided += [[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]]
            }
            faces = subdivided
        }
        let craters: [SIMD3<Float>] = (0..<5).map { index in
            let y = hash(index + key * 13, 43) * 1.8 - 0.9
            let angle = hash(index + key * 17, 131) * 2 * .pi
            let ring = sqrt(1 - y * y)
            return [cos(angle) * ring, y, sin(angle) * ring]
        }
        for index in vertices.indices {
            let direction = vertices[index]
            let phase = Float(key) * 1.7
            var radius: Float = 0.88 + sin(direction.x * 6 + phase) * cos(direction.y * 7 - phase) * 0.065
                + sin(direction.z * 11 + direction.x * 5) * 0.035
            for crater in craters {
                let alignment = simd_dot(direction, crater)
                let bowl = max(0, (alignment - 0.86) / 0.14)
                radius -= bowl * bowl * 0.17
            }
            vertices[index] = direction * min(0.99, max(0.64, radius))
        }
        var batch = Batch()
        for face in faces {
            let a = vertices[face[0]], b = vertices[face[1]], c = vertices[face[2]]
            if simd_dot(simd_cross(b - a, c - a), a + b + c) > 0 { batch.triangle(a, b, c) }
            else { batch.triangle(a, c, b) }
        }
        let resource = batch.mesh(name: "Closed cratered asteroid \(key)") ?? .generateSphere(radius: 0.92)
        asteroidMeshes[key] = resource
        return resource
    }

    private static func surfaceCell(_ planet: SpacePlanet, latitude: Int, longitude: Int) -> [SIMD3<Float>] {
        let grid = [(latitude, longitude), (latitude, longitude + 1),
                    (latitude + 1, longitude + 1), (latitude + 1, longitude)]
        let districtHeight = planet.height(latitude: latitude, longitude: longitude)
        return grid.map { i, j in
            let lat = Float(i) * .pi / Float(SpacePlanet.latitudeSegments)
            let lon = Float(j) * 2 * .pi / Float(SpacePlanet.longitudeSegments)
            let direction = SIMD3<Float>(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon))
            let height = planet == .coruscant ? districtHeight : planet.height(latitude: i, longitude: j)
            return direction * (planet.radius + height + 0.28)
        }
    }

    private static func patch(_ batch: inout Batch, _ corners: [SIMD3<Float>],
                              u0: Float = 0, v0: Float = 0, u1: Float = 1, v1: Float = 1) {
        // Interpolate the actual pair of triangles, rather than a smoother sphere.
        func point(_ u: Float, _ v: Float) -> SIMD3<Float> {
            u >= v
                ? corners[0] * (1 - u) + corners[1] * (u - v) + corners[2] * v
                : corners[0] * (1 - v) + corners[2] * u + corners[3] * (v - u)
        }
        batch.quad(point(u0, v0), point(u1, v0), point(u1, v1), point(u0, v1))
    }

    private static func hash(_ value: Int, _ salt: Int) -> Float {
        var bits = UInt32(truncatingIfNeeded: value) &* 747_796_405 &+ UInt32(salt)
        bits = ((bits >> ((bits >> 28) + 4)) ^ bits) &* 277_803_737
        bits = (bits >> 22) ^ bits
        return Float(bits & 0x00ff_ffff) / Float(0x00ff_ffff)
    }

    private static func makeNebulaTexture() -> TextureResource? {
        let width = 1_024, height = 512
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let axis = simd_normalize(SIMD3<Float>(0.42, 0.8, -0.44))
        let cloudCenter = simd_normalize(SIMD3<Float>(-0.8, 0.1, -0.5))
        let secondCenter = simd_normalize(SIMD3<Float>(0.65, -0.35, 0.45))
        for y in 0..<height {
            let lat = Float(y) / Float(height - 1) * .pi
            for x in 0..<width {
                let lon = Float(x) / Float(width - 1) * 2 * .pi
                let direction = SIMD3<Float>(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon))
                let band = exp(-pow(simd_dot(direction, axis) * 3.8, 2))
                let folds = sin(direction.x * 11 + direction.z * 7 + sin(direction.y * 9))
                let wisps = sin(direction.z * 31 + direction.y * 19 + folds * 2)
                    * cos(direction.x * 23 - direction.y * 17)
                let dust = max(0, 0.45 + folds * 0.3 + wisps * 0.23)
                let violet = pow(max(0, simd_dot(direction, cloudCenter)), 4)
                let blue = pow(max(0, simd_dot(direction, secondCenter)), 6)
                let glow = band * dust
                let color = SIMD3<Float>(0.004, 0.007, 0.023)
                    + SIMD3<Float>(0.083, 0.033, 0.14) * glow
                    + SIMD3<Float>(0.09, 0.018, 0.08) * violet * glow
                    + SIMD3<Float>(0.018, 0.063, 0.1) * blue * dust
                let offset = (y * width + x) * 4
                pixels[offset] = UInt8(min(255, max(0, color.x * 255)))
                pixels[offset + 1] = UInt8(min(255, max(0, color.y * 255)))
                pixels[offset + 2] = UInt8(min(255, max(0, color.z * 255)))
                pixels[offset + 3] = 255
            }
        }
        return pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let image = context.makeImage() else { return nil }
            return try? TextureResource(image: image, options: .init(semantic: .color))
        }
    }
}
