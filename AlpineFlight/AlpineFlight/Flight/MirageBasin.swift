import Foundation
import simd
import ProceduralCore

/// An isolated native adaptation of Walking Dune + Canyon of Three Airs.
/// The same quantised snapshot drives prepared meshes, clearance and contact.
enum MirageBasin {
    static let enabled=false // Retired from gameplay at the player's request.
    static let center=SIMD2<Float>(4800,-5200)
    static let cells=16
    static let cell:Float=24
    static let half=Float(cells)*cell/2
    static let phases=8
    static let tickRate:Float=6
    static let foundation:Float = {
        let ground=PlanetExploration(planet:.tatooine)
        var top:Float=0
        for i in 0...cells { for j in 0...cells {
            top=max(top,ground.groundHeight(x:center.x-half+Float(i)*cell,z:center.y-half+Float(j)*cell))
        } }
        for j in 0...32 {
            let z=center.y+half+(650-half)*Float(j)/32
            top=max(top,ground.groundHeight(x:center.x,z:z))
        }
        return top+16
    }()
    static var arrival:SIMD3<Float> { [center.x,foundation+125,center.y+650] }
    static func contains(x:Float,z:Float,margin:Float=0) -> Bool {
        abs(x-center.x)<=half+margin && abs(z-center.y)<=half+margin
    }
    static func clearsObstacle(x:Float,z:Float) -> Bool {
        contains(x:x,z:z,margin:180) || (abs(x-center.x)<180 && z>center.y+half && z<center.y+800)
    }
    static func phase(at time:Float) -> Int {
        guard time.isFinite,time>0 else { return 0 }
        return Int((time*tickRate).truncatingRemainder(dividingBy:Float(phases)))
    }
    static func top(i:Int,j:Int,phase:Int) -> Float {
        let x=(Float(i)+0.5)*cell-half,z=(Float(j)+0.5)*cell-half
        let ridge:Float = -35+95*pow(abs(x)/half,1.6)
        let crest=74*exp(-pow((z-ridge)/65,2))*max(0,1-pow(abs(x)/half,4))
        let wave=4*floor(1.5+1.5*sin(Float(i+j)*0.65+Float(phase)*2 * .pi/Float(phases)))
        return foundation+8+floor(crest/4)*4+wave
    }
    private static let bottoms:[Float] = {
        let ground=PlanetExploration(planet:.tatooine)
        return (0..<(cells*cells)).map { index in
            let i=index/cells,j=index%cells
            let x=center.x-half+Float(i)*cell,z=center.y-half+Float(j)*cell
            return min(ground.groundHeight(x:x,z:z),ground.groundHeight(x:x+cell,z:z),
                       ground.groundHeight(x:x,z:z+cell),ground.groundHeight(x:x+cell,z:z+cell))-12
        }
    }()
    static func bottom(i:Int,j:Int) -> Float { bottoms[i*cells+j] }
    static func height(x:Float,z:Float,time:Float) -> Float? {
        guard contains(x:x,z:z) else { return nil }
        let i=min(cells-1,max(0,Int(floor((x-center.x+half)/cell))))
        let j=min(cells-1,max(0,Int(floor((z-center.y+half)/cell))))
        return top(i:i,j:j,phase:phase(at:time))
    }
    static func hits(_ p:SIMD3<Float>,radius:Float,time:Float) -> Bool {
        guard contains(x:p.x,z:p.z,margin:radius) else { return false }
        let loX=max(0,Int(floor((p.x-radius-center.x+half)/cell)))
        let hiX=min(cells-1,Int(floor((p.x+radius-center.x+half)/cell)))
        let loZ=max(0,Int(floor((p.z-radius-center.y+half)/cell)))
        let hiZ=min(cells-1,Int(floor((p.z+radius-center.y+half)/cell)))
        guard loX<=hiX,loZ<=hiZ else { return false }
        let snapshot=phase(at:time)
        for i in loX...hiX { for j in loZ...hiZ {
            let low=bottom(i:i,j:j),high=top(i:i,j:j,phase:snapshot)
            let center=SIMD3<Float>(self.center.x-half+(Float(i)+0.5)*cell,(low+high)/2,self.center.y-half+(Float(j)+0.5)*cell)
            let axes=SIMD3<Float>(cell/2,(high-low)/2,cell/2)
            if simd_distance_squared(p-center,simd_clamp(p-center,-axes,axes))<=radius*radius { return true }
        } }
        return false
    }
    static func impact(from a:SIMD3<Float>,to b:SIMD3<Float>,radius:Float,start:Float,end:Float) -> Bool {
        guard max(a.x,b.x)+radius>=center.x-half,min(a.x,b.x)-radius<=center.x+half,
              max(a.z,b.z)+radius>=center.y-half,min(a.z,b.z)-radius<=center.y+half else { return false }
        let steps=max(1,Int(ceil(simd_distance(a,b)/8)))
        for i in 0...steps {
            let t=Float(i)/Float(steps),p=a+(b-a)*t
            if hits(p,radius:radius,time:start+(end-start)*t) { return true }
        }
        return false
    }
    static func meshes(phase:Int) throws -> [MeshData] {
        var positions=Array(repeating:[SIMD3<Float>](),count:3)
        var normals=positions,indices=Array(repeating:[UInt32](),count:3)
        for i in 0..<cells { for j in 0..<cells {
            let low=bottom(i:i,j:j),high=top(i:i,j:j,phase:phase)
            let x=Float(i)*cell-half,z=Float(j)*cell-half
            let corners:[SIMD3<Float>] = [[x,low-foundation,z],[x+cell,low-foundation,z],[x+cell,low-foundation,z+cell],[x,low-foundation,z+cell],
                                        [x,high-foundation,z],[x+cell,high-foundation,z],[x+cell,high-foundation,z+cell],[x,high-foundation,z+cell]]
            let group=Int((high-foundation)/8)%3
            for face in [[0,1,2,3],[4,7,6,5],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]] {
                let a=corners[face[0]],b=corners[face[1]],c=corners[face[2]]
                let n=simd_normalize(simd_cross(b-a,c-a)),start=UInt32(positions[group].count)
                positions[group] += face.map { corners[$0] }
                normals[group] += Array(repeating:n,count:4)
                indices[group] += [start,start+1,start+2,start,start+2,start+3]
            }
        } }
        return try (0..<3).map { try MeshData(positions:positions[$0],normals:normals[$0],indices:indices[$0]) }
    }
}
