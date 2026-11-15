import Foundation
import simd

/// A trunk valley with smoothly joined tributaries and smaller twigs.
/// The union is sampled by the existing terrain recipe, so rendered/collision
/// triangles acquire the very same branches without extra scenery meshes.
enum CanyonRoutes {
    struct Route {
        let name:String
        let parent:Int?
        let width:Float
        let control:[SIMD2<Float>]
        func point(_ t:Float) -> SIMD2<Float> {
            let u=1-t
            return control[0]*(u*u*u)+control[1]*(3*u*u*t)+control[2]*(3*u*t*t)+control[3]*(t*t*t)
        }
    }
    static let routes:[Route] = {
        let surface=PlanetExploration(planet:.tatooine)
        func branch(_ name:String,_ z:Float,_ side:Float,_ end:SIMD2<Float>) -> Route {
            let p=SIMD2<Float>(surface.canyonCenter(z:z),z)
            return Route(name:name,parent:nil,width:390,control:[p,p+[side*1300,-450],end+[-side*1400,750],end])
        }
        let east=branch("Sunrise fork",4400,1,[6100,800])
        let west=branch("Shaded fork",1700,-1,[-6200,-2200])
        let south=branch("Redstone fork",-1200,1,[5900,-5600])
        var result=[east,west,south]
        for (parent,ends) in [(0,[SIMD2<Float>(8000,2300),[7900,-1400]]),(1,[SIMD2<Float>(-8200,400),[-8200,-4300]]),(2,[SIMD2<Float>(7900,-3500),[7400,-7800]])] {
            for (index,end) in ends.enumerated() {
                let p=result[parent].point(0.62),tangent=simd_normalize(result[parent].point(0.64)-result[parent].point(0.60))
                result.append(Route(name:result[parent].name+" · "+(index == 0 ? "upper trail":"lower trail"),parent:parent,width:300,
                                    control:[p,p+tangent*850,end+(p-end)*0.3,end]))
            }
        }
        return result
    }()
    private struct Segment {
        let a:SIMD2<Float>,b:SIMD2<Float>
        let width:Float
    }
    private static let bucket:Float=1000
    private static let bins:[SIMD2<Int>:[Segment]] = {
        var result:[SIMD2<Int>:[Segment]] = [:]
        for route in routes {
            let p=(0...24).map { route.point(Float($0)/24) }
            for (a,b) in zip(p,p.dropFirst()) {
                let segment=Segment(a:a,b:b,width:route.width),reach=route.width+600
                let low=simd_min(a,b)-SIMD2(repeating:reach),high=simd_max(a,b)+SIMD2(repeating:reach)
                for i in Int(floor(low.x/bucket))...Int(floor(high.x/bucket)) {
                    for j in Int(floor(low.y/bucket))...Int(floor(high.y/bucket)) { result[[i,j],default:[]].append(segment) }
                }
            }
        }
        return result
    }()
    /// Zero is the open valley floor, one is untouched surrounding mountain.
    static func wall(x:Float,z:Float) -> Float {
        let p=SIMD2<Float>(x,z),key=SIMD2<Int>(Int(floor(x/bucket)),Int(floor(z/bucket)))
        var mask:Float=1
        for segment in bins[key] ?? [] {
            let delta=segment.b-segment.a
            let t=max(0,min(1,simd_dot(p-segment.a,delta)/max(0.001,simd_length_squared(delta))))
            let d=simd_distance(p,segment.a+delta*t)
            let blend=max(0,min(1,(d-segment.width)/600))
            mask=min(mask,blend*blend*(3-2*blend))
            if mask==0 { break }
        }
        return mask
    }
}
