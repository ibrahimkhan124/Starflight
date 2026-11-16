import Foundation
import simd

enum PlanetWildlife {
    enum Kind { case bantha,forestDeer,tauntaun }
    static func kind(on planet:SpacePlanet) -> Kind? {
        switch planet { case .tatooine:return .bantha;case .endor:return .forestDeer;case .hoth:return .tauntaun;case .coruscant:return nil }
    }
    static func birdName(on planet:SpacePlanet) -> String {
        switch planet { case .tatooine:return "Soaring canyon glider";case .endor:return "Forest glider";case .hoth:return "Ice glider";case .coruscant:return "Rooftop glider" }
    }
    private static let birdHomes:[SpacePlanet:[SIMD3<Float>]] = Dictionary(uniqueKeysWithValues:SpacePlanet.allCases.filter { $0 != .tatooine }.map { planet in
        let surface=PlanetExploration(planet:planet)
        let routeZ:[Float]=[7800,5600,3400,1200,-1000,-3200,-5400,-7600]
        let homes=routeZ.enumerated().map { i,z -> SIMD3<Float> in
            let side:Float=i.isMultiple(of:2) ? -1:1
            let x:Float=planet == .hoth ? surface.glacierCenter(z:z)+side*240 : planet == .endor ? 1000*sin(z*0.00025)+side*260 : side*900
            var ceiling:Float=0
            for step in 0..<64 {
                let a=Float(step)*2 * .pi/64
                ceiling=max(ceiling,surface.groundHeight(x:x+cos(a)*160,z:z+sin(a)*240))
            }
            // Prepared canopy/roof clearance covers the entire orbit and wingspan.
            for obstacle in surface.obstacles where abs(obstacle.center.x-x)<obstacle.size.x/2+230 && abs(obstacle.center.z-z)<obstacle.size.z/2+310 {
                ceiling=max(ceiling,obstacle.center.y+obstacle.size.y/2)
            }
            return [x,ceiling+110,z]
        }
        return (planet,homes)
    })
    static func bird(_ index:Int,time:Float,planet:SpacePlanet) -> CanyonLife.BirdPose {
        if planet == .tatooine {
            let pose=CanyonLife.bird(index,time:time)
            return .init(position:TatooineCanyon.origin+pose.position,heading:pose.heading,bank:pose.bank,wing:pose.wing)
        }
        let home=birdHomes[planet]![index%CanyonLife.flockCount]
        let phase=Float(index)*1.31,a=time*0.1+phase
        let beat=max(0,sin(time*0.38+phase))
        return .init(position:home+[cos(a)*160,sin(time*0.21+phase)*14,sin(a)*240],heading:atan2(-sin(a)*160,cos(a)*240),bank:-0.14+sin(a)*0.05,wing:0.12+sin(time*5.5+phase)*0.52*beat*beat)
    }
    static func lookoutPosition(site:SIMD3<Float>,planet:SpacePlanet,standOff:Float,clearance:Float) -> SIMD3<Float> {
        let surface=PlanetExploration(planet:planet),targetY=site.y+7
        let z=site.z+standOff
        var height=max(site.y,surface.groundHeight(x:site.x,z:z))+clearance
        // Keep the inspection sightline above intervening hills, not just its endpoints.
        for step in 1...32 {
            let fraction=Float(step)/32
            let ground=surface.groundHeight(x:site.x,z:site.z+standOff*fraction)
            height=max(height,targetY+(ground+4-targetY)/fraction)
        }
        return [site.x,height,z]
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


/// Earth uses the SolarLandscape triangle mesh rather than the home-sector terrain.
enum EarthWildlife {
    static let field=SolarLandscape(body:SolarBody.all.first { $0.name == "Earth" }!)
    static let routeZ:[Float]=[10800,8200,5600,3000,400,-2200,-4800,-7400,-10000]
    static let sites:[SIMD3<Float>]=routeZ.flatMap { z -> [SIMD3<Float>] in
        for side:Float in [1,-1] { for offset:Float in [210,340,470,600] {
            let x=field.riverCenter(z:z)+side*offset
            let herd:[SIMD3<Float>]=[-24,24].map { dx in [x+dx,field.height(x:x+dx,z:z),z] }
            if herd.allSatisfy({ site in
                (0..<24).allSatisfy { step in
                    let p=position(site:site,index:0,time:Float(step)*2.7)
                    return abs(p.y-site.y)<2.5 && p.y>max(4,field.riverLevel(z:p.z)+2) &&
                        !field.scenerySolids.contains { tree in
                            simd_distance(SIMD2(p.x,p.z),SIMD2(tree.base.x,tree.base.z))<tree.height*0.4+18
                        }
                }
            }) { return herd }
        } }
        return []
    }
    static func sites(reduced:Bool) -> [SIMD3<Float>] {
        reduced ? sites.enumerated().filter { $0.offset.isMultiple(of:2) }.map(\.element):sites
    }
    static func position(site:SIMD3<Float>,index:Int,time:Float) -> SIMD3<Float> {
        let a=time*0.1+Float(index)*1.7,x=site.x+cos(a)*3,z=site.z+sin(a)*3
        return [x,field.height(x:x,z:z),z]
    }
    private static let birdHomes:[SIMD3<Float>]=routeZ.map { z in
        let x=field.riverCenter(z:z)
        var ceiling:Float=0
        for step in 0..<64 {
            let a=Float(step)*2 * .pi/64
            ceiling=max(ceiling,field.height(x:x+cos(a)*180,z:z+sin(a)*280))
        }
        for tree in field.scenerySolids where abs(tree.base.x-x)<tree.height*0.4+210 && abs(tree.base.z-z)<tree.height*0.4+310 {
            ceiling=max(ceiling,tree.base.y+tree.height*1.25)
        }
        return [x,ceiling+110,z]
    }
    static func birdCount(reduced:Bool) -> Int { routeZ.count*(reduced ? 1:3) }
    static func bird(_ index:Int,time:Float) -> CanyonLife.BirdPose {
        let home=birdHomes[index%birdHomes.count],phase=Float(index)*1.31,a=time*0.10+phase
        let beat=max(0,sin(time*0.38+phase))
        return .init(position:home+[cos(a)*180,sin(time*0.21+phase)*14,sin(a)*280],heading:atan2(-sin(a)*180,cos(a)*280),bank:-0.12+sin(a)*0.05,wing:0.12+sin(time*5.5+phase)*0.52*beat*beat)
    }
}
