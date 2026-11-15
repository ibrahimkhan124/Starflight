import Foundation
import simd

enum PlanetWildlife {
    enum Kind { case bantha,forestDeer,tauntaun }
    static func kind(on planet:SpacePlanet) -> Kind? {
        switch planet { case .tatooine:return .bantha;case .endor:return .forestDeer;case .hoth:return .tauntaun;case .coruscant:return nil }
    }
    static func sites(on planet:SpacePlanet,reduced:Bool) -> [SIMD3<Float>] {
        guard kind(on:planet) != nil else { return [] }
        let surface=PlanetExploration(planet:planet)
        for offset:SIMD2<Float> in [[180,-300],[-180,-300],[280,-450],[-280,-450]] {
            let center=SIMD2<Float>(surface.arrival.x+offset.x,surface.arrival.z+offset.y)
            let sites=(0..<(reduced ? 2:4)).map { i -> SIMD3<Float> in
                let p=center+SIMD2<Float>(Float(i%2)*18-9,Float(i/2)*20-10)
                return [p.x,surface.groundHeight(x:p.x,z:p.y),p.y]
            }
            let safe=sites.allSatisfy { site in
                (0..<24).allSatisfy { step in
                    let a=Float(step)*2 * .pi/24,x=site.x+3*cos(a),z=site.z+3*sin(a)
                    let y=surface.groundHeight(x:x,z:z)
                    return abs(y-site.y)<2.5 && !surface.hitsObstacle(at:[x,y+4,z],radius:12)
                }
            }
            if safe { return sites }
        }
        return []
    }
    static func position(site:SIMD3<Float>,index:Int,time:Float,planet:SpacePlanet) -> SIMD3<Float> {
        let angle=time*0.1+Float(index)*1.7
        let x=site.x+cos(angle)*3,z=site.z+sin(angle)*3
        return [x,PlanetExploration(planet:planet).groundHeight(x:x,z:z),z]
    }
    static func stride(index:Int,time:Float) -> Float { sin(time*2.3+Float(index)*1.7)*0.25 }
    static func dustStrength(clearance:Float) -> Float {
        guard clearance.isFinite,clearance>=0,clearance<70 else { return 0 }
        let t=max(0,min(1,(70-clearance)/55))
        return t*t*(3-2*t)
    }
}
