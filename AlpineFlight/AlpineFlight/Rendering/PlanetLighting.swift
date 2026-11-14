import RealityKit
import UIKit
import simd

/// A small, original HDR sky probe supplies diffuse fill and stable specular
/// reflections. It is generated once per expedition, never captured per frame.
@MainActor
enum PlanetLighting {
    private static var cache:[String:EnvironmentResource] = [:]
    private static var failed = Set<String>()
    private static var pending:[String:Task<Void,Never>] = [:]

    static func prewarm() {
        for world in ["Mercury","Venus","Earth","Mars","Jupiter","coruscant","tatooine","hoth","endor"] { prepare(world) }
    }
    static func environment(for world:String) -> EnvironmentResource? {
        if let existing = cache[world] { return existing }
        prepare(world)
        return nil
    }
    private static func prepare(_ world:String) {
        guard cache[world] == nil, pending[world] == nil, !failed.contains(world) else { return }
        pending[world] = Task { @MainActor in
            guard let image = probeImage(world:world) else {
                failed.insert(world); pending[world] = nil; return
            }
            do {
                cache[world] = try await EnvironmentResource(equirectangular:image,withName:"Starflight-"+world+"-sky-probe")
            } catch { failed.insert(world) }
            pending[world] = nil
        }
    }
    private static func probeImage(world:String) -> CGImage? {
        let zenith:SIMD3<Float>, horizon:SIMD3<Float>, ground:SIMD3<Float>
        switch world.lowercased() {
        case "earth": zenith = [0.12,0.23,0.42]; horizon = [0.50,0.63,0.69]; ground = [0.15,0.18,0.12]
        case "mercury": zenith = [0.002,0.002,0.003]; horizon = [0.018,0.018,0.02]; ground = [0.11,0.10,0.09]
        case "venus": zenith = [0.30,0.19,0.06]; horizon = [0.56,0.38,0.14]; ground = [0.14,0.10,0.05]
        case "mars": zenith = [0.22,0.12,0.08]; horizon = [0.48,0.29,0.18]; ground = [0.18,0.09,0.05]
        case "jupiter": zenith = [0.22,0.17,0.10]; horizon = [0.58,0.47,0.32]; ground = [0.31,0.22,0.13]
        case "coruscant": zenith = [0.012,0.016,0.035]; horizon = [0.025,0.035,0.065]; ground = [0.02,0.012,0.028]
        case "tatooine": zenith = [0.29,0.25,0.19]; horizon = [0.56,0.43,0.26]; ground = [0.25,0.16,0.08]
        case "hoth": zenith = [0.18,0.30,0.43]; horizon = [0.61,0.73,0.82]; ground = [0.49,0.59,0.65]
        case "endor": zenith = [0.10,0.17,0.20]; horizon = [0.32,0.38,0.26]; ground = [0.055,0.10,0.045]
        default: return nil
        }
        let width = 128, height = 64
        let sun = simd_normalize(SIMD3<Float>(800,1200,900))
        var pixels = [SIMD4<Float>](repeating:.zero,count:width*height)
        let fullTurn = Float.pi * 2
        let halfTurn = Float.pi
        let quarterTurn = Float.pi / 2
        for y in 0..<height {
            let verticalFraction = (Float(y) + 0.5) / Float(height)
            let latitude = quarterTurn - verticalFraction * halfTurn
            for x in 0..<width {
                let horizontalFraction = (Float(x) + 0.5) / Float(width)
                let longitude = horizontalFraction * fullTurn - halfTurn
                let direction = SIMD3<Float>(cos(latitude) * cos(longitude), sin(latitude), cos(latitude) * sin(longitude))
                let heightBlend: Float = pow(abs(direction.y), Float(0.6))
                var rgb = horizon*(1-heightBlend)+(direction.y>=0 ? zenith:ground)*heightBlend
                // Broad HDR sun disk, with more diffuse fill on hazy planets.
                let haze:Float = ["venus","jupiter"].contains(world.lowercased()) ? 70:320
                let glare = pow(max(0,simd_dot(direction,sun)),haze)
                let sunlight:Float = world.lowercased() == "coruscant" ? 0.12:world.lowercased() == "mercury" ? 13:7
                rgb += SIMD3<Float>(1,0.93,0.80)*glare*sunlight
                pixels[y*width+x] = SIMD4<Float>(rgb,1)
            }
        }
        let bytes = pixels.withUnsafeBytes { Data($0) }
        guard let colorSpace = CGColorSpace(name:CGColorSpace.extendedLinearSRGB),
              let provider = CGDataProvider(data:bytes as CFData) else { return nil }
        return CGImage(width:width,height:height,bitsPerComponent:32,bitsPerPixel:128,
                bytesPerRow:width*MemoryLayout<SIMD4<Float>>.stride,space:colorSpace,
                bitmapInfo:CGBitmapInfo.floatComponents.union(.byteOrder32Little).union(CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue)),
                provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent)
    }
}
