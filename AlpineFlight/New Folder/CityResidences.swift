import Foundation
import simd

enum CityPlot: String, CaseIterable, Codable, Identifiable, Sendable {
    case aurora, obsidian, cloud, senate
    var id: String { rawValue }
    var index: Int { Self.allCases.firstIndex(of:self)! }
    var name: String { ["Aurora Garden Villa","Obsidian Neon Loft","Cloudspire Residence","Senate Sky Palace"][index] }
    var price: Int { [900,1800,3600,6500][index] }
    var position: SIMD3<Float> { [[-6720,0,5760],[6720,0,5760],[-6720,0,-5760],[6720,0,-5760]][index] }
    static let clearing: Float = 750
    var arrival: SIMD3<Float> { position + [0,260,590] }
    var description: String {
        ["A tiered ivory villa with a reflecting pool, garden courts and cyan balconies.",
         "A dramatic black-glass home with violet light fins, an elevated lounge and twin wings.",
         "A sculpted silver tower with floating terraces, a rooftop garden and blue light ribbons.",
         "A grand gold-trimmed palace with a ceremonial avenue, twin towers and an illuminated courtyard."][index]
    }
    /// Remove complete nearby towers and tunnel sections rather than leaving invisible walls.
    static func clears(center: SIMD3<Float>, size: SIMD3<Float>) -> Bool {
        allCases.contains { abs(center.x-$0.position.x) < clearing+size.x/2 && abs(center.z-$0.position.z) < clearing+size.z/2 }
    }
    private static let cachedParts = Dictionary(uniqueKeysWithValues:allCases.map { ($0,$0.makeParts()) })
    var parts:[ResidencePart] { Self.cachedParts[self] ?? [] }
    private func makeParts() -> [ResidencePart] {
        var parts: [ResidencePart] = []
        func box(_ center: SIMD3<Float>, _ size: SIMD3<Float>, _ material: Int, solid: Bool = true) {
            parts.append(ResidencePart(center:center,size:size,material:material,solid:solid))
        }
        // Shared ceremonial plinth, wide front landing terrace and inset garden courts.
        box([0,4,0],[520,8,460],0)
        box([0,10,225],[180,12,180],0)
        box([0,17,225],[150,1,150],3,solid:false)
        for x: Float in [-240,240] {
            box([x,9,0],[6,10,440],2)
            for z: Float in stride(from:-180,through:180,by:60) {
                box([x,18,z],[10,12,10],4,solid:false)
            }
        }
        switch self {
        case .aurora:
            box([0,43,-65],[260,70,160],1)
            box([0,87,-90],[175,18,110],0)
            box([-155,29,20],[100,42,130],1); box([155,29,20],[100,42,130],1)
            box([0,10,100],[100,2,65],5,solid:false)
        case .obsidian:
            box([0,73,-80],[170,130,150],1)
            for x:Float in [-145,145] { box([x,35,-25],[100,54,220],1); box([x,75,-40],[115,8,205],0) }
            box([0,147,-80],[205,18,180],0)
        case .cloud:
            for level in 0..<4 {
                let y = Float(level)*45+30, width = Float(200-level*25)
                box([Float(level%2)*20,y,-80],[width,44,150],1)
                box([0,y+23,-80],[width+50,4,185],0)
            }
        case .senate:
            box([0,60,-95],[300,104,180],1)
            for x:Float in [-180,180] { box([x,95,-110],[65,174,100],1); box([x,187,-110],[82,10,115],2) }
            box([0,118,-95],[340,12,205],0)
            box([0,10,100],[180,2,65],5,solid:false)
            for x:Float in [-110,-55,55,110] { box([x,50,5],[12,84,12],2) }
        }
        // Window ribbons and projecting light fins follow the actual room blocks.
        let structure = parts.filter { $0.material == 1 }
        for volume in structure {
            for y in stride(from:volume.center.y-volume.size.y/2+12,through:volume.center.y+volume.size.y/2-5,by:17) {
                box([volume.center.x,y,volume.center.z+volume.size.z/2+0.6],[volume.size.x-12,5,1],3,solid:false)
                box([volume.center.x+volume.size.x/2+0.6,y,volume.center.z],[1,4,volume.size.z-12],3,solid:false)
            }
        }
        for x:Float in [-205,205] {
            for z:Float in [-130,-40,50,140] { box([x,12,z],[24,8,24],4,solid:false) }
        }
        for z:Float in stride(from:290,through:650,by:45) {
            for x:Float in [-100,100] { box([x,5,z],[5,3,15],3,solid:false) }
        }
        return parts
    }
}

struct ResidencePart: Sendable {
    let center: SIMD3<Float>
    let size: SIMD3<Float>
    let material: Int
    let solid: Bool
    func hits(_ point:SIMD3<Float>,radius:Float) -> Bool {
        let local = point-center
        return simd_distance_squared(local,simd_clamp(local,-size/2,size/2)) <= radius*radius
    }
}

enum InteriorItem: String, CaseIterable, Codable, Identifiable, Sendable {
    case lounge, holotable, garden, aquarium, art, jukebox, trophy, lights
    case readingChair, dining, cabinet, nebulaPainting, sunsetPainting, floorLamp, pendant, desk
    case patioLounge, bistro, planter, fountain, lantern, firepit
    var id: String { rawValue }
    var name: String { furnishing.name }
    var index: Int { Self.allCases.firstIndex(of:self)! }
    var price: Int { furnishing.price }
    var detail: String { furnishing.detail }
}

struct CityHousing: Codable, Equatable, Sendable {
    private(set) var owned: Set<CityPlot> = []
    private(set) var furniture: [String:Set<InteriorItem>] = [:]
    private(set) var installed: [String:Set<InteriorItem>] = [:]
    private(set) var layouts:[String:[String:RoomPlacement]]?
    private(set) var itemStates:[String:[String:HomeItemState]]?
    func items(in plot:CityPlot) -> Set<InteriorItem> { installed[plot.rawValue] ?? [] }
    func owns(_ item:InteriorItem,in plot:CityPlot) -> Bool { furniture[plot.rawValue]?.contains(item) == true }
    func state(_ item:InteriorItem,in plot:CityPlot) -> HomeItemState { itemStates?[plot.id]?[item.id] ?? item.initialState }
    func states(in plot:CityPlot) -> [InteriorItem:HomeItemState] { Dictionary(uniqueKeysWithValues:items(in:plot).map { ($0,state($0,in:plot)) }) }
    @discardableResult
    mutating func interact(_ item:InteriorItem,in plot:CityPlot) -> Bool {
        guard owned.contains(plot),items(in:plot).contains(item) else { return false }
        var value = state(item,in:plot)
        switch item.interaction {
        case .toggle,.cabinet:value.enabled.toggle()
        case .chart:value.variant = (value.variant+1)%3
        case .water:value.variant = 1
        default:return false
        }
        if itemStates == nil { itemStates = [:] }
        itemStates?[plot.id,default:[:]][item.id] = value; return true
    }
    mutating func build(_ plot:CityPlot) { owned.insert(plot) }
    @discardableResult
    mutating func furnish(_ item:InteriorItem,in plot:CityPlot) -> Bool {
        let newItems = items(in:plot).union([item])
        guard owned.contains(plot),let placement = HomeRoomLayout.freePlacement(item,preferred:layouts?[plot.id]?[item.id] ?? item.defaultPlacement,items:newItems,layout:layout(in:plot)) else { return false }
        furniture[plot.rawValue,default:[]].insert(item)
        installed[plot.rawValue,default:[]].insert(item)
        if layouts == nil { layouts = [:] }
        layouts?[plot.id,default:[:]][item.id] = placement
        return true
    }
    func layout(in plot:CityPlot) -> [InteriorItem:RoomPlacement] {
        Dictionary(uniqueKeysWithValues:items(in:plot).map { item in
            (item,layouts?[plot.id]?[item.id] ?? item.defaultPlacement)
        })
    }
    @discardableResult
    mutating func place(_ item:InteriorItem,in plot:CityPlot,at placement:RoomPlacement) -> Bool {
        guard owned.contains(plot),owns(item,in:plot),HomeRoomLayout.canPlace(item,at:placement,items:items(in:plot),layout:layout(in:plot)) else { return false }
        if layouts == nil { layouts = [:] }
        layouts?[plot.id,default:[:]][item.id] = placement; return true
    }
    mutating func resetLayout(in plot:CityPlot,area:HomeArea? = nil) {
        if let area { for item in InteriorItem.allCases where item.area == area { layouts?[plot.id]?.removeValue(forKey:item.id) } }
        else { layouts?.removeValue(forKey:plot.id) }
    }
    @discardableResult
    mutating func restoreLayout(_ candidate:[InteriorItem:RoomPlacement],in plot:CityPlot) -> Bool {
        let currentItems = items(in:plot)
        guard owned.contains(plot),Set(candidate.keys) == currentItems else { return false }
        for (item,placement) in candidate {
            if item.movable {
                guard HomeRoomLayout.canPlace(item,at:placement,items:currentItems,layout:candidate) else { return false }
            } else if placement != item.defaultPlacement { return false }
        }
        // Commit only after the complete layout passes. Stored item positions are retained.
        if layouts == nil { layouts = [:] }
        for (item,placement) in candidate { layouts?[plot.id,default:[:]][item.id] = placement }
        return true
    }
    @discardableResult
    mutating func toggle(_ item:InteriorItem,in plot:CityPlot) -> Bool {
        guard owned.contains(plot),owns(item,in:plot) else { return false }
        if installed[plot.rawValue]?.contains(item) == true { installed[plot.rawValue]?.remove(item); return true }
        return furnish(item,in:plot)
    }
    func impact(from:SIMD3<Float>,to:SIMD3<Float>,radius:Float) -> Bool {
        let steps = max(1,Int(ceil(simd_distance(from,to)/max(0.5,radius))))
        return (0...steps).contains { hits(from+(to-from)*Float($0)/Float(steps),radius:radius) }
    }
    func hits(_ point:SIMD3<Float>,radius:Float) -> Bool {
        owned.contains { plot in
            abs(point.x-plot.position.x)<400 && abs(point.z-plot.position.z)<400 &&
            plot.parts.contains { $0.solid && $0.hits(point-plot.position,radius:radius) }
        }
    }
}
