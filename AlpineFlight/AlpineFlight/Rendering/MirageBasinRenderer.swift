import RealityKit
import UIKit

/// All eight six-Hz dune snapshots are uploaded before the region is visible.
/// Runtime work swaps three prepared meshes; it never generates terrain in flight.
@MainActor
final class MirageBasinRenderer {
    let root=Entity()
    private var snapshots:[[MeshResource]]=[]
    private var dunes:[ModelEntity]=[]
    private var airs:[ModelEntity]=[]
    private var lastPhase = -1
    init() throws {
        root.name="Mirage Basin · Walking Dune and Three Airs"
        root.position=[MirageBasin.center.x,MirageBasin.foundation,MirageBasin.center.y]
        let colors:[UIColor] = [.init(red:0.78,green:0.48,blue:0.24,alpha:1),.init(red:0.94,green:0.72,blue:0.42,alpha:1),.init(red:0.58,green:0.36,blue:0.34,alpha:1)]
        for phase in 0..<MirageBasin.phases {
            snapshots.append(try MirageBasin.meshes(phase:phase).map { try AetherPlanetRenderer.mesh($0,name:"Prepared walking dune phase \(phase)") })
        }
        for i in 0..<3 {
            let entity=ModelEntity(mesh:snapshots[0][i],materials:[SimpleMaterial(color:colors[i],roughness:1,isMetallic:false)])
            entity.name="Living dune layer \(i)";root.addChild(entity);dunes.append(entity)
        }
        let hues:[UIColor] = [.init(red:0.10,green:0.72,blue:0.74,alpha:1),.init(red:1,green:0.62,blue:0.15,alpha:1),.init(red:0.98,green:0.45,blue:0.67,alpha:1)]
        let mesh=MeshResource.generatePlane(width:450,depth:450)
        for i in 0..<3 {
            guard let material=ScenicMaterials.mirageAir(color:hues[i]) else { continue }
            let entity=ModelEntity(mesh:mesh,materials:[material]);entity.name="Three Airs layer \(i)"
            entity.position.y=Float(35+i*75);entity.components.set(DynamicLightShadowComponent(castsShadow:false))
            root.addChild(entity);airs.append(entity)
        }
        update(time:0)
    }
    func update(time:Float) {
        let phase=MirageBasin.phase(at:time)
        if phase != lastPhase {
            for i in dunes.indices { dunes[i].model?.mesh=snapshots[phase][i] }
            lastPhase=phase
        }
        for (i,air) in airs.enumerated() {
            air.position.y=Float(35+i*75)+3*sin(time*0.4+Float(i)*2.1)
            air.orientation=simd_quatf(angle:time*0.025*(i.isMultiple(of:2) ? 1:-1),axis:[0,1,0])
        }
    }
}
