import Foundation
import simd

enum PlanetWildlife {
    enum Kind { case bantha,forestDeer,tauntaun }
    static func kind(on planet:SpacePlanet) -> Kind? {
        switch planet { case .tatooine:return .bantha;case .endor:return .forestDeer;case .hoth:return .tauntaun;case .coruscant:return nil }
    }
    static func scale(index:Int) -> Float { index.isMultiple(of:2) ? 2.4:1.9 }
    private static let full:[SpacePlanet:[SIMD3<Float>]] = Dictionary(uniqueKeysWithValues:SpacePlanet.allCases.map { ($0,makeSites(on:$0,reduced:false)) })
    private static let reduced:[SpacePlanet:[SIMD3<Float>]] = Dictionary(uniqueKeysWithValues:SpacePlanet.allCases.map { ($0,makeSites(on:$0,reduced:true)) })
    static func sites(on planet:SpacePlanet,reduced:Bool) -> [SIMD3<Float>] {
        (reduced ? self.reduced:full)[planet] ?? []
    }
    private static func makeSites(on planet:SpacePlanet,reduced:Bool) -> [SIMD3<Float>] {
        guard kind(on:planet) != nil else { return [] }
        let surface=PlanetExploration(planet:planet)
        let routeZ:[Float]=[8100,6000,3900,1800,-500,-2800,-5100,-7400]
        var anchors:[SIMD2<Float>]=routeZ.map { z in
            let x:Float = planet == .tatooine ? surface.canyonCenter(z:z) : planet == .hoth ? surface.glacierCenter(z:z):1000*sin(z*0.00025)
            return [x,z]
        }
        if planet == .tatooine { anchors += CanyonRoutes.routes.prefix(3).map { $0.point(0.55) } }
        var result:[SIMD3<Float>]=[]
        for anchor in anchors {
            for offset:SIMD2<Float> in [[180,-160],[-180,-180],[300,-240],[-300,-240],[420,-200],[-420,-200],[90,-120],[-90,-120]] {
                let center=anchor+offset
                let sites=(0..<(reduced ? 1:2)).map { i -> SIMD3<Float> in
                    let p=center+SIMD2<Float>(i == 0 ? -28:28,i == 0 ? -15:25)
                    return [p.x,surface.groundHeight(x:p.x,z:p.y),p.y]
                }
                let safe=sites.allSatisfy { site in
                    (0..<24).allSatisfy { step in
                        let a=Float(step)*2 * .pi/24,x=site.x+3*cos(a),z=site.z+3*sin(a)
                        let y=surface.groundHeight(x:x,z:z)
                        return abs(y-site.y)<2.5 && !surface.hitsObstacle(at:[x,y+8,z],radius:24)
                    }
                }
                if safe { result += sites;break }
            }
        }
        return result
    }
    static func position(site:SIMD3<Float>,index:Int,time:Float,planet:SpacePlanet) -> SIMD3<Float> {
        let angle=time*0.1+Float(index)*1.7
        let x=site.x+cos(angle)*3,z=site.z+sin(angle)*3
        return [x,PlanetExploration(planet:planet).groundHeight(x:x,z:z),z]
    }
    static func stride(index:Int,time:Float) -> Float { sin(time*2.3+Float(index)*1.7)*0.25 }
    static func dustStrength(clearance:Float) -> Float {
        guard clearance.isFinite,clearance>=0,clearance<150 else { return 0 }
        let t=max(0,min(1,(150-clearance)/135))
        return t*t*(3-2*t)
    }
}
