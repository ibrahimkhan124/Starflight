import Foundation
import simd

enum HomeArea:String,CaseIterable,Identifiable,Sendable {
    case room,terrace
    var id:String { rawValue }
    var name:String { self == .room ? "Room":"Terrace" }
    // The furnished terrace is beside the front avenue, away from the landing pad.
    static let terraceOrigin = SIMD3<Float>(-165,8.4,155)
    static let terraceScale:Float = 3
}
enum HomeItemLayer:Equatable,Sendable { case floor,wall,ceiling }
enum HomeItemInteraction:Equatable,Sendable { case none,seat,toggle,cabinet,chart,water,inspect }
struct HomeItemState:Codable,Equatable,Sendable {
    var enabled = true
    var variant = 0
}
struct HomeFurnishingInfo {
    let name:String, price:Int, detail:String
    var area:HomeArea = .room
    var layer:HomeItemLayer = .floor
    var position:SIMD2<Float>
    var halfSize:SIMD2<Float>
    var interaction:HomeItemInteraction = .inspect
}
extension InteriorItem {
    var furnishing:HomeFurnishingInfo {
        switch self {
        case .lounge:return .init(name:"Cloud lounge suite",price:90,detail:"A curved sofa, low table and matching armchairs. Sit down to enjoy the view.",position:[-3,2.5],halfSize:[3.7,3.6],interaction:.seat)
        case .holotable:return .init(name:"Galactic holo table",price:180,detail:"An illuminated star chart. Switch between three planetary displays.",position:[4,0],halfSize:[2,1.5],interaction:.chart)
        case .garden:return .init(name:"Indoor moon garden",price:75,detail:"Three sculptural planters. Water them to bring out their luminous blossoms.",position:[0,-5.5],halfSize:[8,1],interaction:.water)
        case .aquarium:return .init(name:"Luminous aquarium",price:240,detail:"A blue-lit tank with swimming fish. Inspect the miniature aquatic habitat.",position:[7,-3],halfSize:[1.5,0.9])
        case .art:return .init(name:"Sculpture collection",price:120,detail:"Three metallic abstract sculptures on pedestals.",position:[-4,-3],halfSize:[2.5,0.7])
        case .jukebox:return .init(name:"Cantina sound console",price:160,detail:"Switch on an original, gentle electronic lounge loop. Respects the game's sound settings.",position:[7,5],halfSize:[1,0.7],interaction:.toggle)
        case .trophy:return .init(name:"Bounty trophy display",price:300,detail:"A cabinet of miniature starfighters, commemorating your travels.",position:[-8.1,2],halfSize:[0.75,0.95])
        case .lights:return .init(name:"Neon ceiling canopy",price:60,detail:"Switch the violet and cyan ceiling strips on or off.",layer:.ceiling,position:[0,0],halfSize:[8.2,7.6],interaction:.toggle)
        case .readingChair:return .init(name:"Starlight reading chair",price:110,detail:"A padded wing chair with a footrest. Take a seat and look around.",position:[-12,-9],halfSize:[1.4,1.8],interaction:.seat)
        case .dining:return .init(name:"Orbital dining set",price:220,detail:"A stone-topped dining table and four upholstered chairs. Sit at the table.",position:[11,8],halfSize:[3.1,3.1],interaction:.seat)
        case .cabinet:return .init(name:"Sliding display cabinet",price:140,detail:"Open the sliding doors to reveal shelves of colourful keepsakes.",position:[-12,9],halfSize:[2.8,1.05],interaction:.cabinet)
        case .nebulaPainting:return .init(name:"Nebula drift · framed painting",price:85,detail:"An original abstract nebula study in violet, cyan and gold. Hangs on the gallery wall.",layer:.wall,position:[-19.75,-9],halfSize:[0.2,1.9])
        case .sunsetPainting:return .init(name:"Twin sunset · framed painting",price:85,detail:"An original desert skyline beneath two warm suns. Hangs on the gallery wall.",layer:.wall,position:[-19.75,0],halfSize:[0.2,1.9])
        case .floorLamp:return .init(name:"Crescent floor lamp",price:65,detail:"A brass-stemmed reading lamp with a warm illuminated shade.",position:[-15,-9],halfSize:[0.65,0.65],interaction:.toggle)
        case .pendant:return .init(name:"Prism pendant fixture",price:120,detail:"A suspended three-light fixture. Position it above your furniture without taking floor space.",layer:.ceiling,position:[11,8],halfSize:[2,1],interaction:.toggle)
        case .desk:return .init(name:"Navigator's desk",price:160,detail:"A curved console and three navigation screens. Cycle their planetary charts.",position:[11,-9],halfSize:[2.6,1.3],interaction:.chart)
        case .patioLounge:return .init(name:"Skyline outdoor sofa",price:150,detail:"Weatherproof seating and a low deck table. Sit beneath the skyline.",area:.terrace,position:[-9,-5],halfSize:[3.3,2.2],interaction:.seat)
        case .bistro:return .init(name:"Terrace bistro set",price:180,detail:"A tiled café table and two matching chairs, ready for a skyline break.",area:.terrace,position:[8,5],halfSize:[2.7,2.8],interaction:.seat)
        case .planter:return .init(name:"Moonflower garden bed",price:95,detail:"A raised planter with flowering alien shrubs. Water it to brighten the blossoms.",area:.terrace,position:[-10,8],halfSize:[3.2,1.4],interaction:.water)
        case .fountain:return .init(name:"Cascade courtyard fountain",price:220,detail:"A tiered stone fountain with luminous water jets. Switch the flow on or off.",area:.terrace,position:[8,-7],halfSize:[2.4,2.4],interaction:.toggle)
        case .lantern:return .init(name:"Aurora lantern trio",price:90,detail:"Three sculpted light posts with warm glowing cores. Switch their light on or off.",area:.terrace,position:[0,-10],halfSize:[3.5,0.7],interaction:.toggle)
        case .firepit:return .init(name:"Ember conversation pit",price:240,detail:"A stone hearth with a contained amber flame. Switch it on or off.",area:.terrace,position:[0,3],halfSize:[2,2],interaction:.toggle)
        }
    }
    var area:HomeArea { furnishing.area }
    var layer:HomeItemLayer { furnishing.layer }
    var interaction:HomeItemInteraction { furnishing.interaction }
    var blocksWalking:Bool { layer == .floor }
    var canRotate:Bool { movable && layer != .wall }
    var initialState:HomeItemState { HomeItemState(enabled:self != .jukebox && self != .cabinet) }
    func actionLabel(_ state:HomeItemState) -> String {
        switch interaction {
        case .seat:return "Sit down"
        case .toggle:return state.enabled ? (self == .jukebox ? "Stop music":"Switch off"):(self == .jukebox ? "Play music":"Switch on")
        case .cabinet:return state.enabled ? "Close cabinet":"Open cabinet"
        case .chart:return "Next planetary chart"
        case .water:return state.variant == 0 ? "Water plants":"Refresh blossoms"
        default:return "Inspect"
        }
    }
    func placing(_ point:RoomPlacement,snap:Bool) -> RoomPlacement {
        var p = snap ? point.snapped:point
        if layer == .wall { p.x = -19.75; p.turns = 0 }
        return p
    }
    func transformed(_ local:SIMD2<Float>,at p:RoomPlacement) -> SIMD2<Float> {
        switch p.turns%4 { case 1:return p.point+[local.y,-local.x]; case 2:return p.point-local; case 3:return p.point+[-local.y,local.x]; default:return p.point+local }
    }
    var seatOffset:SIMD2<Float> { self == .lounge ? [0,-2.5]:self == .dining ? [0,2.2]:self == .bistro ? [0,2]:[0,-0.4] }
    var seatHeight:Float { self == .lounge ? 2.6:1.5 }
    var seatYaw:Float { self == .dining || self == .bistro ? 0:.pi }
}

enum HomeInteraction {
    static func distance(to item:InteriorItem,from position:SIMD2<Float>,layout:[InteriorItem:RoomPlacement]) -> Float {
        if item == .lights { return simd_distance(position,[4,12]) }
        let p = HomeRoomLayout.placement(item,in:layout)
        let offset = position-p.point
        let delta = SIMD2<Float>(abs(offset.x),abs(offset.y))-p.halfSize(for:item)
        return simd_length(simd_max(delta,.zero))
    }
    static func nearest(from position:SIMD2<Float>,area:HomeArea,items:Set<InteriorItem>,layout:[InteriorItem:RoomPlacement]) -> InteriorItem? {
        InteriorItem.allCases.filter { items.contains($0) && $0.area == area && $0.interaction != .none && distance(to:$0,from:position,layout:layout)<=2.6 }
            .min { distance(to:$0,from:position,layout:layout)+($0.layer == .ceiling ? 2:0)<distance(to:$1,from:position,layout:layout)+($1.layer == .ceiling ? 2:0) }
    }
}

enum HomeFurnitureTint:Int,CaseIterable,Sendable { case stone,ivory,metal,gold,teal,violet,green,amber,water,glass,white }
struct HomeFurniturePart:Sendable {
    var center:SIMD3<Float>, size:SIMD3<Float>
    var tint:HomeFurnitureTint
    var glow = false
    func placed(at p:RoomPlacement,origin:SIMD3<Float> = .zero,scale:Float = 1) -> HomeFurniturePart {
        let angle = Float(p.turns)*Float.pi/2
        let x = center.x*cos(angle)+center.z*sin(angle), z = -center.x*sin(angle)+center.z*cos(angle)
        let dimensions = p.turns.isMultiple(of:2) ? size:SIMD3<Float>(size.z,size.y,size.x)
        return HomeFurniturePart(center:origin+SIMD3<Float>(x+p.x,center.y,z+p.z)*scale,size:dimensions*scale,tint:tint,glow:glow)
    }
}
enum HomeFurnitureDesign {
    static func parts(_ item:InteriorItem,state:HomeItemState) -> [HomeFurniturePart] {
        var p:[HomeFurniturePart] = []
        func box(_ c:SIMD3<Float>,_ s:SIMD3<Float>,_ t:HomeFurnitureTint,_ glow:Bool = false) { p.append(.init(center:c,size:s,tint:t,glow:glow)) }
        func chair(_ x:Float,_ z:Float,turns:Int = 0) {
            let start = p.count
            box([x,0.6,z],[1.5,0.3,1.5],.ivory); box([x,1.1,z-0.65],[1.5,1,0.2],.teal)
            for dx:Float in [-0.5,0.5] { for dz:Float in [-0.5,0.5] { box([x+dx,0.25,z+dz],[0.12,0.5,0.12],.gold) } }
            if turns != 0 {
                for i in start..<p.count {
                    var local = p[i]; local.center -= [x,0,z]
                    p[i] = local.placed(at:RoomPlacement(x:x,z:z,turns:turns))
                }
            }
        }
        switch item {
        case .readingChair:
            chair(0,0); box([0,0.45,1.3],[1.2,0.8,0.7],.teal)
            for x:Float in [-0.8,0.8] { box([x,0.85,0],[0.18,0.55,1.5],.ivory) }
        case .dining,.bistro:
            let outdoor = item == .bistro
            box([0,1.05,0],[outdoor ? 2.5:3.4,0.18,2],.stone)
            box([0,0.5,0],[0.5,1,0.5],.gold)
            chair(0,2,turns:2)
            if !outdoor { chair(-2,0,turns:1); chair(2,0,turns:3) }
            chair(0,-2)
            box([0,1.35,0],[0.4,0.45,0.4],.gold); box([0,1.7,0],[0.8,0.5,0.7],.green)
        case .cabinet:
            box([0,1.6,-0.65],[3.2,3.2,0.12],.metal)
            for x:Float in [-1.5,1.5] { box([x,1.6,0],[0.2,3.2,1.4],.metal) }
            for y:Float in [0.25,1.15,2.1,3.1] { box([0,y,0.15],[2.9,0.1,1.1],.gold) }
            for i in 0..<9 { box([Float(i%3-1)*0.8,0.6+Float(i/3)*0.9,0.3],[0.35,0.5,0.4],i.isMultiple(of:2) ? .teal:.amber) }
            for sign:Float in [-1,1] {
                let x = sign*(state.enabled ? 2:0.75)
                box([x,1.65,0.82],[1.4,2.9,0.12],.ivory); box([x-sign*0.45,1.65,0.92],[0.08,0.5,0.08],.gold)
            }
        case .nebulaPainting,.sunsetPainting:
            box([0,2.8,0],[0.2,2.7,3.7],.gold); box([0.12,2.8,0],[0.05,2.4,3.4],.metal)
        case .floorLamp:
            box([0,0.1,0],[1.1,0.2,1.1],.metal); box([0,1.4,0],[0.12,2.6,0.12],.gold)
            box([0,2.7,0],[1.2,0.7,1.2],state.enabled ? .ivory:.stone,state.enabled)
        case .pendant:
            box([0,7.7,0],[4,0.12,0.6],.gold)
            for x:Float in [-1.4,0,1.4] {
                box([x,6.8,0],[0.04,1.8,0.04],.metal)
                box([x,5.9,0],[0.7,0.7,0.7],state.enabled ? .teal:.glass,state.enabled)
            }
        case .desk:
            box([0,0.7,0],[4.7,0.2,2.1],.stone)
            for x:Float in [-2,2] { box([x,0.35,0],[0.2,0.7,1.7],.gold) }
            for x:Float in [-1.5,0,1.5] {
                box([x,1.4,-0.75],[1.3,1.1,0.18],.metal)
                box([x,1.4,-0.63],[1.1,0.8,0.04],[HomeFurnitureTint.teal,.water,.violet][state.variant%3],true)
                for y:Float in [1.2,1.4,1.6] { box([x,y,-0.59],[0.8,0.025,0.02],.white,true) }
            }
        case .patioLounge:
            box([0,0.45,-0.5],[5.5,0.6,1.7],.metal); box([0,0.8,-0.5],[5.1,0.3,1.5],.ivory)
            box([0,1.3,-1.2],[5.5,1.1,0.25],.teal)
            for x:Float in [-2.8,2.8] { box([x,0.85,-0.5],[0.25,0.8,1.7],.gold) }
            box([0,0.6,1.1],[3.5,0.2,1.2],.stone)
        case .planter:
            box([0,0.4,0],[6,0.8,2.2],.stone); box([0,0.85,0],[5.7,0.1,1.9],.metal)
            for x:Float in [-2,0,2] {
                box([x,1.3,0],[0.15,1,0.15],.gold)
                box([x,1.65,0],[1.4,1.1,1.2],.green)
                if state.variant>0 { box([x,2.3,0],[0.7,0.35,0.7],.violet,true) }
            }
        case .fountain:
            box([0,0.25,0],[4.5,0.5,4.5],.stone); box([0,0.55,0],[3.9,0.08,3.9],.water,true)
            box([0,1.1,0],[0.7,1.6,0.7],.gold); box([0,1.8,0],[2.3,0.3,2.3],.stone)
            if state.enabled {
                for x:Float in [-0.8,0.8] { for z:Float in [-0.8,0.8] { box([x,1.15,z],[0.08,1.4,0.08],.water,true) } }
                box([0,2.25,0],[0.1,0.7,0.1],.water,true)
            }
        case .lantern:
            for x:Float in [-2.8,0,2.8] {
                box([x,0.1,0],[0.8,0.2,0.8],.metal); box([x,1.2,0],[0.12,2.2,0.12],.gold)
                box([x,2.3,0],[0.65,0.9,0.65],state.enabled ? .amber:.glass,state.enabled)
                box([x,2.8,0],[0.9,0.12,0.9],.metal)
            }
        case .firepit:
            box([0,0.35,0],[3.6,0.7,3.6],.stone); box([0,0.75,0],[2.7,0.15,2.7],.metal)
            if state.enabled {
                for i in 0..<5 { box([Float(i%3-1)*0.6,1+Float(i%2)*0.25,Float(i/3)*0.7-0.35],[0.35,0.6+Float(i%2)*0.4,0.35],i.isMultiple(of:2) ? .amber:.gold,true) }
            }
        default:break
        }
        return p
    }
    static var terraceShell:[HomeFurniturePart] {
        var p:[HomeFurniturePart] = [.init(center:[0,-0.1,0],size:[40,0.2,32],tint:.stone)]
        for x:Float in [-19.8,19.8] { p.append(.init(center:[x,1,0],size:[0.15,0.12,32],tint:.gold)) }
        for z:Float in [-15.8,15.8] {
            p.append(.init(center:[-8.8,1,z],size:[22.4,0.12,0.15],tint:.gold))
            p.append(.init(center:[12.8,1,z],size:[14.4,0.12,0.15],tint:.gold))
        }
        for x:Float in stride(from:-19.8,through:19.8,by:6.6) { for z:Float in [-15.8,15.8] { p.append(.init(center:[x,0.5,z],size:[0.15,1,0.15],tint:.metal)) } }
        return p
    }
    static func terraceParts(items:Set<InteriorItem>,layout:[InteriorItem:RoomPlacement],states:[InteriorItem:HomeItemState]) -> [HomeFurniturePart] {
        terraceShell+InteriorItem.allCases.filter { items.contains($0) && $0.area == .terrace }.flatMap { item in
            parts(item,state:states[item] ?? item.initialState).map { $0.placed(at:HomeRoomLayout.placement(item,in:layout)) }
        }
    }
}
