import Foundation
import simd

enum CityFaction: String, CaseIterable, Codable, Identifiable, Sendable {
    case republic, empire, hunters
    var id: String { rawValue }
    var name: String { self == .republic ? "Republic · the good side" : self == .empire ? "Empire · the dark side" : "Bounty Hunters' Guild" }
    var brief: String {
        switch self {
        case .republic: return "Protect civilians and fly relief supplies. Earn Republic standing through rescues and aid deliveries."
        case .empire: return "Fly classified dispatches and scan the capital for Imperial command. Earn Imperial standing."
        case .hunters: return "Track marked pirate craft above the city. Disable their shields with your ship's guns and collect the bounty."
        }
    }
}

struct CityFactionProgress: Codable, Equatable {
    private(set) var standing: [String:Int] = [:]
    private(set) var bountyReceipts: Set<UUID> = []
    func points(_ faction:CityFaction) -> Int { standing[faction.rawValue] ?? 0 }
    func rank(_ faction:CityFaction) -> String {
        let p = points(faction)
        return p >= 100 ? "Elite operative" : p >= 40 ? "Trusted specialist" : p >= 10 ? "Field agent" : "New contact"
    }
    mutating func record(_ faction:CityFaction) { standing[faction.rawValue,default:0] += 10 }
    mutating func claimBounty(_ id:UUID) -> Bool {
        guard bountyReceipts.insert(id).inserted else { return false }
        record(.hunters); return true
    }
}

enum BountyContract: String, CaseIterable, Identifiable, Sendable {
    case runaway, syndicate
    var id:String { rawValue }
    var name:String { self == .runaway ? "The Neon Runner" : "Syndicate Wing" }
    var reward:Int { self == .runaway ? 180 : 320 }
    var count:Int { self == .runaway ? 1 : 3 }
    var requiredStanding:Int { self == .runaway ? 0 : 20 }
    var description:String { self == .runaway ? "Disable one wanted pirate above the Spaceport. Its shield takes several hits; incoming fire is slow and does light damage." : "Track three marked syndicate pilots above the capital. Disable every shield to complete the contract." }
}

struct BountyTarget: Identifiable {
    let id:Int
    var position:SIMD3<Float>
    var velocity:SIMD3<Float> = .zero
    var health:Float = 85
    var cooldown:Float = 5
}

struct CityBountyHunt {
    private(set) var contract:BountyContract?
    private(set) var receipt:UUID?
    private(set) var targets:[BountyTarget] = []
    private(set) var bolts:[TurretBolt] = []
    private var origin:SIMD3<Float> = .zero
    private var time:Float = 0
    var remaining:Int { targets.count }
    var target:SIMD3<Float>? { targets.first?.position }
    mutating func start(_ job:BountyContract,near state:FlightState) {
        reset(); contract = job; receipt = UUID()
        // Above the tallest city tower; no spawn inside a building or behind the ship.
        origin = state.position + state.forward*650
        origin.y = 1000; origin.x = clamp(origin.x,-10000,10000); origin.z = clamp(origin.z,-10000,10000)
        targets = (0..<job.count).map { index in
            let phase = Float(index)*1.3
            return BountyTarget(id:index,position:origin+SIMD3<Float>(sin(phase)*220,Float(index)*35,Float(index)*100+cos(phase)*110))
        }
    }
    mutating func reset() { contract = nil; receipt = nil; targets = []; bolts = []; time = 0 }
    /// Swept relative segments register fast shots and consume each bolt at most once.
    mutating func advance(ship:FlightState,playerBolts:[PlayerBolt],dt:Float) -> (consumed:Set<Int>,damage:Float,completed:Bool) {
        guard contract != nil, dt.isFinite, dt > 0, dt <= 0.25 else { return ([],0,false) }
        time += dt
        var consumed:Set<Int> = [], damage:Float = 0
        for index in targets.indices {
            let previous = targets[index].position
            let phase = time*0.12+Float(targets[index].id)*1.3
            targets[index].position = origin + [sin(phase)*220,Float(targets[index].id)*35+sin(time*0.3)*22,Float(targets[index].id)*100+cos(phase)*110]
            targets[index].velocity = (targets[index].position-previous)/dt
            for (boltIndex,bolt) in playerBolts.enumerated() where !consumed.contains(boltIndex) {
                let from = bolt.position-bolt.velocity*min(dt,bolt.age)-previous
                let to = bolt.position-targets[index].position
                let segment = to-from
                let t = clamp(-simd_dot(from,segment)/max(0.001,simd_length_squared(segment)),0,1)
                if simd_length(from+segment*t) < 26 {
                    targets[index].health -= bolt.damage; consumed.insert(boltIndex)
                }
            }
            targets[index].cooldown -= dt
            let delta = ship.position-targets[index].position
            if targets[index].health > 0, targets[index].cooldown <= 0, simd_length(delta)>120, simd_length(delta)<1400,bolts.count<8 {
                bolts.append(TurretBolt(position:targets[index].position,velocity:simd_normalize(delta)*110,fromPursuer:true))
                targets[index].cooldown = 5.5
            }
        }
        targets.removeAll { $0.health <= 0 }
        for index in bolts.indices {
            let from = bolts[index].position
            bolts[index].position += bolts[index].velocity*dt; bolts[index].age += dt
            let segment = bolts[index].position-from
            let t = clamp(simd_dot(ship.position-from,segment)/max(0.001,simd_length_squared(segment)),0,1)
            if simd_distance(from+segment*t,ship.position)<6 { damage += 3; bolts[index].age = 10 }
        }
        bolts.removeAll { $0.age>8 }
        if targets.isEmpty { bolts = [] }
        return (consumed,damage,targets.isEmpty)
    }
}
