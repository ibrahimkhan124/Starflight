import RealityKit
import UIKit
import simd
import Metal

/// Small, seamless surface maps prepared once and shared across the expedition
/// scenery. Detail lives in materials rather than thousands of extra entities.
@MainActor
enum ScenicMaterials {
    private struct Maps {
        let color: TextureResource
        let normal: TextureResource
    }
    private static var cache: [String: Maps] = [:]
    private static let library: (any MTLLibrary)? = {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        return try? device.makeDefaultLibrary(bundle: .main)
    }()
    static var shadersAvailable: Bool { library?.functionNames.contains("starflight_ground") == true }
    static func planetCode(_ name: String?) -> Float {
        switch name?.lowercased() {
        case "tatooine": return 1; case "hoth": return 2; case "endor": return 3; case "coruscant": return 4
        case "mercury": return 5; case "venus": return 6; case "earth": return 7; case "mars": return 8; case "jupiter": return 9
        default: return 0
        }
    }
    private static func shader(_ name: String, base: any RealityKit.Material, settings: SIMD4<Float>) -> any RealityKit.Material {
        guard let library, library.functionNames.contains(name),
              var material = try? CustomMaterial(from: base, surfaceShader: .init(named: name, in: library)) else { return base }
        material.custom.value = settings
        return material
    }

    /// Detailed needles and branch gaps are alpha clipped, keeping a rounded
    /// forest silhouette without adding a mesh for every leaf or twig.
    static func foliage() -> PhysicallyBasedMaterial {
        var paint = PhysicallyBasedMaterial()
        paint.baseColor = .init(tint: .white)
        if let texture = foliageTexture { paint.baseColor = .init(tint: .white, texture: .init(texture)) }
        paint.roughness = .init(floatLiteral: 0.95)
        paint.faceCulling = .none
        paint.blending = .transparent(opacity: .init(floatLiteral: 1))
        paint.opacityThreshold = 0.35
        return paint
    }

    private static let foliageTexture: TextureResource? = {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 1024), format: format).image { renderer in
            let context = renderer.cgContext
            context.setLineCap(.round)
            func random(_ i: Int) -> CGFloat {
                let value = sin(Double(i) * 127.13 + 31.7) * 43758.5453
                return CGFloat(value - floor(value))
            }
            for layer in 0..<30 {
                let t = CGFloat(layer) / 29
                let y = 45 + t * 900
                let spread = 14 + pow(sin(t * .pi * 0.94), 0.64) * (210 - 55 * t)
                for side: CGFloat in [-1, 1] {
                    let seed = layer * 137 + (side > 0 ? 79 : 0)
                    let tipX = 256 + side * spread * (0.78 + random(seed) * 0.22)
                    let tipY = y - 15 - random(seed + 1) * 32
                    context.setStrokeColor(UIColor(red: 0.22, green: 0.18, blue: 0.10, alpha: 1).cgColor)
                    context.setLineWidth(1.5 + t * 2.5)
                    context.move(to: CGPoint(x: 256, y: y + 13)); context.addQuadCurve(to: CGPoint(x: tipX, y: tipY), control: CGPoint(x: (256 + tipX) / 2, y: y - 16)); context.strokePath()
                    for twig in 0..<28 {
                        let u = CGFloat(twig) / 27
                        let x = 256 + (tipX - 256) * u
                        let py = y + (tipY - y) * u
                        let needleSpread = (8 + 28 * sin(u * .pi)) * (0.6 + random(seed + twig * 3) * 0.4)
                        for needle in 0..<6 {
                            let r = random(seed + twig * 19 + needle * 7)
                            let nx = x + (r - 0.5) * 15
                            let ny = py + (CGFloat(needle) / 5 - 0.5) * needleSpread
                            let shade = 0.72 + random(seed + twig + needle * 51) * 0.28
                            context.setFillColor(UIColor(red: 0.18 * shade, green: 0.39 * shade, blue: 0.15 * shade, alpha: 1).cgColor)
                            context.fillEllipse(in: CGRect(x: nx, y: ny, width: 5 + r * 9, height: 2.5 + r * 3.5))
                        }
                    }
                }
            }
        }
        guard let cg = image.cgImage else { return nil }
        return try? TextureResource.generate(from: cg, options: .init(semantic: .color))
    }()

    static func terrain(color: UIColor, kind: String, planet: String? = nil, continuous: Bool = false, reducedDetail: Bool = false) -> any RealityKit.Material {
        var paint = PhysicallyBasedMaterial()
        paint.baseColor = .init(tint: color)
        paint.roughness = .init(floatLiteral: kind == "snow" ? 0.76 : 0.94)
        paint.metallic = .init(floatLiteral: 0)
        if let maps = maps(kind: kind) {
            paint.baseColor = .init(tint: color, texture: .init(maps.color))
            paint.normal = .init(texture: .init(maps.normal))
        }
        let code: Float = kind == "snow" ? 1 : kind == "sand" ? 2 : kind == "moss" ? 3 : kind == "bark" ? 4 : kind == "cloud" ? 5 : 0
        return shader("starflight_ground", base: paint, settings: [code, planetCode(planet), planet == "Tatooine" && TatooineCanyon.enabled ? 2 : continuous ? 1 : 0, reducedDetail ? 1 : 0])
    }

    static func aetherSurface(_ base:PhysicallyBasedMaterial) -> any RealityKit.Material {
        shader("starflight_aether_surface",base:base,settings:[0.28,0,0,0])
    }
    static func water(color: UIColor, planet: String = "Earth") -> any RealityKit.Material {
        var paint = PhysicallyBasedMaterial(); paint.baseColor = .init(tint: color)
        paint.roughness = .init(floatLiteral: 0.17); paint.specular = .init(floatLiteral: 0.95)
        paint.clearcoat = .init(floatLiteral: 0.5); paint.clearcoatRoughness = .init(floatLiteral: 0.12)
        return shader("starflight_water", base: paint, settings: [planetCode(planet),0,0,0])
    }
    static func cloud(color: UIColor, planet: String, reducedDetail: Bool = false, orbital: Bool = false) -> any RealityKit.Material {
        var paint = UnlitMaterial(color: color); paint.faceCulling = .none
        paint.blending = .transparent(opacity: .init(floatLiteral: 0.5))
        return shader("starflight_cloud", base: paint, settings: [planetCode(planet),reducedDetail ? 1:0,orbital ? 1:0,orbital ? 0.78:0.65])
    }
    static func atmosphere(planet: String, color: UIColor) -> any RealityKit.Material {
        var paint = UnlitMaterial(color: color); paint.faceCulling = .back
        paint.blending = .transparent(opacity: .init(floatLiteral: 0.16))
        return shader("starflight_atmosphere", base: paint, settings: [planetCode(planet),0,0,0])
    }
    static func globe(_ source: UnlitMaterial, planet: String) -> any RealityKit.Material {
        var paint = PhysicallyBasedMaterial(); paint.baseColor = .init(tint: source.color.tint, texture: source.color.texture)
        paint.roughness = .init(floatLiteral: 0.9)
        return shader("starflight_globe", base: paint, settings: [planetCode(planet),0,0,0])
    }

    /// A continuous horizon, without stacked translucent bands. The map wraps
    /// seamlessly around the inside of a sphere and never changes in flight.
    static func sky(zenith: UIColor, horizon: UIColor) -> UnlitMaterial {
        let top = rgb(zenith), edge = rgb(horizon)
        let width = 64, height = 256
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            let latitude = Float(y) / Float(height - 1)
            let nearHorizon = pow(max(0, 1 - abs(latitude - 0.5) * 2), 5)
            let value = top * (1 - nearHorizon) + edge * nearHorizon
            for x in 0..<width {
                let index = (y * width + x) * 4
                bytes[index] = byte(value.x); bytes[index + 1] = byte(value.y)
                bytes[index + 2] = byte(value.z)
            }
        }
        var paint = UnlitMaterial(color: zenith)
        if let image = image(bytes: bytes, size: CGSize(width: width, height: height)),
           let texture = try? TextureResource.generate(from: image, options: .init(semantic: .color)) {
            paint.color = .init(tint: .white, texture: .init(texture))
        }
        paint.faceCulling = .front
        return paint
    }

    private static func maps(kind: String) -> Maps? {
        if let existing = cache[kind] { return existing }
        let size = 256
        var heights = [Float](repeating: 0, count: size * size)
        for y in 0..<size { for x in 0..<size {
            let u = Float(x) / Float(size), v = Float(y) / Float(size)
            let broad = noise(u * 8, v * 8, period: 8, seed: 17)
            let middle = noise(u * 32, v * 32, period: 32, seed: 93)
            let fine = noise(u * 64, v * 64, period: 64, seed: 217)
            let value: Float
            switch kind {
            case "bark":
                let flutes = abs(sin(u * .pi * 32 + broad * 2 + middle * 0.35))
                value = flutes * 0.50 + broad * 0.25 + fine * 0.12
            case "sand":
                let ripple = sin((v * 48 + broad * 0.9) * .pi * 2)
                value = 0.4 + ripple * 0.075 + broad * 0.22 + fine * 0.045
            case "snow": value = 0.5 + broad * 0.13 + middle * 0.05 + fine * 0.025
            case "moss": value = broad * 0.5 + middle * 0.26 + fine * 0.13
            default:
                let strata = sin((v * 16 + broad * 0.6) * .pi * 2)
                value = broad * 0.42 + middle * 0.27 + fine * 0.15 + strata * 0.055
            }
            heights[y * size + x] = value
        } }
        var albedo = [UInt8](repeating: 255, count: size * size * 4)
        var normals = albedo
        let bump: Float = kind == "snow" ? 0.8 : kind == "bark" ? 3.8 : 2.4
        for y in 0..<size { for x in 0..<size {
            let index = y * size + x, pixel = index * 4
            let value = heights[index]
            let shade = byte(0.70 + value * 0.34)
            albedo[pixel] = shade; albedo[pixel + 1] = shade; albedo[pixel + 2] = shade
            let dx = heights[y * size + (x + 1) % size] - heights[y * size + (x + size - 1) % size]
            let dy = heights[((y + 1) % size) * size + x] - heights[((y + size - 1) % size) * size + x]
            let normal = simd_normalize(SIMD3<Float>(-dx * bump, -dy * bump, 1))
            normals[pixel] = byte(normal.x * 0.5 + 0.5)
            normals[pixel + 1] = byte(normal.y * 0.5 + 0.5)
            normals[pixel + 2] = byte(normal.z * 0.5 + 0.5)
        } }
        let dimensions = CGSize(width: size, height: size)
        guard let colorImage = image(bytes: albedo, size: dimensions),
              let normalImage = image(bytes: normals, size: dimensions),
              let color = try? TextureResource.generate(from: colorImage, options: .init(semantic: .color)),
              let normal = try? TextureResource.generate(from: normalImage, options: .init(semantic: .normal)) else { return nil }
        let result = Maps(color: color, normal: normal)
        cache[kind] = result
        return result
    }

    private static func image(bytes: [UInt8], size: CGSize) -> CGImage? {
        let width = Int(size.width), height = Int(size.height)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    private static func rgb(_ color: UIColor) -> SIMD3<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [Float(r), Float(g), Float(b)]
    }
    private static func byte(_ value: Float) -> UInt8 { UInt8(max(0, min(255, Int(value * 255)))) }

    /// Wrapped integer hashing keeps both sides of each texture tile identical.
    private static func noise(_ x: Float, _ y: Float, period: Int, seed: UInt32) -> Float {
        let ix = Int(floor(x)), iy = Int(floor(y))
        let fx = x - Float(ix), fy = y - Float(iy)
        let u = fx * fx * (3 - 2 * fx), v = fy * fy * (3 - 2 * fy)
        func hash(_ px: Int, _ py: Int) -> Float {
            var h = UInt32((px % period + period) % period) &* 374761393
            h = h &+ UInt32((py % period + period) % period) &* 668265263 &+ seed
            h = (h ^ (h >> 13)) &* 1274126177
            return Float((h ^ (h >> 16)) & 65535) / 65535
        }
        let a = hash(ix, iy) * (1 - u) + hash(ix + 1, iy) * u
        let b = hash(ix, iy + 1) * (1 - u) + hash(ix + 1, iy + 1) * u
        return a * (1 - v) + b * v
    }
}
