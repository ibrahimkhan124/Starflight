import RealityKit
import simd

@MainActor
enum ArenaScenery {
    /// Three great circles form a readable boundary with one shared mesh/material.
    static func make() -> Entity {
        let root = Entity(); root.name = "Duel arena boundary"
        var vertices: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        let r = ArenaDuel.radius
        for plane in 0..<3 {
            for segment in 0..<96 {
                let a = Float(segment)*2 * .pi/96, b = Float(segment+1)*2 * .pi/96
                func point(_ angle: Float, _ radius: Float) -> SIMD3<Float> {
                    let x = cos(angle)*radius, y = sin(angle)*radius
                    return plane == 0 ? [x,0,y] : plane == 1 ? [x,y,0] : [0,x,y]
                }
                let base = UInt32(vertices.count)
                vertices += [point(a,r-2),point(a,r+2),point(b,r+2),point(b,r-2)]
                indices += [base,base+1,base+2,base,base+2,base+3,base+2,base+1,base,base+3,base+2,base]
            }
        }
        var descriptor = MeshDescriptor(name:"Holographic arena")
        descriptor.positions = .init(vertices); descriptor.primitives = .triangles(indices)
        if let mesh = try? MeshResource.generate(from:[descriptor]) {
            root.addChild(ModelEntity(mesh:mesh,materials:[UnlitMaterial(color:.cyan.withAlphaComponent(0.7))]))
        }
        root.isEnabled = false
        return root
    }
}
