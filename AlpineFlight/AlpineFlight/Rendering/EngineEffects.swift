import RealityKit
import UIKit

/// Reuses a handful of tiny meshes. No particle allocation or scene searches in flight.
@MainActor
final class EngineEffects {
    struct Nozzle {
        let position: SIMD3<Float>
        let radius: Float
    }
    private struct SourceLayout: Decodable {
        struct SourceNozzle: Decodable { let position:[Float]; let radius:Float }
        let width:Float
        let length:Float
        let nozzles:[SourceNozzle]
    }
    private static let sourceLayouts: [String:SourceLayout] = {
        guard let url = Bundle.main.url(forResource:"EngineNozzles",withExtension:"json",subdirectory:"Ships"),
              let data = try? Data(contentsOf:url), let layouts = try? JSONDecoder().decode([String:SourceLayout].self,from:data) else { return [:] }
        return layouts
    }()
    static func layout(for ship: AircraftType) -> [Nozzle] {
        if let source = sourceLayouts[ship.rawValue] {
            let sx = ship.wingspan/source.width, sz = ship.length/source.length
            let scale = SIMD3<Float>(sx,min(sx,sz),sz)
            return source.nozzles.prefix(4).compactMap { item in
                guard item.position.count == 3 else { return nil }
                return Nozzle(position:SIMD3<Float>(item.position[0],item.position[1],item.position[2])*scale,radius:clamp(item.radius*min(sx,sz),0.12,2))
            }
        }
        if ship == .starDestroyer {
            return [(-6.0, 2.1), (0.0, 2.4), (6.0, 2.1), (-11.0, 0.8), (-3.0, 0.8), (3.0, 0.8), (11.0, 0.8)].map {
                Nozzle(position: [Float($0.0), -0.1, 25.64], radius: Float($0.1) * 0.82)
            }
        }
        let span = ship.wingspan, length = ship.length
        let points: [(Float,Float,Float,Float)]
        switch ship {
        case .xwing,.starkJet:
            points = [(-0.22,0.65,0.32,0.42),(0.22,0.65,0.32,0.42),(-0.22,-0.65,0.32,0.42),(0.22,-0.65,0.32,0.42)]
        case .tieFighter,.tieDefender,.tieInterceptor:
            points = [(-0.04,0,0.23,0.25),(0.04,0,0.23,0.25)]
        case .anakinPodracer,.sebulbaPodracer,.quadinPodracer,.rattsPodracer,.nevaKeePodracer,.voltwingPodracer:
            points = [(-0.34,0,0.02,0.85),(0.34,0,0.02,0.85)]
        case .yWing,.n1Starfighter,.razorCrest:
            points = [(-0.32,0,0.43,0.7),(0.32,0,0.43,0.7)]
        case .enterprise,.voyager:
            points = [(-0.34,-0.6,0.2,0.7),(0.34,-0.6,0.2,0.7)]
        case .millenniumFalcon:
            points = [(-0.12,0,0.44,0.8),(0,0,0.47,0.8),(0.12,0,0.44,0.8)]
        case .slaveI:
            points = [(-0.13,-0.7,0.40,0.8),(0.13,-0.7,0.40,0.8)]
        case .scimitar:
            points = [(-0.13,0,0.40,0.65),(0.13,0,0.40,0.65)]
        default:
            points = [(-0.12,0,0.42,0.55),(0.12,0,0.42,0.55)]
        }
        return points.map { Nozzle(position:[$0.0*span,$0.1,$0.2*length],radius:$0.3) }
    }
    let root = Entity()
    private var jets: [(Entity,Entity,Float)] = []
    private(set) var strength: Float = 0
    private var time: Float = 0
    init(on aircraft: Entity, type: AircraftType) {
        root.name = "Animated engine exhaust"
        let mesh = MeshResource.generateSphere(radius:1)
        let ion = [.tieFighter,.tieDefender,.tieInterceptor,.scimitar].contains(type)
        let hot = UnlitMaterial(color:ion ? .init(red:1,green:0.65,blue:0.4,alpha:1):.init(red:0.75,green:0.95,blue:1,alpha:1))
        var haze = UnlitMaterial(color:ion ? .systemRed : type.isPodracer ? .systemOrange : .systemCyan)
        haze.blending = .transparent(opacity:.init(floatLiteral:0.28))
        var authored: [Nozzle] = []
        func collect(_ entity: Entity) {
            if entity.name.hasPrefix("EngineNozzle_") {
                let m = entity.transformMatrix(relativeTo:aircraft)
                let radius = simd_length(SIMD3<Float>(m.columns.0.x,m.columns.0.y,m.columns.0.z))
                authored.append(Nozzle(position:entity.position(relativeTo:aircraft),radius:clamp(radius,0.12,2)))
            }
            for child in entity.children { collect(child) }
        }
        collect(aircraft)
        let nozzles = authored.isEmpty ? Self.layout(for:type) : Array(authored.prefix(4))
        for (index,nozzle) in nozzles.enumerated() {
            let mount = Entity(); mount.name = "Engine nozzle \(index+1)"; mount.position = nozzle.position
            let core = ModelEntity(mesh:mesh,materials:[hot]); core.name = "Plasma core"
            let plume = ModelEntity(mesh:mesh,materials:[haze]); plume.name = "Exhaust plume"
            mount.addChild(core); mount.addChild(plume); root.addChild(mount)
            jets.append((core,plume,nozzle.radius))
        }
        aircraft.addChild(root)
        update(throttle:0,boosting:false,dt:0)
    }
    func update(throttle:Float,boosting:Bool,dt:Float) {
        let delta = dt.isFinite ? clamp(dt,0,0.1) : 0
        time += delta
        let target = throttle.isFinite ? clamp(abs(throttle),0,1) : 0
        strength += (target-strength)*(1-exp(-delta*9))
        for (index,jet) in jets.enumerated() {
            let pulse = 1+0.055*sin(time*23+Float(index)*1.7)
            let radius = jet.2*(0.6+strength*0.4)*pulse
            let length = (0.25+strength*3.6)*(boosting ? 1.7 : 1)*jet.2
            jet.0.scale = [radius*0.65,radius*0.65,length*0.45]
            jet.0.position.z = length*0.35
            jet.1.scale = [radius,radius,length]
            jet.1.position.z = length*0.85
        }
    }
}
