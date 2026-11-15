import Foundation
import simd
import ProceduralCore
import ProceduralTerrain
import ProceduralPlacement
import ProceduralGeometry

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

/// Canyon of Light study: reusable arch anchors and geometric contact, independent of camera.
enum TatooineCanyon {
    static var enabled:Bool { AetherPlanet.flag("portalsCanyonEnabled") }
    static let mesh:Result<MeshData,Error> = Result { try RockArch.build(RockArchRequest(span:520,height:360,thickness:64,depth:110)) }
    static let origin:SIMD3<Float> = {
        let ground = PlanetExploration(planet:.tatooine)
        let x=ground.canyonCenter(z:-4500)
        let left=ground.groundHeight(x:x-260,z:-4500),right=ground.groundHeight(x:x+260,z:-4500)
        return [x,min(left,right)-18,-4500]
    }()
    static var passage:SIMD3<Float> { origin + [0,170,0] }
    static func hits(_ point:SIMD3<Float>,radius:Float) -> Bool {
        let p=point-origin
        guard abs(p.x)<310+radius,abs(p.z)<60+radius,p.y > -60-radius,p.y<410+radius else { return false }
        for i in 0...96 {
            let angle=Float(i)*Float.pi/96
            let delta=p-SIMD3<Float>(260*cos(angle),360*sin(angle),0)
            // Elliptical tube follows the rendered arch, including its depth.
            if simd_length_squared(delta/SIMD3<Float>(36+radius,36+radius,56+radius))<1 { return true }
        }
        return false
    }
}
