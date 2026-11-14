import RealityKit
import UIKit
import Combine
import ProceduralCore

/// Focused MeshData -> RealityKit adapter. No Aether demo engine or shader host.
@MainActor
enum AetherPlanetRenderer {
    static let status = AetherPreparationStatus()
    static var ready:Bool { get { status.ready } set { status.ready = newValue } }
    static var failure:String? { get { status.failure } set { status.failure = newValue } }
    static func mesh(_ source:MeshData,name:String,terrainUV:Bool = false, worldUVScale:Float? = nil) throws -> MeshResource {
        var descriptor = MeshDescriptor(name:name)
        descriptor.positions = .init(source.positions)
        descriptor.normals = .init(source.normals)
        descriptor.textureCoordinates = .init(source.positions.map {
            if let scale = worldUVScale { return SIMD2($0.x/scale,$0.z/scale) }
            return terrainUV ? SIMD2(($0.x+AetherPlanet.extent)/(2*AetherPlanet.extent),1-($0.z+AetherPlanet.extent)/(2*AetherPlanet.extent)) : SIMD2($0.x/80,$0.y/80)
        })
        descriptor.primitives = .triangles(source.indices)
        return try MeshResource.generate(from:[descriptor])
    }
    static func hothTiles(_ asset:AetherHothTerrain.Prepared,reducedDetail:Bool) throws -> [ModelEntity] {
        let material = ScenicMaterials.terrain(color:.white,kind:"snow",planet:"Hoth",continuous:true,reducedDetail:reducedDetail)
        return try asset.tiles.map { tile in
            let entity = ModelEntity(mesh:try mesh(tile.renderMesh,name:"Hoth Aether tile",worldUVScale:180),materials:[material])
            entity.name = "Hoth Aether ground \(tile.x),\(tile.z)"
            return entity
        }
    }
    static func make(_ asset:AetherPlanet.Prepared,enhanced:Bool = true) throws -> Entity {
        let root = Entity(); root.name = "Aether Reach prepared expedition"
        var paint = PhysicallyBasedMaterial(); paint.baseColor = .init(tint:UIColor(red:0.35,green:0.48,blue:0.30,alpha:1)); paint.roughness = .init(floatLiteral:0.9)
        if enhanced {
            let size = asset.textureSize
            guard let provider = CGDataProvider(data:Data(asset.pixels) as CFData),
                  let image = CGImage(width:size,height:size,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:size*4,
                    space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),
                    provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent) else { throw CocoaError(.fileReadCorruptFile) }
            paint.baseColor = .init(tint:.white,texture:.init(try TextureResource(image:image,options:.init(semantic:.color))))
        }
        let terrain = ModelEntity(mesh:try mesh(asset.grid.mesh,name:"Aether Reach terrain",terrainUV:true),materials:[paint])
        terrain.name = "Aether triangle-aligned ground"; root.addChild(terrain)
        let arch = ModelEntity(mesh:try mesh(asset.arch,name:"Aether rock arch"),materials:[ScenicMaterials.terrain(color:.init(red:0.46,green:0.39,blue:0.30,alpha:1),kind:"rock")])
        arch.name = "Aether rock arch"; arch.position = AetherPlanet.archPosition(asset); root.addChild(arch)
        let sky = ModelEntity(mesh:.generateSphere(radius:48000),materials:[ScenicMaterials.sky(zenith:.init(red:0.12,green:0.30,blue:0.45,alpha:1),horizon:.init(red:0.63,green:0.77,blue:0.72,alpha:1))])
        sky.name = "Aether prepared sky"; sky.components.set(DynamicLightShadowComponent(castsShadow:false)); root.addChild(sky)
        return root
    }
}

@MainActor
final class AetherPreparationStatus:ObservableObject {
    @Published var ready = false
    @Published var failure:String?
}
