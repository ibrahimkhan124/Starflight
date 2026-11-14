import Foundation

enum MineralRarity: String, CaseIterable {
    case common, uncommon, rare, epic, legendary, exotic, mythic,impossible
    var name: String { rawValue.capitalized }
    var weight: Int { switch self { case .common: return 5000; case .uncommon: return 2800; case .rare: return 1400; case .epic: return 600; case .legendary: return 180; case .exotic: return 120; case .mythic: return 90; case .impossible: return 50 } }
    static var totalWeight: Int { allCases.reduce(0) { $0 + $1.weight } }
    var odds: String { String(format: weight < 20 ? "%.3f%%" : "%.1f%%", Double(weight) * 100 / Double(Self.totalWeight)) }
}

struct MinedMineralReward: Identifiable {
    let id = UUID()
    let mineral: TradeMineral
    let quantity: Int
}

enum MineralFamily: String { case metal, crystal, volatile, organic }

struct TradeMineral: Identifiable {
    let id: String
    let name: String
    let rarity: MineralRarity
    let family: MineralFamily
    let value: Int
    static let all: [Self] = [
        .init(id:"plastic", name:"Plastic", rarity:.common, family:.metal, value:4),
        .init(id:"Ruby", name:"Ruby", rarity:.epic, family:.volatile, value:60),
        .init(id:"lead", name:"Lead", rarity:.common, family:.metal, value:7),
        .init(id:"iron", name:"Iron", rarity:.common, family:.metal, value:10),
        .init(id:"copper", name:"Copper", rarity:.common, family:.metal, value:15),
        .init(id:"nickel", name:"Nickel", rarity:.common, family:.metal, value:17),
        .init(id:"silica", name:"Silica", rarity:.common, family:.crystal, value:18),
        .init(id:"carbon", name:"Carbon", rarity:.common, family:.organic, value:22),
        .init(id:"waterIce", name:"Water ice", rarity:.common, family:.volatile, value:23),
        .init(id:"aluminium", name:"Aluminium", rarity:.common, family:.metal, value:27),
        .init(id:"sulphur", name:"Sulphur", rarity:.common, family:.volatile, value:27),
        .init(id:"titanium", name:"Titanium", rarity:.uncommon, family:.metal, value:30),
        .init(id:"cobalt", name:"Cobalt", rarity:.uncommon, family:.metal, value:30),
        .init(id:"lithium", name:"Lithium", rarity:.uncommon, family:.metal, value:30),
        .init(id:"ammonia", name:"Ammonia ice", rarity:.uncommon, family:.volatile, value:37),
        .init(id:"resinite", name:"Resinite", rarity:.uncommon, family:.organic, value:40),
        .init(id:"chromium", name:"Chromium", rarity:.uncommon, family:.metal, value:44),
        .init(id:"platinum", name:"Platinum", rarity:.rare, family:.metal, value:50),
        .init(id:"quartz", name:"Quartz", rarity:.rare, family:.crystal, value:50),
        .init(id:"iridium", name:"Iridium", rarity:.rare, family:.metal, value:55),
        .init(id:"sapphire", name:"Star sapphire", rarity:.rare, family:.crystal, value:58),
        .init(id:"deuterium", name:"Deuterium ice", rarity:.rare, family:.volatile, value:66),
        .init(id:"amberite", name:"Amberite", rarity:.rare, family:.organic, value:72),
        .init(id:"electrum", name:"Electrum", rarity:.rare, family:.metal, value:78),
        .init(id:"aether", name:"Aether crystal", rarity:.epic, family:.crystal, value:125),
        .init(id:"voidsteel", name:"Voidsteel ore", rarity:.epic, family:.metal, value:140),
        .init(id:"plasmaSalt", name:"Plasma salt", rarity:.epic, family:.volatile, value:130),
        .init(id:"lumen", name:"Lumen pearl", rarity:.epic, family:.organic, value:150),
        .init(id:"nova", name:"Nova diamond", rarity:.legendary, family:.crystal, value:350),
        .init(id:"neutronium", name:"Neutronium", rarity:.legendary, family:.metal, value:400),
        .init(id:"helios", name:"Helios core", rarity:.legendary, family:.volatile, value:380),
        .init(id:"neutron", name:"neutron core", rarity:.legendary, family:.metal, value:780),
        .init(id:"singularity", name:"Singularity shard", rarity:.exotic, family:.crystal, value:900),
        .init(id:"stardust", name:"Primordial stardust", rarity:.exotic, family:.organic, value:1000),
        .init(id:"future star", name:"Future star dust", rarity:.mythic, family:.organic, value:10000),
        .init(id:"God star", name:"God's star dust", rarity:.impossible, family:.volatile, value:10000000),
        .init(id:"Black hole", name:"Black hole dust", rarity:.impossible, family:.volatile, value:100000000),
        .init(id:"Sun Ice", name:"Sun Ice", rarity:.impossible, family:.volatile, value:1000000000),
       
    ]
    /// Tier odds are exact; materials within a tier have equal chances.
    static func draw(tierRoll: Int, materialRoll: Int) -> Self {
        var cumulative = 0
        let roll = min(MineralRarity.totalWeight - 1,max(0,tierRoll))
        let rarity = MineralRarity.allCases.first { cumulative += $0.weight; return roll < cumulative } ?? .common
        let choices = all.filter { $0.rarity == rarity }
        return choices[max(0,materialRoll) % choices.count]
    }
    func price(at planet: SpacePlanet) -> Int {
        let premium: Bool
        switch planet {
        case .coruscant: premium = family == .metal
        case .tatooine: premium = family == .volatile
        case .hoth: premium = family == .crystal
        case .endor: premium = family == .organic
        }
        return premium ? value*3/2 : value
    }
}

struct SpaceTradeRoute: Identifiable {
    let id: String
    let origin: SpacePlanet
    let destination: SpacePlanet
    let cost: Int
    var name: String { origin.name + " ↔ " + destination.name }
    func serves(_ port: SpacePlanet) -> Bool { origin == port || destination == port }
    static let all: [Self] = [
        .init(id:"coreDesert",origin:.coruscant,destination:.tatooine,cost:0),
        .init(id:"iceRun",origin:.tatooine,destination:.hoth,cost:750),
        .init(id:"forestLink",origin:.coruscant,destination:.endor,cost:1500),
        .init(id:"polarExpress",origin:.coruscant,destination:.hoth,cost:2200),
        .init(id:"frontier",origin:.tatooine,destination:.endor,cost:3000),
        .init(id:"outerCircuit",origin:.hoth,destination:.endor,cost:4500)
    ]
}

struct TradeDelivery: Codable, Equatable {
    let routeID: String
    let departure: String
    var destination: SpacePlanet? {
        guard let route = SpaceTradeRoute.all.first(where:{$0.id == routeID}), let from = SpacePlanet(rawValue:departure), route.serves(from) else { return nil }
        return from == route.origin ? route.destination : route.origin
    }
}

struct SpaceTrading: Codable, Equatable {
    static let capacity = 120
    var cargo: [String:Int] = [:]
    var discovered: Set<String> = []
    var routes: Set<String> = []
    var mined = 0
    var sold = 0
    var revenue = 0
    var delivery: TradeDelivery?
    var deliveries: Int? = 0
    var used: Int { cargo.values.reduce(0,+) }
    func canTrade(at planet: SpacePlanet) -> Bool { SpaceTradeRoute.all.contains { routes.contains($0.id) && $0.serves(planet) } }
    /// Offer the least expensive missing connection at the player's current market.
    func requiredRoute(at planet: SpacePlanet) -> SpaceTradeRoute? {
        guard !canTrade(at: planet) else { return nil }
        return SpaceTradeRoute.all.filter { $0.serves(planet) && !routes.contains($0.id) }
            .min { $0.cost == $1.cost ? $0.id < $1.id : $0.cost < $1.cost }
    }
    func quote(at planet: SpacePlanet) -> Int {
        let base = TradeMineral.all.reduce(0) { $0 + $1.price(at:planet)*(cargo[$1.id] ?? 0) }
        return base + (delivery?.destination == planet ? base/5 : 0)
    }
    var valid: Bool {
        let ids = Set(TradeMineral.all.map(\.id))
        return cargo.count <= ids.count && Set(cargo.keys).isSubset(of:ids) && discovered.isSubset(of:ids)
            && cargo.values.allSatisfy { (0...Self.capacity).contains($0) } && used <= Self.capacity
            && routes.isSubset(of:Set(SpaceTradeRoute.all.map(\.id)))
            && (0...1_000_000_000).contains(mined) && (0...1_000_000_000).contains(sold)
            && (0...1_000_000_000).contains(revenue)
            && (0...1_000_000_000).contains(deliveries ?? 0)
            && (delivery == nil || (delivery?.destination != nil && routes.contains(delivery!.routeID)))
    }
}


/// A scan identifies a specific rock; mining that rock yields the same material.
struct OreSurvey {
    let asteroidID: Int
    let mineral: TradeMineral
    let position: SIMD3<Float>
    let distance: Float
    let hazardous: Bool
    var summary: String { "\(mineral.name) · \(mineral.rarity.name) · \(Int(distance)) m at scan · " + (hazardous ? "Large rock · approach slowly" : "Small rock · keep clear") }
}
