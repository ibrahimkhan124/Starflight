import RealityKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Shared meshes and bounded particle counts; nothing is generated in the flight loop.
@MainActor
final class FlightAdventureRenderer {
    let root = Entity()
    private let weatherRoot = Entity()
    private let platform = Entity()
    private var particles: [ModelEntity] = []
    private var haze: [ModelEntity] = []
    private var mistBanks: [ModelEntity] = []
    private var ghost: Entity?
    private var lastWeather: FlightWeather?
    private var clock: Float = 0
    init() {
        let disk = ModelEntity(mesh:.generateCylinder(height:3,radius:95),materials:[SimpleMaterial(color:.darkGray,roughness:0.7,isMetallic:true)])
        disk.position.y = -18; platform.addChild(disk)
        let light = UnlitMaterial(color:.cyan)
        for i in 0..<16 {
            let angle = Float(i)*2 * .pi/16
            let lamp = ModelEntity(mesh:.generateBox(size:[3,3,8]),materials:[light])
            lamp.position = [sin(angle)*85,-14,cos(angle)*85]; platform.addChild(lamp)
        }
        let beacon = ModelEntity(mesh:.generateCylinder(height:100,radius:1),materials:[light])
        beacon.position = [0,70,0]; platform.addChild(beacon)
        platform.isEnabled = false; root.addChild(platform); root.addChild(weatherRoot)
        let sphere = MeshResource.generateSphere(radius:0.32)
        for _ in 0..<72 {
            let particle = ModelEntity(mesh:sphere,materials:[UnlitMaterial(color:.white)])
            weatherRoot.addChild(particle); particles.append(particle)
        }
        for radius: Float in [220,520,950] {
            var material = UnlitMaterial(color:UIColor.white.withAlphaComponent(0.09)); material.faceCulling = .front
            material.blending = .transparent(opacity:.init(floatLiteral:0.08))
            let shell = ModelEntity(mesh:.generateSphere(radius:radius),materials:[material])
            weatherRoot.addChild(shell); haze.append(shell)
        }
        if let texture = Self.mistTexture() {
            var veil = UnlitMaterial(color:.white)
            veil.color = .init(tint:.white,texture:.init(texture))
            veil.blending = .transparent(opacity:.init(floatLiteral:0.15)); veil.faceCulling = .none
            let mesh = MeshResource.generatePlane(width:560,height:300)
            for _ in 0..<12 {
                let bank = ModelEntity(mesh:mesh,materials:[veil]); weatherRoot.addChild(bank); mistBanks.append(bank)
            }
        }
        weatherRoot.isEnabled = false
    }
    /// A soft alpha texture is made once, shared by every cloud bank, and never rebuilt in flight.
    private static func mistTexture() -> TextureResource? {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
        let image = UIGraphicsImageRenderer(size:CGSize(width:128,height:128),format:format).image { renderer in
            let colors = [UIColor.white.withAlphaComponent(0.85).cgColor,UIColor.white.withAlphaComponent(0.35).cgColor,UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0,0.4,1]) else { return }
            renderer.cgContext.drawRadialGradient(gradient,startCenter:CGPoint(x:64,y:64),startRadius:0,endCenter:CGPoint(x:64,y:64),endRadius:64,options:[])
        }
        guard let cgImage = image.cgImage else { return nil }
        return try? TextureResource.generate(from:cgImage,options:.init(semantic:.color))
    }
    func update(ghostState: FlightState?, template: Entity, target:SIMD3<Float>?,weather:FlightWeather,
                active:Bool,camera:SIMD3<Float>,cameraOrientation:simd_quatf,dt:Float,reducedDetail:Bool) {
        clock += dt
        platform.isEnabled = target != nil
        if let target { platform.position = target }
        if let ghostState {
            if ghost == nil {
                let copy = template.clone(recursive:true)
                func tint(_ entity:Entity) {
                    entity.components.remove(CollisionComponent.self)
                    entity.components.remove(PhysicsBodyComponent.self)
                    if let model = entity as? ModelEntity, var component = model.model {
                        component.materials = component.materials.map { _ in
                            var material = UnlitMaterial(color:.cyan)
                            material.blending = .transparent(opacity:.init(floatLiteral:0.3)); return material
                        }
                        model.model = component
                    }
                    entity.children.forEach(tint)
                }
                tint(copy); ghost = copy; root.addChild(copy)
            }
            ghost?.isEnabled = true; ghost?.position = ghostState.position; ghost?.orientation = ghostState.orientation
        } else { ghost?.isEnabled = false }
        weatherRoot.isEnabled = active && weather != .clear
        guard weatherRoot.isEnabled else { return }
        weatherRoot.position = camera
        if weather != lastWeather {
            let color: UIColor = weather == .dust ? UIColor(red:0.66,green:0.40,blue:0.16,alpha:1) : weather == .rain ? UIColor(red:0.4,green:0.55,blue:0.75,alpha:1) : UIColor(red:0.76,green:0.86,blue:0.92,alpha:1)
            for particle in particles { particle.model?.materials = [UnlitMaterial(color:color.withAlphaComponent(0.6))] }
            for shell in haze { var m = UnlitMaterial(color:color); m.faceCulling = .front; m.blending = .transparent(opacity:.init(floatLiteral:weather == .whiteout ? 0.075:weather == .mist ? 0.065:0.04)); shell.model?.materials = [m] }
            lastWeather = weather
        }
        for (i,bank) in mistBanks.enumerated() {
            bank.isEnabled = i < (reducedDetail ? 5:12)
            let seed = Float(i)
            let drift = sin(clock*0.035+seed*1.7)*210
            let local = SIMD3<Float>(drift,sin(clock*0.025+seed*2.3)*80-25,-100-seed*55)
            bank.position = cameraOrientation.act(local)
            bank.orientation = cameraOrientation
            bank.scale = weather == .mist ? [1.5,1.25,1]:[1,0.65,1]
        }
        let count = weather == .mist ? 0 : reducedDetail ? 28:72
        for (i,p) in particles.enumerated() {
            p.isEnabled = i < count
            let seed = Float(i)
            let fall:Float = weather == .rain ? 45:weather == .whiteout ? 12:3
            let y = (seed*17-clock*fall).truncatingRemainder(dividingBy:120)
            p.position = [sin(seed*2.4+clock*0.22)*90,y < -60 ? y+120:y,cos(seed*1.3+clock*0.15)*90]
            p.scale = weather == .rain ? [0.3,8,0.3] : weather == .dust ? [3,1,2]:[1,1,1]
        }
    }
}
