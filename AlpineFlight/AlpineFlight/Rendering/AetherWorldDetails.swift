import Foundation
import simd
import ProceduralCore
import ProceduralTerrain
import ProceduralPlacement

/// Host exclusion predicates wrap the actual triangle query before scattering.
enum AetherWorldDetails {
    static let enabled:Bool = AetherPlanet.flag("aetherWorldDetailEnabled")
    struct ProtectedSurface:SurfaceQuery {
        let grid:TerrainGrid
        func sample(at p:SIMD2<Float>) -> SurfaceSample? {
            guard isClear(p) else { return nil }
            return grid.sample(at:p)
        }
        func isClear(_ p:SIMD2<Float>) -> Bool {
            let valley = 900*sin(p.y/3200)
            // Wide travel corridor, arrival, arch approach/terrace and map edge.
            return abs(p.x-valley)>1050 && simd_distance(p,[0,1200])>1500
                && simd_distance(p,[-480,-1800])>1200
                && abs(p.x)<13000 && abs(p.y)<13000
        }
    }
    static func scatter(on grid:TerrainGrid) throws -> ScatterResult {
        try TerrainScatter.sample(on:ProtectedSurface(grid:grid),request:ScatterRequest(
            bounds:WorldBounds(minimum:[-12500,-12500],maximum:[12500,12500]),
            count:420,maximumAttempts:9000,minimumSpacing:210,minimumNormalY:0.68,altitude:180...1850),seed:81396)
    }
    static func hits(from a:SIMD3<Float>,to b:SIMD3<Float>,radius:Float,placements:[Placement]) -> Bool {
        let delta=b-a
        for item in placements {
            let r:Float = 18+item.variation*24, height:Float = r*1.8
            guard min(a.x,b.x)-radius < item.position.x+r,max(a.x,b.x)+radius>item.position.x-r,
                  min(a.z,b.z)-radius < item.position.z+r,max(a.z,b.z)+radius>item.position.z-r else { continue }
            let center=item.position+SIMD3<Float>(0,height*0.5-2,0)
            let axes=SIMD3<Float>(r+radius,height*0.5+radius,r+radius)
            let scaledDelta=delta/axes, scaledStart=(a-center)/axes
            let t=max(0,min(1,-simd_dot(scaledStart,scaledDelta)/max(0.000001,simd_length_squared(scaledDelta))))
            let offset=scaledStart+scaledDelta*t
            if simd_length_squared(offset)<1 { return true }
        }
        return false
    }
}
