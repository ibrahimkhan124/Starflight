import RealityKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor
final class TerrainRenderer {
    let root = Entity()
    let generator: TerrainGenerator
    private struct MaterialBinding {
        let entity: ModelEntity
        let originals: [any Material]
    }
    private struct Tile {
        let entity: Entity
        let divisions: Int
        let authored: Bool
        var bindings: [MaterialBinding] = []
        var fogBand: Int = -1
    }
    private var tiles: [TileKey: Tile] = [:]
    private var generation: Task<Void, Never>?
    private var revision = 0
    private let emptyRegion: Bool
    private var scenery: Entity?
    private var surfaceMaterials: [any RealityKit.Material]?
    private(set) var ready = false
    private(set) var progress: Float = 0
    private(set) var preparedReducedDetail: Bool?
    private(set) var failure: String?
    var fogColor: UIColor { UIColor(rgb: generator.level.fogColor) }

    init(generator: TerrainGenerator, emptyRegion: Bool = false) {
        self.generator = generator
        self.emptyRegion = emptyRegion
        root.isEnabled = false
        if emptyRegion { ready = true; progress = 1 }
    }

    static func assetURL(level: FlightLevel, key: TileKey, divisions: Int) -> URL? {
        // Shipping thousands of pre-baked tiles made the iPad app larger than 850 MB.
        // The deterministic generator below produces collision-aligned low-poly regions
        // on demand, so release builds only bundle the compact aircraft models.
        nil
    }

    func stop() { generation?.cancel(); generation = nil }

    func update(position: SIMD3<Float>, reducedDetail: Bool) {
        guard generation == nil, !ready else { return }
        scheduleRegion(reducedDetail: reducedDetail)
    }

    func restart(reducedDetail: Bool) {
        guard !emptyRegion, preparedReducedDetail != reducedDetail else { return }
        generation?.cancel()
        generation = nil
        scheduleRegion(reducedDetail: reducedDetail)
    }

    private func scheduleRegion(reducedDetail: Bool) {
        generation?.cancel()
        revision += 1
        let currentRevision = revision
        ready = false
        progress = 0
        failure = nil
        preparedReducedDetail = reducedDetail
        scenery?.removeFromParent()
        scenery = nil
        root.isEnabled = false
        for tile in tiles.values { tile.entity.removeFromParent() }
        tiles.removeAll()
        let divisions = reducedDetail ? 16 : 24
        let needed = Self.regionKeys(for: generator.level).map { ($0, divisions) }
        let generator = self.generator
        generation = Task { [weak self] in
            for (index, item) in needed.enumerated() {
                let (key, divisions) = item
                guard !Task.isCancelled else { return }
                if let url = Self.assetURL(level: generator.level, key: key, divisions: divisions) {
                    guard let self, self.revision == currentRevision else { return }
                    do {
                        let entity = try await Entity(contentsOf: url)
                        guard !Task.isCancelled, self.revision == currentRevision else { return }
                        entity.position = [Float(key.x) * TerrainGenerator.tileSize, 0, Float(key.z) * TerrainGenerator.tileSize]
                        self.tiles.removeValue(forKey: key)?.entity.removeFromParent()
                        self.root.addChild(entity)
                        self.tiles[key] = Tile(entity: entity, divisions: divisions, authored: true, bindings: self.materialBindings(in: entity))
                    } catch {
                        guard !Task.isCancelled, self.revision == currentRevision else { return }
                        self.failure = "Blender terrain could not load: \(error.localizedDescription)"
                        return
                    }
                    await Task.yield()
                    continue
                }
                // Story-route outskirts remain explorable beyond the authored course boundary.
                let data = await Task.detached(priority: .userInitiated) { generator.mesh(key: key, divisions: divisions) }.value
                guard !Task.isCancelled, let self, self.revision == currentRevision else { return }
                do {
                    var descriptor = MeshDescriptor(name: "mountain-\(key.x)-\(key.z)")
                    descriptor.positions = MeshBuffers.Positions(data.positions)
                    descriptor.normals = MeshBuffers.Normals(data.normals)
                    descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(data.textureCoordinates)
                    descriptor.primitives = .triangles(data.indices)
                    descriptor.materials = .perFace(data.materials)
                    let entity = ModelEntity(mesh: try MeshResource.generate(from: [descriptor]), materials: self.materials(fog: 0))
                    self.tiles.removeValue(forKey: key)?.entity.removeFromParent()
                    self.root.addChild(entity)
                    self.tiles[key] = Tile(entity: entity, divisions: divisions, authored: false)
                } catch {
                    self.failure = "Terrain could not be created: \(error.localizedDescription)"
                    return
                }
                self.progress = Float(index + 1) / Float(max(needed.count, 1))
                await Task.yield()
            }
            guard let self, self.revision == currentRevision else { return }
            let layout = await Task.detached(priority:.userInitiated) { ScenicRegion(terrain:generator) }.value
            guard !Task.isCancelled, self.revision == currentRevision else { return }
            do {
                let scenery = try ScenicRegionRenderer.make(layout,level:generator.level)
                self.root.addChild(scenery)
                self.scenery = scenery
            } catch {
                self.failure = "Scenery could not be prepared: \(error.localizedDescription)"
                return
            }
            self.ready = true
            self.progress = 1
            self.root.isEnabled = true
            self.generation = nil
        }
    }

    /// Prepares one immutable terrain set. Nothing is evicted or replaced while flying.
    static func regionKeys(for level: FlightLevel) -> [TileKey] {
        let tileSize = TerrainGenerator.tileSize
        if level.isFreeRoam {
            // A 9.6 km square comfortably contains the portal hub and a long exploration radius.
            return (-8...7).flatMap { z in (-8...7).map { x in TileKey(x: x, z: z) } }
        }
        let xRange = -3...3
        let lastZ = Int(floor(-level.routeLength / tileSize)) - 2
        return (lastZ...2).flatMap { z in xRange.map { x in TileKey(x: x, z: z) } }
    }

    private func materials(fog: Float) -> [any Material] {
        if let surfaceMaterials { return surfaceMaterials }
        // Fine height-projected noise can alias into regular ripples on bright snow.
        // Snow keeps smooth lighting and the existing low-poly silhouette without that texture.
        let snow = generator.level == .alpine || generator.level == .andoPrime
        let texture: TextureResource? = snow ? nil : Self.surfaceTexture(metal:generator.level == .deathStar)
        let result: [any RealityKit.Material] = generator.level.palette.map { color in
            let tint = UIColor(rgb: color * (1 - fog) + generator.level.fogColor * fog)
            var material = SimpleMaterial(color: tint, roughness: 1, isMetallic: false)
            if let texture { material.color = .init(tint:tint,texture:.init(texture)) }
            material.faceCulling = .none
            return material
        }
        surfaceMaterials = result
        return result
    }

    /// One small shared texture adds close-range detail without more terrain triangles.
    private static func surfaceTexture(metal: Bool) -> TextureResource? {
        let side = 256
        var pixels = [UInt8](repeating:255,count:side*side*4)
        for y in 0..<side {
            for x in 0..<side {
                var n = UInt32(x) &* 374761393 &+ UInt32(y) &* 668265263
                n = (n ^ (n >> 13)) &* 1274126177
                let noise = Float((n ^ (n >> 16)) & 255) / 255
                let value: Float
                if metal {
                    let seam = x % 64 < 2 || y % 64 < 2 || (y % 64 > 24 && y % 64 < 28 && x % 64 < 27)
                    let inset = x % 64 > 12 && x % 64 < 50 && y % 64 > 36 && y % 64 < 50
                    value = seam ? 0.28 : inset ? 0.6 + noise*0.08 : 0.87 + noise*0.13
                } else {
                    let band = sin(Float(y)*0.0245437 + sin(Float(x)*0.049087)*1.4)
                    value = 0.89 + noise*0.075 + band*0.025
                }
                let offset = (y*side+x)*4, byte = UInt8(clamp(value*255,0,255))
                pixels[offset] = byte; pixels[offset+1] = byte; pixels[offset+2] = byte
            }
        }
        return pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data:buffer.baseAddress,width:side,height:side,bitsPerComponent:8,bytesPerRow:side*4,
                space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue), let image = context.makeImage() else { return nil }
            return try? TextureResource(image:image,options:.init(semantic:.color))
        }
    }

    private func materialBindings(in entity: Entity) -> [MaterialBinding] {
        var result: [MaterialBinding] = []
        if let model = entity as? ModelEntity, let materials = model.model?.materials {
            result.append(MaterialBinding(entity: model, originals: materials))
        }
        for child in entity.children { result += materialBindings(in: child) }
        return result
    }

    private func fogTint(_ color: UIColor, amount: Float) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
#if canImport(UIKit)
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return color }
#else
        color.usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
#endif
        let rgb = SIMD3<Float>(Float(r), Float(g), Float(b))
        return UIColor(rgb: rgb * (1 - amount) + generator.level.fogColor * amount)
    }
}

extension UIColor {
    convenience init(rgb: SIMD3<Float>) {
        self.init(red: CGFloat(rgb.x), green: CGFloat(rgb.y), blue: CGFloat(rgb.z), alpha: 1)
    }
}
