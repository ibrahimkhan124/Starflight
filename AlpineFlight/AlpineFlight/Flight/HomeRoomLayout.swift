import Foundation
import simd

// One room footprint for rendering, walking and the furniture editor.
// Furniture anchors stay unchanged so existing saved arrangements remain valid.
enum HomeRoomGeometry {
    static let width:Float = 40
    static let depth:Float = 32
    static let height:Float = 8
    static let halfSize = SIMD2<Float>(width/2,depth/2)
    static let furnitureLimit = halfSize-SIMD2<Float>(repeating:1)
    static let walkingLimit = halfSize-SIMD2<Float>(repeating:0.6)
    static let entrance = SIMD2<Float>(4,depth/2-1.5)
    static let entranceHalfSize = SIMD2<Float>(1.5,1.5)
    static let walkingStart = SIMD2<Float>(entrance.x,depth/2-2)
    static var dimensionsLabel:String { String(format:"%.0f × %.0f m · %.0f m²",width,depth,width*depth) }
}

struct RoomPlacement:Codable,Equatable,Sendable {
    var x:Float
    var z:Float
    var turns:Int = 0
    var point:SIMD2<Float> { [x,z] }
    var snapped:RoomPlacement {
        RoomPlacement(x:(x*2).rounded()/2,z:(z*2).rounded()/2,turns:turns)
    }
    func halfSize(for item:InteriorItem) -> SIMD2<Float> {
        let size = item.roomHalfSize
        return turns.isMultiple(of:2) ? size:SIMD2<Float>(size.y,size.x)
    }
}

extension InteriorItem {
    var movable:Bool { self != .lights }
    var defaultPlacement:RoomPlacement {
        let point = furnishing.position; return RoomPlacement(x:point.x,z:point.y)
    }
    var roomHalfSize:SIMD2<Float> {
        furnishing.halfSize
    }
}

enum HomeRoomLayout {
    static func placement(_ item:InteriorItem,in layout:[InteriorItem:RoomPlacement]) -> RoomPlacement { layout[item] ?? item.defaultPlacement }
    static func canPlace(_ item:InteriorItem,at candidate:RoomPlacement,items:Set<InteriorItem>,layout:[InteriorItem:RoomPlacement]) -> Bool {
        placementIssue(item,at:candidate,items:items,layout:layout) == nil
    }
    static func placementIssue(_ item:InteriorItem,at candidate:RoomPlacement,items:Set<InteriorItem>,layout:[InteriorItem:RoomPlacement]) -> String? {
        guard item.movable else { return "Ceiling lighting stays fixed." }
        guard items.contains(item) else { return "Install this furniture set first." }
        guard candidate.x.isFinite,candidate.z.isFinite,(0..<4).contains(candidate.turns) else { return "Choose a position inside the room." }
        let half = candidate.halfSize(for:item)
        // Prefer the useful doorway explanation when a set also reaches the front wall.
        if item.layer == .wall {
            guard abs(candidate.x+19.75)<0.01,candidate.turns == 0,abs(candidate.z)+half.y<=14.5 else { return "Hang paintings on the left gallery wall. Drag along the wall to choose a position." }
        } else {
            if item.blocksWalking,overlaps(candidate.point,half,HomeRoomGeometry.entrance,HomeRoomGeometry.entranceHalfSize) { return "Keep the entrance clear so you can walk into the room." }
            guard abs(candidate.x)+half.x <= HomeRoomGeometry.furnitureLimit.x,
                  abs(candidate.z)+half.y <= HomeRoomGeometry.furnitureLimit.y else { return "Too close to the wall. Move the whole set inside the floor plan." }
        }
        for other in InteriorItem.allCases where items.contains(other) && other != item && other.movable && other.area == item.area && other.layer == item.layer {
            let p = placement(other,in:layout)
            if overlaps(candidate.point,half,p.point,p.halfSize(for:other)) { return "Overlaps \(other.name). Move it into an open space." }
        }
        return nil
    }
    static func freePlacement(_ item:InteriorItem,preferred:RoomPlacement,items:Set<InteriorItem>,layout:[InteriorItem:RoomPlacement]) -> RoomPlacement? {
        if !item.movable { return item.defaultPlacement }
        if canPlace(item,at:preferred,items:items,layout:layout) { return preferred }
        var best:RoomPlacement?, bestDistance = Float.infinity
        if item.layer == .wall {
            for z:Float in stride(from:-12,through:12,by:0.5) {
                let p = RoomPlacement(x:-19.75,z:z), distance = abs(z-preferred.z)
                if distance<bestDistance,canPlace(item,at:p,items:items,layout:layout) { best = p; bestDistance = distance }
            }
            return best
        }
        let limit = HomeRoomGeometry.furnitureLimit
        for z:Float in stride(from:-limit.y,through:limit.y,by:1) {
            for x:Float in stride(from:-limit.x,through:limit.x,by:1) {
                for turns in 0..<2 {
                    let p = RoomPlacement(x:x,z:z,turns:turns)
                    let distance = simd_length_squared(p.point-preferred.point)
                    if distance<bestDistance,canPlace(item,at:p,items:items,layout:layout) { best = p; bestDistance = distance }
                }
            }
        }
        return best
    }
    static func overlaps(_ a:SIMD2<Float>,_ ah:SIMD2<Float>,_ b:SIMD2<Float>,_ bh:SIMD2<Float>) -> Bool {
        abs(a.x-b.x)<ah.x+bh.x+0.1 && abs(a.y-b.y)<ah.y+bh.y+0.1
    }
}

/// Session-only edit history. Purchases and installed item ownership never enter this stack.
struct HomeArrangementHistory {
    typealias Layout = [InteriorItem:RoomPlacement]
    private var previous:[Layout] = []
    private var next:[Layout] = []
    var undoTarget:Layout? { previous.last }
    var redoTarget:Layout? { next.last }
    mutating func record(before:Layout,after:Layout) {
        guard before != after else { return }
        previous.append(before)
        if previous.count>40 { previous.removeFirst() }
        next.removeAll()
    }
    mutating func didUndo(current:Layout) {
        guard previous.popLast() != nil else { return }
        next.append(current)
    }
    mutating func didRedo(current:Layout) {
        guard next.popLast() != nil else { return }
        previous.append(current)
    }
}
