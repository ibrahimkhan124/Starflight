import SwiftUI
import SceneKit

struct CityHomePreview: View {
    let plot:CityPlot
    let interior:Bool
    let items:Set<InteriorItem>
    var layout:[InteriorItem:RoomPlacement] = [:]
    var states:[InteriorItem:HomeItemState] = [:]
    var area:HomeArea = .room
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var preview:ResidencePreviewScene?
    @State private var viewingRoom = ""
    private var key:String { plot.id+area.id+String(interior)+String(reduceMotion)+items.map(\.id).sorted().joined()+String(describing:layout.sorted { $0.key.id<$1.key.id })+String(describing:states.sorted { $0.key.id<$1.key.id }) }
    var body:some View {
        ZStack {
            if let preview {
                SceneView(scene:preview.scene,pointOfView:preview.camera,options:[.allowsCameraControl],
                          preferredFramesPerSecond:30,antialiasingMode:.multisampling2X)
            } else { ProgressView() }
        }.background(.black).clipShape(RoundedRectangle(cornerRadius:16))
            .accessibilityElement(children:.ignore)
            .accessibilityLabel(interior ? "Furnished home interior. Drag to look around; pinch to zoom." : plot.name+" exterior. Drag to rotate; pinch to zoom.")
            .accessibilityIdentifier("Residence 3D preview")
            .task(id:key) {
                let roomKey = plot.id+String(interior)+area.id
                let updated = ResidencePreviewScene(plot:plot,interior:interior,items:items,reduceMotion:reduceMotion,layout:layout,states:states,area:area)
                if viewingRoom == roomKey,let preview { updated.camera.simdTransform = preview.camera.simdTransform }
                preview = updated; viewingRoom = roomKey
            }
    }
}

@MainActor
final class ResidencePreviewScene {
    let scene = SCNScene(), camera = SCNNode()
    init(plot:CityPlot,interior:Bool,items:Set<InteriorItem>,reduceMotion:Bool,layout:[InteriorItem:RoomPlacement] = [:],walkthrough:Bool = false,states:[InteriorItem:HomeItemState] = [:],area:HomeArea = .room) {
        scene.background.contents = UIColor(red:0.018,green:0.025,blue:0.05,alpha:1)
        if interior,area == .terrace { makeTerrace(plot:plot,items:items,layout:layout,states:states,walkthrough:walkthrough) }
        else if interior { makeRoom(plot:plot,items:items,reduceMotion:reduceMotion,layout:layout,walkthrough:walkthrough,states:states) }
        else {
            for part in plot.parts { box(part.center,part.size,CityResidenceRenderer.color(part.material,plot:plot),glow:part.material == 3 || part.material == 5) }
            for part in HomeFurnitureDesign.terraceParts(items:items,layout:layout,states:states) {
                let transformed = part.placed(at:RoomPlacement(x:0,z:0),origin:HomeArea.terraceOrigin,scale:HomeArea.terraceScale)
                scene.rootNode.addChildNode(HomeFurnishingScene.node(transformed))
            }
        }
        camera.camera = SCNCamera(); camera.camera?.fieldOfView = 50
        camera.camera?.zNear = 0.05; camera.camera?.zFar = 4000
        camera.position = interior ? SCNVector3(HomeRoomGeometry.width*0.72,HomeRoomGeometry.height*2.8,HomeRoomGeometry.depth*1.15) : SCNVector3(550,400,750)
        camera.look(at:interior ? SCNVector3(0,2,0) : SCNVector3(0,70,30)); scene.rootNode.addChildNode(camera)
        let key = SCNNode(); key.light = SCNLight(); key.light?.type = .omni
        key.light?.intensity = 1200; key.position = interior ? SCNVector3(0,HomeRoomGeometry.height+4,HomeRoomGeometry.depth/4) : SCNVector3(100,500,600)
        scene.rootNode.addChildNode(key)
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient
        ambient.light?.intensity = 300; ambient.light?.color = UIColor(red:0.6,green:0.7,blue:1,alpha:1)
        scene.rootNode.addChildNode(ambient)
    }
    @discardableResult
    private func box(_ center:SIMD3<Float>,_ size:SIMD3<Float>,_ color:UIColor,glow:Bool = false) -> SCNNode {
        let geometry = SCNBox(width:CGFloat(size.x),height:CGFloat(size.y),length:CGFloat(size.z),chamferRadius:CGFloat(min(0.12,min(size.x,size.y,size.z)*0.1)))
        let material = SCNMaterial(); material.diffuse.contents = color
        material.metalness.contents = 0.35; material.roughness.contents = 0.5
        if glow { material.emission.contents = color }
        geometry.materials = [material]; let node = SCNNode(geometry:geometry); node.simdPosition = center
        scene.rootNode.addChildNode(node); return node
    }
    private func makeRoom(plot:CityPlot,items:Set<InteriorItem>,reduceMotion:Bool,layout:[InteriorItem:RoomPlacement],walkthrough:Bool,states:[InteriorItem:HomeItemState]) {
        let cream = UIColor(red:0.65,green:0.65,blue:0.61,alpha:1)
        let width = HomeRoomGeometry.width, depth = HomeRoomGeometry.depth, height = HomeRoomGeometry.height
        let edge = HomeRoomGeometry.halfSize
        box([0,-0.2,0],[width,0.4,depth],.init(white:0.1,alpha:1)).name = "Room floor"
        let wall = CityResidenceRenderer.color(1,plot:plot)
        box([0,0.6,-edge.y],[width,1.2,0.4],wall)
        box([0,height-0.2,-edge.y],[width,0.4,0.4],wall)
        for x:Float in [-edge.x+0.2,edge.x-0.2] { box([x,height/2,-edge.y],[0.4,height,0.4],wall) }
        let window = box([0,height/2+0.5,-edge.y],[width-0.8,height-1.4,0.06],.init(red:0.1,green:0.3,blue:0.5,alpha:1))
        window.name = "Panoramic window"
        window.opacity = 0.16
        box([-edge.x,height/2,0],[0.3,height,depth],.darkGray)
        // Low gallery walls keep the larger room readable in the cutaway shop preview.
        box([edge.x,0.6,0],[0.3,1.2,depth],wall)
        box([edge.x-0.15,1.25,0],[0.08,0.08,depth],.cyan,glow:true)
        let doorX = HomeRoomGeometry.entrance.x, doorHalfWidth = HomeRoomGeometry.entranceHalfSize.x
        let leftDoor = doorX-doorHalfWidth, rightDoor = doorX+doorHalfWidth
        box([(-edge.x+leftDoor)/2,0.6,edge.y],[leftDoor+edge.x,1.2,0.3],wall)
        box([(rightDoor+edge.x)/2,0.6,edge.y],[edge.x-rightDoor,1.2,0.3],wall)
        for x in [leftDoor,rightDoor] { box([x,1.8,edge.y],[0.12,3.6,0.12],.cyan,glow:true) }
        box([doorX,3.6,edge.y],[doorHalfWidth*2,0.12,0.12],.cyan,glow:true).name = "Room entrance"
        if walkthrough {
            // Close the shell for walking; the shop keeps a cutaway so furniture remains visible.
            box([0,height+0.1,0],[width,0.3,depth],.init(white:0.16,alpha:1)).name = "Room ceiling"
            for z:Float in [-10,0,10] { box([0,height-0.1,z],[width,0.25,0.2],wall) }
            box([(-edge.x+leftDoor)/2,height/2,edge.y],[leftDoor+edge.x,height,0.3],wall)
            box([(rightDoor+edge.x)/2,height/2,edge.y],[edge.x-rightDoor,height,0.3],wall)
            box([doorX,(height+3.6)/2,edge.y],[doorHalfWidth*2,height-3.6,0.3],wall)
            box([doorX,1.75,edge.y],[doorHalfWidth*2-0.2,3.5,0.2],.init(white:0.13,alpha:1))
            box([doorX,1.75,edge.y-0.12],[0.04,3.3,0.03],.cyan,glow:true)
            box([edge.x,height-0.2,0],[0.3,0.4,depth],wall)
            let sideWindow = box([edge.x,height/2+0.5,0],[0.06,height-1.4,depth-0.8],.init(red:0.1,green:0.3,blue:0.5,alpha:1))
            sideWindow.opacity = 0.16
            for z:Float in [-edge.y+0.2,edge.y-0.2] { box([edge.x,height/2,z],[0.4,height,0.4],wall) }
            for x:Float in [-10,10] {
                for z:Float in [-8,8] { box([x,height-0.1,z],[3,0.06,1.5],.init(white:0.65,alpha:1),glow:true) }
            }
        }
        for x:Float in stride(from:-edge.x+2,through:edge.x-2,by:3) {
            box([x,height/2,-edge.y+0.3],[0.08,height-1,0.08],.cyan,glow:true)
            box([x,0.1,0],[0.03,0.03,depth],.init(white:0.3,alpha:1))
        }
        // A miniature neon skyline beyond the panoramic window.
        for i in 0..<24 {
            let x = (Float(i%12)/11-0.5)*(width+4), z = -edge.y-6-Float(i/12)*5
            let h = 3+Float((i*7)%9)
            box([x,h/2,z],[1.2,h,1.3],.init(white:0.08,alpha:1))
            box([x,h*0.6,z+0.7],[1.1,0.12,0.03],i.isMultiple(of:3) ? .systemPurple:.cyan,glow:true)
        }
        box([0,0.03,0],[width*0.55,0.06,depth*0.5],.init(red:0.13,green:0.17,blue:0.24,alpha:1))
        func place(_ item:InteriorItem,build:()->Void) {
            guard items.contains(item) else { return }
            let start = scene.rootNode.childNodes.count
            build()
            let nodes = Array(scene.rootNode.childNodes.dropFirst(start))
            let group = SCNNode(); group.name = "Furniture " + item.id
            let anchor = item.defaultPlacement.point
            for node in nodes {
                node.removeFromParentNode(); node.simdPosition -= [anchor.x,0,anchor.y]; group.addChildNode(node)
            }
            let position = HomeRoomLayout.placement(item,in:layout)
            group.simdPosition = [position.x,0,position.z]; group.eulerAngles.y = Float(position.turns) * .pi/2
            HomeFurnishingScene.updateOriginal(group,item:item,state:states[item] ?? item.initialState,reduceMotion:reduceMotion)
            scene.rootNode.addChildNode(group)
        }
        place(.lounge) {
            box([-3,0.8,0],[6,1.6,2],cream); box([-3,1.7,-0.8],[6,0.8,0.4],cream)
            for x:Float in [-6,0] { box([x,1.2,0],[0.4,1.2,2],cream) }
            box([-3,0.7,3],[4,0.25,2],.darkGray)
            for x:Float in [-6,0] { box([x,0.8,5],[1.6,1.6,1.6],cream) }
        }
        place(.holotable) {
            box([4,0.8,0],[4,1.6,3],.darkGray); box([4,1.7,0],[3.6,0.1,2.6],.cyan,glow:true)
            let orbit = SCNNode(geometry:SCNTorus(ringRadius:1.15,pipeRadius:0.025))
            orbit.geometry?.firstMaterial?.emission.contents = UIColor.cyan
            orbit.position = SCNVector3(4,2.2,0); scene.rootNode.addChildNode(orbit)
            for i in 0..<5 {
                let sphere = SCNNode(geometry:SCNSphere(radius:0.18+Double(i%2)*0.12))
                sphere.geometry?.firstMaterial?.emission.contents = UIColor.cyan
                sphere.position = SCNVector3(3+Float(i)*0.5,2.4+Float(i%2)*0.3,0)
                scene.rootNode.addChildNode(sphere)
            }
        }
        place(.garden) {
            for x:Float in [-7,0,7] { box([x,0.5,-5.5],[1.2,1,1.2],.lightGray); box([x,1.5,-5.5],[0.2,2,0.2],.brown); box([x,2.4,-5.5],[2,1.2,1.6],.systemGreen) }
        }
        place(.aquarium) {
            box([7,1.2,-3],[3,2.4,1.5],.init(red:0.02,green:0.2,blue:0.4,alpha:1),glow:true)
            for i in 0..<5 {
                let fish = box([6+Float(i)*0.4,0.7+Float(i%3)*0.5,-2.1],[0.3,0.12,0.15],.systemOrange,glow:true)
                if !reduceMotion { fish.runAction(.repeatForever(.sequence([.moveBy(x:0.4,y:0,z:0,duration:2),.moveBy(x:-0.4,y:0,z:0,duration:2)]))) }
            }
        }
        place(.art) {
            for i in 0..<3 { let x = -6+Float(i)*2; box([x,0.7,-3],[1,1.4,1],.darkGray); let art = box([x,2,-3],[0.7,1.2,0.7],.systemYellow); art.eulerAngles = SCNVector3(0.4,0.7,0.4) }
        }
        place(.jukebox) {
            box([7,1.2,5],[2,2.4,1],.darkGray)
            for y:Float in [0.6,1.2,1.8] { box([7,y,5.6],[1.6,0.12,0.05],.systemPink,glow:true) }
        }
        place(.trophy) {
            box([-8.1,1.3,2],[1.5,2.6,1.5],.darkGray)
            for y:Float in [0.8,1.6,2.4] { box([-8.1,y,2.8],[1.2,0.05,0.7],.cyan,glow:true); box([-8.1,y+0.15,2.8],[0.6,0.13,0.3],.systemYellow) }
        }
        place(.lights) {
            for x:Float in [-edge.x+2,edge.x-2] { box([x,height-0.2,0],[0.15,0.15,depth-1],.systemPurple,glow:true) }
            box([0,height-0.2,-edge.y+2],[width-4,0.15,0.15],.cyan,glow:true)
        }
        for item in InteriorItem.allCases where item.index>=8 && item.area == .room && items.contains(item) {
            addFurniture(item,layout:layout,states:states)
        }
    }
    private func addFurniture(_ item:InteriorItem,layout:[InteriorItem:RoomPlacement],states:[InteriorItem:HomeItemState]) {
        let node = HomeFurnishingScene.furniture(item,state:states[item] ?? item.initialState)
        let p = HomeRoomLayout.placement(item,in:layout); node.simdPosition = [p.x,0,p.z]; node.eulerAngles.y = Float(p.turns)*Float.pi/2
        scene.rootNode.addChildNode(node)
    }
    private func makeTerrace(plot:CityPlot,items:Set<InteriorItem>,layout:[InteriorItem:RoomPlacement],states:[InteriorItem:HomeItemState],walkthrough:Bool) {
        for part in HomeFurnitureDesign.terraceShell { scene.rootNode.addChildNode(HomeFurnishingScene.node(part)) }
        for item in InteriorItem.allCases where item.area == .terrace && items.contains(item) { addFurniture(item,layout:layout,states:states) }
        if walkthrough {
            for part in plot.parts {
                box((part.center-HomeArea.terraceOrigin)/HomeArea.terraceScale,part.size/HomeArea.terraceScale,CityResidenceRenderer.color(part.material,plot:plot),glow:part.material == 3 || part.material == 5)
            }
        }
        for i in 0..<32 {
            let angle = Float(i)*2*Float.pi/32, radius:Float = i.isMultiple(of:2) ? 90:110
            let x = cos(angle)*radius, z = sin(angle)*radius, height = Float(12+(i*13)%40)
            box([x,height/2-5,z],[5,height,5],.init(white:0.06,alpha:1))
            for y in stride(from:Float(3),through:height-5,by:5) {
                let onX = abs(x)>abs(z)
                let center:SIMD3<Float> = onX ? [x-(x>0 ? 2.6:-2.6),y,z]:[x,y,z-(z>0 ? 2.6:-2.6)]
                box(center,onX ? [0.04,0.18,4]:[4,0.18,0.04],i.isMultiple(of:3) ? .systemPurple:.cyan,glow:true)
            }
        }
    }
}
