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
    static let mesh:Result<MeshData,Error> = Result { try makeSculptedArch() }

    /// Portals part/core study: broad swells, upright flutes and bedding ledges.
    /// Deform once during preparation, then regenerate normals from the final mesh.
    private static func makeSculptedArch() throws -> MeshData {
        let base = try RockArch.build(RockArchRequest(span:520,height:360,thickness:90,depth:180,segments:96,radialSegments:16))
        let points = base.positions.map { p -> SIMD3<Float> in
            let a = atan2(max(0,p.y)/360,p.x/260)
            let center = SIMD3<Float>(260*cos(a),360*sin(a),0)
            let delta = p-center
            let swell:Float = 1 + 0.10*sin(a*7+0.8) + 0.045*sin(a*19)
            let flute:Float = sin(p.x*0.14+p.y*0.012)*sin(p.z*0.025)*3.2
            let ledge:Float = sin(p.y*0.12+sin(p.x*0.015))*2.8
            let normal = simd_length_squared(delta)>0.01 ? simd_normalize(delta) : SIMD3<Float>(0,-1,0)
            return center + delta*swell + normal*(flute+ledge)
        }
        var normals = Array(repeating:SIMD3<Float>.zero,count:points.count)
        for i in stride(from:0,to:base.indices.count,by:3) {
            let a=Int(base.indices[i]),b=Int(base.indices[i+1]),c=Int(base.indices[i+2])
            let n=simd_cross(points[b]-points[a],points[c]-points[a])
            normals[a]+=n;normals[b]+=n;normals[c]+=n
        }
        // Weld the duplicated radial seam while retaining the separate end caps.
        for ring in 0...96 {
            let first=ring*17,last=first+16,n=normals[first]+normals[last]
            normals[first]=n;normals[last]=n
        }
        normals = normals.enumerated().map { i,n in simd_length_squared(n)>0.000001 ? simd_normalize(n) : base.normals[i] }
        return try MeshData(positions:points,normals:normals,indices:base.indices)
    }
    static let origin:SIMD3<Float> = {
        let ground = PlanetExploration(planet:.tatooine)
        let x=ground.canyonCenter(z:-4500)
        let left=ground.groundHeight(x:x-260,z:-4500),right=ground.groundHeight(x:x+260,z:-4500)
        return [x,min(left,right)-18,-4500]
    }()
    static var passage:SIMD3<Float> { origin + [0,170,0] }
    static func hits(_ point:SIMD3<Float>,radius:Float) -> Bool {
        let p=point-origin
        guard abs(p.x)<330+radius,abs(p.z)<110+radius,p.y > -70-radius,p.y<430+radius else { return false }
        for i in 0...96 {
            let angle=Float(i)*Float.pi/96
            let delta=p-SIMD3<Float>(260*cos(angle),360*sin(angle),0)
            // Elliptical tube follows the rendered arch, including its depth.
            if simd_length_squared(delta/SIMD3<Float>(64+radius,64+radius,104+radius))<1 { return true }
        }
        return false
    }
}


/// Native world composition: Canyon of Light + The Desert Opens / fauna kit.
/// Positions are local to the arch; all animation is bounded and camera-independent.
enum CanyonLife {
    struct BirdPose {
        let position:SIMD3<Float>
        let heading:Float
        let bank:Float
        let wing:Float
    }
    static let funnelOffsets:[SIMD3<Float>] = [[-360,0,230],[430,0,-350]]
    static let funnelSegments=20
    static let funnel:Result<MeshData,Error> = Result {
        try ArchitecturalGeometry.lathe(LatheRequest(profile:[[8,0],[12,15],[18,40],[25,75],[36,110]],segments:funnelSegments))
    }
    static func funnelUVs(_ data:MeshData) -> [SIMD2<Float>] {
        data.positions.enumerated().map { i,p in
            // Distinct U=0/U=1 at the duplicate seam prevents a smeared strip.
            [Float(i % (funnelSegments+1))/Float(funnelSegments),p.y/110]
        }
    }
    static let birdFloor:Float = {
        let ground=PlanetExploration(planet:.tatooine),origin=TatooineCanyon.origin
        var top:Float = 0
        for i in 0..<64 {
            let a=Float(i)*Float.pi*2/64
            let x=origin.x-410+cos(a)*95,z=origin.z-100+sin(a)*150
            top=max(top,ground.groundHeight(x:x,z:z)-origin.y)
        }
        return top+150
    }()
    static func bird(_ index:Int,time:Float) -> BirdPose {
        let phase=Float(index)*1.31,a=time*0.13+phase
        let position=SIMD3<Float>(-410+cos(a)*95,birdFloor+sin(time*0.21+phase)*14,-100+sin(a)*150)
        let heading=atan2(-sin(a)*95,cos(a)*150)
        // Long glides interrupted by short wingbeats, rather than constant flutter.
        let beat=max(0,sin(time*0.38+phase))
        let wing:Float = 0.12+sin(time*5.5+phase)*0.52*beat*beat
        return BirdPose(position:position,heading:heading,bank:-0.14+sin(a)*0.05,wing:wing)
    }
}
