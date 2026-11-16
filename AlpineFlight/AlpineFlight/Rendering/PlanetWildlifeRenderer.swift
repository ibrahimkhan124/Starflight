import RealityKit
import UIKit
import ProceduralGeometry

/// A small prepared herd: shared native meshes, articulated legs/head/tail.
/// Native terrain-following/graze animation informed by Portals' land-fauna kit.
@MainActor
final class PlanetWildlifeRenderer {
    let root=Entity()
    private struct Animal {
        let root:Entity,head:Entity,tail:Entity
        let legs:[Entity]
        let site:SIMD3<Float>
    }
    private var animals:[Animal]=[]
    private let planet:SpacePlanet
    private var lastTime:Float = -1
    init(planet:SpacePlanet,reduced:Bool) {
        self.planet=planet;root.name="Prepared ground wildlife"
        guard let kind=PlanetWildlife.kind(on:planet) else { return }
        guard let sphere=try? Self.roundedMesh() else { return }
        let legMesh=sphere
        let box=MeshResource.generateBox(size:1)
        let horn=(try? ArchitecturalGeometry.moulding(radius:1,tube:0.18,sweep:4.9,segments:20,sides:6)).flatMap { try? AetherPlanetRenderer.mesh($0,name:"Shared curved wildlife horn") }
        let coat:UIColor = kind == .bantha ? .init(red:0.34,green:0.20,blue:0.10,alpha:1) : kind == .forestDeer ? .init(red:0.50,green:0.28,blue:0.12,alpha:1) : .init(red:0.72,green:0.76,blue:0.72,alpha:1)
        let fur=SimpleMaterial(color:coat,roughness:1,isMetallic:false)
        let dark=SimpleMaterial(color:.init(white:0.045,alpha:1),roughness:0.8,isMetallic:false)
        let ivory=SimpleMaterial(color:.init(red:0.79,green:0.69,blue:0.49,alpha:1),roughness:0.9,isMetallic:false)
        let large=kind == .bantha
        func part(_ parent:Entity,_ mesh:MeshResource,_ position:SIMD3<Float>,_ scale:SIMD3<Float>,_ material:SimpleMaterial) -> ModelEntity {
            let entity=ModelEntity(mesh:mesh,materials:[material]);entity.position=position;entity.scale=scale;parent.addChild(entity);return entity
        }
        for (index,site) in PlanetWildlife.sites(on:planet,reduced:reduced).enumerated() {
            let animal=Entity(),head=Entity(),tail=Entity()
            animal.name=(large ? "Bantha":kind == .forestDeer ? "Forest deer":"Tauntaun")+" \(index+1)"
            animal.scale=SIMD3(repeating:PlanetWildlife.scale(index:index))
            let hip:Float = large ? 2.2:kind == .forestDeer ? 1.6:2.2
            part(animal,sphere,[0,hip+0.8,0],large ? [1.7,1.5,2.7]:kind == .forestDeer ? [0.7,0.8,1.7]:[1.0,1.4,1.4],fur)
            if large {
                // Layered shaggy flank tufts make the bantha's silhouette distinct.
                for side:Float in [-1,1] { for i in 0..<7 {
                    part(animal,sphere,[side*1.35,hip-0.05,Float(i)*0.65-2],[0.40,0.9+Float(i%3)*0.13,0.4],fur)
                } }
            }
            let headHeight:Float = large ? 3.8:kind == .forestDeer ? 3.6:4.8
            head.position=[0,headHeight,large ? 2.25:1.35];animal.addChild(head)
            part(head,sphere,[0,0,0.35],large ? [1.2,1.0,1.1]:[0.5,0.55,0.9],fur)
            part(head,sphere,[0,-0.25,large ? 1.1:0.95],large ? [0.65,0.45,0.6]:[0.36,0.26,0.5],fur)
            // The neck connects the elevated deer/tauntaun head to the shoulders.
            if !large { part(animal,sphere,[0,(headHeight+hip+0.8)/2,1],[0.4,(headHeight-hip)/2,0.5],fur) }
            for side:Float in [-1,1] {
                part(head,sphere,[side*(large ? 0.8:0.4),0.2,large ? 0.9:0.75],[0.10,0.12,0.09],dark)
                let ear=part(head,sphere,[side*(large ? 1.05:0.6),0.6,0],large ? [0.45,0.28,0.22]:[0.20,0.55,0.18],fur)
                ear.orientation=simd_quatf(angle:side*0.5,axis:[0,0,1])
                if kind != .forestDeer,let horn {
                    let curl=part(head,horn,[side*(large ? 1.35:0.65),0.25,0],SIMD3(repeating:large ? 1.1:0.45),ivory)
                    curl.orientation=simd_quatf(angle:side*0.35,axis:[0,1,0])
                } else if kind == .forestDeer {
                    for i in 0..<3 {
                        let antler=part(head,box,[side*(0.4+Float(i)*0.22),0.9+Float(i)*0.3,-0.1],[0.12,0.9,0.12],ivory)
                        antler.orientation=simd_quatf(angle:-side*Float(i)*0.3,axis:[0,0,1])
                    }
                }
            }
            var legs:[Entity]=[]
            for i in 0..<(kind == .tauntaun ? 2:4) {
                let side:Float=i.isMultiple(of:2) ? -1:1
                let pivot=Entity();pivot.position=[side*(large ? 1.0:0.48),hip,kind == .tauntaun ? -0.2:(i<2 ? 1.25:-1.25)]
                let limb=part(pivot,legMesh,[0,-hip/2,0],[large ? 0.48:0.18,hip/2,large ? 0.48:0.18],fur)
                limb.name="Articulated leg"
                part(pivot,sphere,[0,-hip+0.12,0.15],[large ? 0.5:0.24,0.22,large ? 0.65:0.36],dark)
                animal.addChild(pivot);legs.append(pivot)
            }
            tail.position=[0,hip+0.7,large ? -2.4:-1.5];animal.addChild(tail)
            part(tail,sphere,[0,-0.4,-0.4],[large ? 0.24:0.12,0.6,kind == .tauntaun ? 1.2:0.3],fur)
            root.addChild(animal);animals.append(Animal(root:animal,head:head,tail:tail,legs:legs,site:site))
        }
        update(time:0)
    }
    private static func roundedMesh() throws -> MeshResource {
        let rows=8,slices=12
        var positions:[SIMD3<Float>]=[],indices:[UInt32]=[]
        for row in 0...rows { for slice in 0...slices {
            let a = -Float.pi/2+Float(row)*Float.pi/Float(rows),b=Float(slice)*2 * .pi/Float(slices)
            positions.append([cos(a)*cos(b),sin(a),cos(a)*sin(b)])
        } }
        for row in 0..<rows { for slice in 0..<slices {
            let low=UInt32(row*(slices+1)+slice),high=low+UInt32(slices+1)
            if row>0 { indices += [low,high,low+1] }
            if row<rows-1 { indices += [low+1,high,high+1] }
        } }
        var descriptor=MeshDescriptor(name:"Shared 168-triangle wildlife surface")
        descriptor.positions = .init(positions);descriptor.normals = .init(positions);descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from:[descriptor])
    }
    func update(time:Float,viewer:SIMD3<Float>?=nil) {
        guard lastTime<0 || abs(time-lastTime)>=1/30 else { return }
        lastTime=time
        for (i,animal) in animals.enumerated() {
            if let viewer {
                let distance=simd_distance(SIMD2(viewer.x,viewer.z),SIMD2(animal.site.x,animal.site.z))
                let visible=distance<1500
                if animal.root.isEnabled != visible { animal.root.isEnabled=visible }
                guard visible else { continue }
                animal.root.components.set(OpacityComponent(opacity:max(0,min(1,(1500-distance)/500))))
            }
            let angle=time*0.1+Float(i)*1.7
            animal.root.position=PlanetWildlife.position(site:animal.site,index:i,time:time,planet:planet)
            animal.root.orientation=simd_quatf(angle:atan2(-sin(angle),cos(angle)),axis:[0,1,0])
            let graze=max(0,sin(time*0.28+Float(i)))
            animal.head.orientation=simd_quatf(angle:graze*0.3,axis:[1,0,0])*simd_quatf(angle:sin(time*0.6+Float(i))*0.15,axis:[0,1,0])
            animal.tail.orientation=simd_quatf(angle:sin(time*1.2+Float(i))*0.35,axis:[0,0,1])
            for (legIndex,leg) in animal.legs.enumerated() {
                let sign:Float = legIndex == 0 || legIndex == 3 ? 1:-1
                leg.orientation=simd_quatf(angle:PlanetWildlife.stride(index:i,time:time)*sign,axis:[1,0,0])
            }
        }
    }
}
