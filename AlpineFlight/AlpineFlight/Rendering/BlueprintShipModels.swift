import RealityKit
import UIKit

/// New fleet models are lightweight original procedural fan interpretations.
@MainActor
enum BlueprintShipModels {
    static func make(type:AircraftType,color:UIColor) -> Entity {
        let root = Entity(); root.name = type.name
        let hull = SimpleMaterial(color:color,roughness:0.4,isMetallic:true)
        let dark = SimpleMaterial(color:.darkGray,roughness:0.7,isMetallic:true)
        let glow = UnlitMaterial(color:.cyan)
        func box(_ name:String,_ size:SIMD3<Float>,_ p:SIMD3<Float>,_ material:any RealityKit.Material) {
            let part = ModelEntity(mesh:.generateBox(size:size,cornerRadius:0.1),materials:[material])
            part.name = name; part.position = p; root.addChild(part)
        }
        if type == .bWing {
            box("long weapon spar",[16,0.6,3],[0,0,0],hull)
            box("armoured engine hull",[2.5,2,12],[1,0,0],hull)
            box("cockpit",[2,1.2,3],[-6,0,-4],dark)
            for x:Float in [-8,8] { box("heavy cannon",[0.4,0.4,8],[x,0,-3],dark) }
            box("cross foil",[5,0.4,5],[0,0,2],hull)
            box("engine glow",[2,0.8,0.2],[1,0,6.1],glow)
        } else if type == .imperialShuttle {
            box("shuttle hull",[6,4,18],[0,0,0],hull)
            box("command cockpit",[4,2,5],[0,0,-9.5],dark)
            box("dorsal fin",[0.6,10,10],[0,6,2],hull)
            for side:Float in [-1,1] {
                box("deployed wing",[9.5,0.7,10],[side*7.7,-1.8,2],hull)
                box("wing cannon",[0.5,0.5,5],[side*9,-1.8,-4],dark)
                box("engine glow",[2,1,0.2],[side*1.7,0,9.1],glow)
            }
        } else {
            let cockpit = ModelEntity(mesh:.generateSphere(radius:1.6),materials:[hull]); root.addChild(cockpit)
            box("viewport",[1.8,1.3,0.3],[0,0,-1.6],dark)
            for index in 0..<3 {
                let arm = Entity(); arm.orientation = simd_quatf(angle:Float(index)*2 * .pi/3,axis:[0,0,1])
                let strut = ModelEntity(mesh:.generateBox(size:[5,0.35,1]),materials:[hull]); strut.position=[2.5,0,0];arm.addChild(strut)
                for side:Float in [-1,1] {
                    let panel = ModelEntity(mesh:.generateBox(size:[0.3,3.2,8]),materials:[dark]);panel.position=[5,side*1.6,0];arm.addChild(panel)
                    let rim = ModelEntity(mesh:.generateBox(size:[0.5,0.2,8.5]),materials:[hull]);rim.position=[5,side*3.2,0];arm.addChild(rim)
                }
                root.addChild(arm)
            }
            box("ion engine",[1.6,1,0.2],[0,0,1.7],glow)
        }
        // Fit the artwork inside the gameplay envelope, with local forward along -Z.
        let bounds = root.visualBounds(relativeTo:root)
        let widthScale = type.wingspan/max(bounds.extents.x,0.01)
        let lengthScale = type.length/max(bounds.extents.z,0.01)
        let scale = SIMD3<Float>(widthScale,min(widthScale,lengthScale),lengthScale)
        let container = Entity(); container.name=type.name
        root.scale=scale; root.position = -bounds.center*scale; container.addChild(root)
        let front = Entity();front.name="FlightForward";front.position=[0,0,-type.length/2];container.addChild(front)
        let rear = Entity();rear.name="FlightRear";rear.position=[0,0,type.length/2];container.addChild(rear)
        return container
    }
}
