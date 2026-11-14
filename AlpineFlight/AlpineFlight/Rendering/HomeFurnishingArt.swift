import SceneKit
import UIKit

extension HomeFurnitureTint {
    var color:UIColor {
        switch self {
        case .stone:return .init(red:0.23,green:0.27,blue:0.34,alpha:1)
        case .ivory:return .init(red:0.78,green:0.79,blue:0.73,alpha:1)
        case .metal:return .init(red:0.07,green:0.09,blue:0.14,alpha:1)
        case .gold:return .init(red:0.72,green:0.51,blue:0.24,alpha:1)
        case .teal:return .init(red:0.08,green:0.65,blue:0.72,alpha:1)
        case .violet:return .init(red:0.62,green:0.19,blue:0.92,alpha:1)
        case .green:return .init(red:0.12,green:0.45,blue:0.27,alpha:1)
        case .amber:return .init(red:1,green:0.46,blue:0.08,alpha:1)
        case .water:return .init(red:0.06,green:0.5,blue:0.95,alpha:1)
        case .glass:return .init(red:0.1,green:0.2,blue:0.3,alpha:1)
        case .white:return .init(white:0.9,alpha:1)
        }
    }
}

@MainActor
enum HomePaintingArt {
    private static var cache:[InteriorItem:UIImage] = [:]
    static func image(_ item:InteriorItem) -> UIImage {
        if let cached = cache[item] { return cached }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true; format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size:CGSize(width:600,height:420),format:format).image { renderer in
            let context = renderer.cgContext
            context.setFillColor(UIColor(red:0.025,green:0.035,blue:0.12,alpha:1).cgColor)
            context.fill(CGRect(x:0,y:0,width:600,height:420))
            if item == .nebulaPainting {
                for i in 0..<14 {
                    let color = i.isMultiple(of:2) ? UIColor.systemPurple:UIColor.cyan
                    context.setFillColor(color.withAlphaComponent(0.14).cgColor)
                    context.fillEllipse(in:CGRect(x:CGFloat(i*31-90),y:CGFloat(80+(i*43)%150),width:280,height:130))
                }
                for i in 0..<95 {
                    let x = CGFloat((i*137+23)%600), y = CGFloat((i*83+19)%420)
                    context.setFillColor((i.isMultiple(of:7) ? UIColor.systemYellow:UIColor.white).withAlphaComponent(0.8).cgColor)
                    context.fillEllipse(in:CGRect(x:x,y:y,width:i.isMultiple(of:7) ? 4:2,height:i.isMultiple(of:7) ? 4:2))
                }
            } else {
                for i in 0..<42 {
                    let t = CGFloat(i)/42
                    context.setFillColor(UIColor(red:0.24+t*0.65,green:0.13+t*0.28,blue:0.35-t*0.2,alpha:1).cgColor)
                    context.fill(CGRect(x:0,y:t*420,width:600,height:11))
                }
                context.setFillColor(UIColor(red:1,green:0.8,blue:0.4,alpha:1).cgColor)
                context.fillEllipse(in:CGRect(x:370,y:85,width:90,height:90)); context.fillEllipse(in:CGRect(x:465,y:125,width:48,height:48))
                for ridge in 0..<3 {
                    let path = UIBezierPath(); path.move(to:CGPoint(x:0,y:420))
                    for x in stride(from:0,through:600,by:30) {
                        let y = 260+ridge*45+Int(sin(Double(x)*0.014+Double(ridge))*25)
                        path.addLine(to:CGPoint(x:x,y:y))
                    }
                    path.addLine(to:CGPoint(x:600,y:420)); path.close()
                    UIColor(red:0.18+CGFloat(ridge)*0.06,green:0.1,blue:0.15,alpha:1).setFill(); path.fill()
                }
            }
        }
        cache[item] = image; return image
    }
}

@MainActor
enum HomeFurnishingScene {
    static func node(_ part:HomeFurniturePart) -> SCNNode {
        let geometry = SCNBox(width:CGFloat(part.size.x),height:CGFloat(part.size.y),length:CGFloat(part.size.z),chamferRadius:CGFloat(min(0.08,min(part.size.x,part.size.y,part.size.z)*0.1)))
        let material = SCNMaterial(); material.diffuse.contents = part.tint.color
        material.roughness.contents = 0.5; material.metalness.contents = part.tint == .gold || part.tint == .metal ? 0.6:0.1
        if part.glow { material.emission.contents = part.tint.color }
        geometry.materials = [material]
        let node = SCNNode(geometry:geometry); node.simdPosition = part.center; return node
    }
    static func furniture(_ item:InteriorItem,state:HomeItemState) -> SCNNode {
        let group = SCNNode(); group.name = "Furniture " + item.id
        for part in HomeFurnitureDesign.parts(item,state:state) { group.addChildNode(node(part)) }
        if item.layer == .wall {
            let painting = SCNNode(geometry:SCNPlane(width:3.4,height:2.4))
            painting.geometry?.firstMaterial?.diffuse.contents = HomePaintingArt.image(item)
            painting.geometry?.firstMaterial?.lightingModel = .constant
            painting.simdPosition = [0.16,2.8,0]; painting.eulerAngles.y = .pi/2; group.addChildNode(painting)
        }
        if [.floorLamp,.pendant,.lantern,.firepit].contains(item),state.enabled {
            let lamp = SCNNode(); lamp.light = SCNLight(); lamp.light?.type = .omni
            lamp.light?.color = item == .pendant ? UIColor.cyan:UIColor(red:1,green:0.72,blue:0.4,alpha:1)
            lamp.light?.intensity = 180; lamp.light?.attenuationStartDistance = 1; lamp.light?.attenuationEndDistance = 7
            lamp.simdPosition = [0,item == .pendant ? 5.5:2,0]; group.addChildNode(lamp)
        }
        return group
    }
    static func updateOriginal(_ group:SCNNode,item:InteriorItem,state:HomeItemState,reduceMotion:Bool) {
        if item == .lights || item == .jukebox {
            for node in group.childNodes {
                guard let material = node.geometry?.firstMaterial,let color = material.emission.contents as? UIColor,color != .black else { continue }
                material.emission.contents = state.enabled ? color:UIColor.black
                if !state.enabled { material.diffuse.contents = color.withAlphaComponent(1).darker }
            }
        }
        if item == .holotable {
            let colors:[UIColor] = [.cyan,.systemOrange,.systemGreen]
            for node in group.childNodes where node.position.y>1.6 { node.geometry?.firstMaterial?.emission.contents = colors[state.variant%3] }
        }
        if item == .garden,state.variant>0 {
            for x:Float in [-7,0,7] {
                let bloom = node(.init(center:[x,3.1,0],size:[0.8,0.3,0.8],tint:.violet,glow:true)); group.addChildNode(bloom)
            }
        }
    }
}
private extension UIColor {
    var darker:UIColor { var r:CGFloat = 0,g:CGFloat = 0,b:CGFloat = 0,a:CGFloat = 0; getRed(&r,green:&g,blue:&b,alpha:&a); return UIColor(red:r*0.15,green:g*0.15,blue:b*0.15,alpha:1) }
}
