import Foundation
import simd
import ProceduralCore
import ProceduralTerrain
import ProceduralGeometry
import ProceduralSurface

/// App-owned composition. Aether supplies neutral geometry and CPU surface masks;
/// Starflight still owns travel, physics, camera, collisions and RealityKit lighting.
enum AetherPlanet {
    static let name = "Aether Reach"
    static let seed: UInt64 = 73142
    static let extent: Float = 14000
    static var enabled: Bool { UserDefaults.standard.object(forKey:"aetherPlanetEnabled") as? Bool ?? true }
    static let body = SolarBody(name:name,radius:65,position:[3400,0,-5200],tint:[0.20,0.65,0.53])
    struct Prepared: Sendable {
        let grid: TerrainGrid
        let arch: MeshData
        let pixels: [UInt8]
        let textureSize: Int
    }
    /// One immutable bounded asset, evaluated during preparation, never per frame.
    static let prepared: Result<Prepared,Error> = Result { try build() }
    struct Highlands: HeightField {
        let noise = ValueNoise(seed:seed)
        func height(at p:SIMD2<Float>) -> Float {
            let warp = SIMD2(noise.value(at:p/4700),noise.value(at:p/4700+[21,-9]))*900
            let q = p+warp
            let ridge = pow(1-abs(noise.fractal(at:q/3000,octaves:4)),3)
            let valley = exp(-pow((p.x-900*sin(p.y/3200))/1550,2))
            let coast = 1-exp(-pow((p.x+9000)/4400,2))
            let relief = 170+ridge*2400*coast*(1-valley*0.88)
            let arrival = exp(-pow(p.x/900,2)-pow((p.y-1200)/2000,2))
            let composed = relief*(1-arrival)+190*arrival
            // A broad valley terrace grounds both arch feet and leaves a clear
            // approach through its opening, without altering other worlds.
            let terrace = exp(-pow((p.x+480)/700,4)-pow((p.y+1800)/700,4))
            return composed*(1-terrace)+260*terrace
        }
    }
    static func height(x:Float,z:Float) -> Float {
        guard let asset = try? prepared.get() else { return 190 }
        let p = SIMD2(max(-extent,min(extent,x)),max(-extent,min(extent,z)))
        return asset.grid.sample(at:p)?.position.y ?? 190
    }
    static func archPosition(_ asset:Prepared) -> SIMD3<Float> {
        let x:Float = -480, z:Float = -1800
        let left = asset.grid.sample(at:[x-210,z])?.position.y ?? 0
        let right = asset.grid.sample(at:[x+210,z])?.position.y ?? 0
        return [x,min(left,right)-20,z]
    }
    /// Capsule segments follow the same arch centreline. The opening stays open.
    static func hitsArch(from a:SIMD3<Float>,to b:SIMD3<Float>,radius:Float) -> Bool {
        guard let asset = try? prepared.get() else { return false }
        let origin = archPosition(asset)
        guard min(a.x,b.x)-radius < origin.x+260, max(a.x,b.x)+radius > origin.x-260,
              min(a.z,b.z)-radius < origin.z+60, max(a.z,b.z)+radius > origin.z-60,
              min(a.y,b.y)-radius < origin.y+350, max(a.y,b.y)+radius > origin.y-50 else { return false }
        let direction = b-a
        for i in 0...64 {
            let angle = Float(i)*Float.pi/64
            let center = origin+SIMD3(210*cos(angle),300*sin(angle),0)
            let t = max(0,min(1,simd_dot(center-a,direction)/max(0.0001,simd_length_squared(direction))))
            if simd_distance(a+direction*t,center)<radius+43 { return true }
        }
        return false
    }
    static func build() throws -> Prepared {
        let grid = try TerrainGrid.build(field:Highlands(),request:TerrainGridRequest(
            bounds:WorldBounds(minimum:[-extent,-extent],maximum:[extent,extent]),cellsX:192,cellsZ:192))
        let arch = try RockArch.build(RockArchRequest(span:420,height:300,thickness:50,depth:85))
        let recipe = try TerrainSurfaceRecipe(rockSlope:Transition(0.55,0.84),snowSlope:Transition(0.4,0.75),
            snowLine:1550,snowBlend:260,snowNoise:150,snowAmount:1,
            ground:LinearRGB(0.10,0.24,0.12),rock:LinearRGB(0.29,0.25,0.22),snow:LinearRGB(0.82,0.90,0.96))
        let size = 512, noise = ValueNoise(seed:seed)
        var pixels = [UInt8](repeating:255,count:size*size*4)
        for y in 0..<size {
            try Task.checkCancellation()
            for x in 0..<size {
                let p = SIMD2(Float(x)/Float(size-1),Float(y)/Float(size-1))*extent*2-SIMD2(repeating:extent)
                guard let sample = grid.sample(at:p) else { continue }
                let macro = max(0,min(1,noise.value(at:p/1400)*0.5+0.5))
                let weights = TerrainSurface.weights(at:try SurfaceInput(position:sample.position,normal:sample.normal,macroVariation:macro),recipe:recipe)
                let rgb = (recipe.ground.value*weights.ground+recipe.rock.value*weights.rock+recipe.snow.value*weights.snow)*(0.88+macro*0.18)
                for c in 0..<3 {
                    // Bake reflectance, not illumination. Convert linear -> sRGB
                    // once; RealityKit's colour texture decodes it for native PBR.
                    let linear = max(0,min(1,rgb[c]))
                    let srgb = linear <= 0.0031308 ? linear*12.92 : 1.055*pow(linear,1/2.4)-0.055
                    pixels[(y*size+x)*4+c] = UInt8(max(0,min(255,Int((srgb*255).rounded()))))
                }
            }
        }
        return Prepared(grid:grid,arch:arch,pixels:pixels,textureSize:size)
    }
}
