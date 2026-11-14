import RealityKit
import UIKit
import simd

/// Every mesh is prepared up front. Selection changes only when its projected
/// silhouette error is below a pixel, with hysteresis to avoid repeated swaps.
/// The flying terrain uses its immutable collision mesh throughout.
@MainActor
final class PlanetOrbitDetail {
    let entity: ModelEntity
    let radius: Float
    private let meshes: [MeshResource]
    private(set) var selectedLevel = 1
    let triangleCounts: [Int]

    init(entity: ModelEntity, name: String, radius: Float) {
        self.entity = entity; self.radius = radius
        let resolutions = [32,64,128]
        meshes = resolutions.map { Self.sphere(name:name,radius:radius,longitude:$0) }
        triangleCounts = resolutions.map { $0*($0/2-1)*2 }
        entity.model?.mesh = meshes[1]
    }
    func update(camera: SIMD3<Float>, reduced: Bool) {
        let angularSize = radius / max(radius,simd_distance(camera,entity.position(relativeTo:nil)))
        let next = Self.level(angularSize:angularSize,current:selectedLevel,reduced:reduced)
        if next != selectedLevel { entity.model?.mesh = meshes[next]; selectedLevel = next }
    }
    static func level(angularSize: Float, current: Int, reduced: Bool) -> Int {
        guard angularSize.isFinite else { return current }
        if reduced {
            if current == 0 { return angularSize>0.032 ? 1:0 }
            return angularSize<0.020 ? 0:1
        }
        if current == 0 { return angularSize>0.032 ? 1:0 }
        if current == 2 { return angularSize<0.070 ? 1:2 }
        if angularSize<0.020 { return 0 }
        return angularSize>0.100 ? 2:1
    }
    private static func sphere(name: String, radius: Float, longitude: Int) -> MeshResource {
        let latitude = longitude/2, columns = longitude+1
        var positions:[SIMD3<Float>] = [], normals:[SIMD3<Float>] = [], uv:[SIMD2<Float>] = [], indices:[UInt32] = []
        for row in 0...latitude { for column in 0...longitude {
            let u = Float(column)/Float(longitude),v = Float(row)/Float(latitude)
            let elevation = Float.pi/2-v*Float.pi, angle = u*Float.pi*2-Float.pi
            let normal = SIMD3<Float>(cos(elevation)*cos(angle),sin(elevation),cos(elevation)*sin(angle))
            let relief = Self.relief(name:name,direction:normal)
            positions.append(normal*radius*(1+relief));normals.append(normal);uv.append([u,v])
        } }
        for row in 0..<latitude { for column in 0..<longitude {
            let a = UInt32(row*columns+column),b=a+1,c=a+UInt32(columns),d=c+1
            if row>0 { indices += [a,b,c] }
            if row<latitude-1 { indices += [b,d,c] }
        } }
        var mesh = MeshDescriptor(name:name+" prepared orbit detail \(longitude)")
        mesh.positions = .init(positions);mesh.normals = .init(normals);mesh.textureCoordinates = .init(uv)
        mesh.primitives = .triangles(indices)
        return (try? MeshResource.generate(from:[mesh])) ?? .generateSphere(radius:radius)
    }
    private static func relief(name: String, direction: SIMD3<Float>) -> Float {
        if name == "Mercury" {
            var height: Float = 0
            for i in 0..<14 {
                let t = Float(i)+1
                let center = simd_normalize(SIMD3<Float>(sin(t*11.3),cos(t*7.1),sin(t*17.7+1)))
                let distance = acos(clamp(simd_dot(center,direction),-1,1))/Float(0.13+Float(i%4)*0.045)
                if distance<1.4 { height += 0.002*exp(-pow((distance-1)*7,2))-0.0028*max(0,1-distance*distance) }
            }
            return height
        }
        guard name == "Mars" || name == "Venus" else { return 0 }
        let a = sin(direction.x*17+sin(direction.z*11))*cos(direction.y*19-direction.z*8)
        let b = sin(direction.z*31+direction.y*7)*0.25
        return (abs(a)+b)*0.0025
    }
}

@MainActor
enum PlanetOrbitAtmosphere {
    static func add(to root: Entity, name: String, radius: Float, tint: UIColor) {
        let code = ScenicMaterials.planetCode(name)
        guard code>0, name != "Mercury" else { return }
        let glow = ModelEntity(mesh:.generateSphere(radius:radius*1.035),materials:[ScenicMaterials.atmosphere(planet:name,color:tint)])
        glow.name = name+" atmospheric scattering"
        glow.components.set(DynamicLightShadowComponent(castsShadow:false))
        root.addChild(glow)
        if name != "Coruscant" {
            let clouds = ModelEntity(mesh:.generateSphere(radius:radius*1.012),materials:[ScenicMaterials.cloud(color:.init(white:0.95,alpha:1),planet:name,orbital:true)])
            clouds.name = name+" orbital cloud layer"
            clouds.components.set(DynamicLightShadowComponent(castsShadow:false))
            root.addChild(clouds)
        }
    }
}
