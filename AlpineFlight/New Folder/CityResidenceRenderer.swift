import RealityKit
import UIKit

/// Four prepared model pools. Ownership only toggles visibility; buying never rebuilds the city.
@MainActor
final class CityResidenceRenderer {
    let root = Entity()
    private var homes:[CityPlot:Entity] = [:]
    private var shown:Set<CityPlot> = []
    private var lastHousing:CityHousing?
    private var terraces:[CityPlot:Entity] = [:]
    init() {
        root.name = "Four cleared residential districts"
        for plot in CityPlot.allCases {
            let home = Entity(); home.name = plot.name; home.position = plot.position
            let parts = plot.parts
            for material in 0..<6 {
                if let mesh = Self.mesh(parts.filter { $0.material == material }) {
                    let entity = ModelEntity(mesh:mesh,materials:[Self.material(material,plot:plot)])
                    home.addChild(entity)
                }
            }
            let terrace = Entity(); terrace.name = "Editable terrace"; home.addChild(terrace); terraces[plot] = terrace
            home.isEnabled = false; root.addChild(home); homes[plot] = home
            let outline = Entity(); outline.position = plot.position
            for x:Float in [-690,690] {
                let strip = ModelEntity(mesh:.generateBox(size:[4,2,1380]),materials:[UnlitMaterial(color:.cyan)])
                strip.position = [x,1,0]; outline.addChild(strip)
            }
            for z:Float in [-690,690] {
                let strip = ModelEntity(mesh:.generateBox(size:[1380,2,4]),materials:[UnlitMaterial(color:.cyan)])
                strip.position = [0,1,z]; outline.addChild(strip)
            }
            root.addChild(outline)
        }
    }
    func update(_ housing:CityHousing?) {
        guard lastHousing != housing else { return }
        let owned = housing?.owned ?? []
        for (plot,home) in homes { home.isEnabled = owned.contains(plot) }
        for plot in CityPlot.allCases where owned.contains(plot) {
            guard let terrace = terraces[plot] else { continue }
            terrace.children.removeAll()
            let parts = HomeFurnitureDesign.terraceParts(items:housing?.items(in:plot) ?? [],layout:housing?.layout(in:plot) ?? [:],states:housing?.states(in:plot) ?? [:])
                .map { $0.placed(at:RoomPlacement(x:0,z:0),origin:HomeArea.terraceOrigin,scale:HomeArea.terraceScale) }
            for tint in HomeFurnitureTint.allCases {
                for glow in [false,true] {
                    let batch = parts.filter { $0.tint == tint && $0.glow == glow }.map { ResidencePart(center:$0.center,size:$0.size,material:0,solid:false) }
                    guard let mesh = Self.mesh(batch) else { continue }
                    let material:any RealityKit.Material = glow ? UnlitMaterial(color:tint.color):SimpleMaterial(color:tint.color,roughness:0.6,isMetallic:tint == .gold || tint == .metal)
                    terrace.addChild(ModelEntity(mesh:mesh,materials:[material]))
                }
            }
        }
        shown = owned
        lastHousing = housing
    }
    static func color(_ index:Int,plot:CityPlot) -> UIColor {
        switch index {
        case 0:return .init(red:0.12,green:0.15,blue:0.22,alpha:1)
        case 1:return [.init(red:0.72,green:0.74,blue:0.69,alpha:1),.init(red:0.035,green:0.045,blue:0.08,alpha:1),.init(red:0.45,green:0.52,blue:0.62,alpha:1),.init(red:0.55,green:0.46,blue:0.3,alpha:1)][plot.index]
        case 2:return .init(red:0.78,green:0.59,blue:0.25,alpha:1)
        case 3:return plot == .obsidian ? .systemPurple : plot == .senate ? .systemOrange : .cyan
        case 4:return .init(red:0.08,green:0.34,blue:0.23,alpha:1)
        default:return .init(red:0.04,green:0.48,blue:0.68,alpha:1)
        }
    }
    private static func material(_ index:Int,plot:CityPlot) -> any RealityKit.Material {
        if index == 3 || index == 5 { return UnlitMaterial(color:color(index,plot:plot)) }
        return SimpleMaterial(color:color(index,plot:plot),roughness:0.55,isMetallic:index != 4)
    }
    private static func mesh(_ parts:[ResidencePart]) -> MeshResource? {
        guard !parts.isEmpty else { return nil }
        var positions:[SIMD3<Float>] = [], normals:[SIMD3<Float>] = [], indices:[UInt32] = []
        let faces:[[Int]] = [[4,5,6,7],[1,0,3,2],[0,4,7,3],[5,1,2,6],[3,7,6,2],[0,1,5,4]]
        for part in parts {
            let lo = part.center-part.size/2, hi = part.center+part.size/2
            let points:[SIMD3<Float>] = [[lo.x,lo.y,lo.z],[hi.x,lo.y,lo.z],[hi.x,hi.y,lo.z],[lo.x,hi.y,lo.z],
                                         [lo.x,lo.y,hi.z],[hi.x,lo.y,hi.z],[hi.x,hi.y,hi.z],[lo.x,hi.y,hi.z]]
            for face in faces {
                let corners = face.map { points[$0] }, start = UInt32(positions.count)
                let normal = simd_normalize(simd_cross(corners[1]-corners[0],corners[2]-corners[0]))
                positions += corners; normals += Array(repeating:normal,count:4)
                indices += [start,start+1,start+2,start,start+2,start+3]
            }
        }
        var descriptor = MeshDescriptor(name:"Batched residence architecture")
        descriptor.positions = MeshBuffers.Positions(positions); descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from:[descriptor])
    }
}
