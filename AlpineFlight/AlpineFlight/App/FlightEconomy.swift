import Foundation

enum BlueprintPack: String, CaseIterable, Identifiable {
    case scout, elite, ace, nebula
    var id: String { rawValue }
    var name: String { rawValue.capitalized + " pack" }
    var cost: Int {
        switch self { case .scout: return 400; case .elite: return 900; case .ace: return 1400; case .nebula: return 2000 }
    }
    var cards: Int {
        switch self { case .scout: return 3; case .elite: return 6; case .ace: return 10; case .nebula: return 15 }
    }
    func chance(for ship: AircraftType) -> Double {
        guard AircraftType.blueprintFleet.contains(ship) else { return 0 }
        let members = AircraftType.blueprintFleet.filter { $0.blueprintRarityIndex == ship.blueprintRarityIndex }.count
        return Double(weights[ship.blueprintRarityIndex])/Double(members)
    }
    /// Independent per-card odds, also displayed directly by the shop.
    var weights: [Int] {
        switch self { case .scout: return [90,9,1]; case .elite: return [82,16,2]; case .ace: return [70,25,5]; case .nebula: return [60,32,8] }
    }
}

struct BlueprintReward: Codable, Equatable, Identifiable {
    var id = UUID()
    let ship: AircraftType
    let collected: Int
    let duplicateCredits: Int
    let unlockedNow: Bool
    var spareCount: Int? = nil
    var receipt: String {
        "\(collected) \(ship.name) blueprint\(collected == 1 ? "" : "s")" +
        ((spareCount ?? 0) > 0 ? " · \(spareCount ?? 0) spare blueprints saved" : "") +
        (duplicateCredits > 0 ? " · \(duplicateCredits) duplicate credits" : "") +
        (unlockedNow ? " · SHIP UNLOCKED!" : "")
    }
}

enum DailyPrize: Int, CaseIterable, Identifiable {
    case credits100, credits250, credits500, bWing, shuttle, defender, scoutPack, elitePack, slaveI, avatarAccessory
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .avatarAccessory: return "Avatar accessory"
        case .credits100: return "100 credits"
        case .credits250: return "250 credits"
        case .credits500: return "500 credits"
        case .bWing: return "2 B-wing blueprints"
        case .shuttle: return "2 Shuttle blueprints"
        case .defender: return "1 Defender blueprint"
        case .scoutPack: return "Scout pack"
        case .elitePack: return "Elite pack"
        case .slaveI: return "2 slaveI blueprints"
        }
    }
    var wheelLabel: String {
        switch self {
        case .avatarAccessory: return "ACCESSORY"
        case .credits100: return "100 CR"
        case .credits250: return "250 CR"
        case .credits500: return "500 CR"
        case .bWing: return "B-WING ×2"
        case .shuttle: return "SHUTTLE ×2"
        case .defender: return "DEFENDER"
        case .scoutPack: return "SCOUT PACK"
        case .elitePack: return "ELITE PACK"
        case .slaveI: return "2 slaveI blueprints"
        }
    }
}

extension AircraftType {
    static let blueprintFleet: [AircraftType] = [.bWing,.imperialShuttle,.tieDefender,.tieInterceptor,.slaveI,.scimitar]
    var blueprintRarityIndex: Int { rarity == "Rare" ? 0 : rarity == "Epic" ? 1 : 2 }
    var blueprintRequirement: Int {
        switch self { case .tieInterceptor: return 18; case .slaveI: return 40; case .scimitar: return 100; case .bWing: return 12; case .imperialShuttle: return 30; case .tieDefender: return 90; default: return 0 }
    }
    var blueprintSaleCredits: Int {
        switch self { case .bWing,.tieInterceptor: return 50; case .imperialShuttle,.slaveI: return 150; case .tieDefender,.scimitar: return 900; default: return 0 }
    }
    var rarity: String {
        switch self { case .bWing,.tieInterceptor: return "Rare"; case .imperialShuttle,.slaveI: return "Epic"; case .tieDefender,.scimitar: return "Legendary"; default: return "Standard" }
    }
}

/// Exact quarter-credit accounting: one newly earned FLP contributes one quarter-credit.
struct FlightEconomy: Codable, Equatable {
    private(set) var profile: PilotProfile?
    private(set) var story: StoryCampaignProgress?
    /// Bonuses earned in earlier runs. Optional for wallets saved before story replay existed.
    private(set) var previousStoryRewards: Set<String>?
    private(set) var adventures: FlightAdventureProgress?
    private(set) var quarterCredits = 0
    private(set) var blueprints: [String:Int] = [:]
    private(set) var lastSpinDay: Int?
    private(set) var lastSpinReceipt = ""
    // Optional additions decode older saves without discarding the player's wallet.
    private(set) var unlockedShips: Set<String>? = []
    private(set) var lastBlueprintRewards: [BlueprintReward]?
    private(set) var spareBlueprints: [String:Int]? = [:]
    private(set) var arenaReceipts: Set<UUID>? = []
    private(set) var cityJobReceipts: Set<UUID>? = []
    private(set) var cityCareer: CityCareer?
    private(set) var housing: CityHousing?
    private(set) var trading: SpaceTrading?
    private(set) var factions: CityFactionProgress?
    var completedCityJobs: Int { cityJobReceipts?.count ?? 0 }
    var cityRank: String { CityCareer.rank(completed:completedCityJobs) }
    static let key = "starflight.economy.v1"
    var creditsLabel: String { String(format:"%.2f",Double(quarterCredits)/4) }
    func count(for ship:AircraftType) -> Int { min(ship.blueprintRequirement,max(0,blueprints[ship.rawValue] ?? 0)) }
    func unlocked(_ ship:AircraftType) -> Bool { ship.blueprintRequirement == 0 || unlockedShips?.contains(ship.rawValue) == true || count(for:ship) >= ship.blueprintRequirement }
    func extras(for ship: AircraftType) -> Int { max(0,spareBlueprints?[ship.rawValue] ?? 0) }
    /// Only saved surplus is tradable. Unlock progress and owned ships are never consumed.
    @discardableResult
    mutating func sellExtras(for ship: AircraftType) -> Int {
        let price = ship.blueprintSaleCredits
        guard price > 0, unlocked(ship) else { return 0 }
        // Respect the wallet's numeric limit without consuming unpaid blueprints.
        let quantity = min(extras(for:ship),(Int.max/4-quarterCredits)/(price*4))
        guard quantity > 0 else { return 0 }
        let remaining = extras(for:ship)-quantity
        spareBlueprints?[ship.rawValue] = remaining
        let proceeds = quantity*price
        credits(proceeds)
        return proceeds
    }
    mutating func earn(lowFlightPoints:Int) {
        guard lowFlightPoints > 0 else { return }
        quarterCredits += min(lowFlightPoints,Int.max/4 - quarterCredits)
    }
    /// The receipt and wallet are encoded together, preventing rematches/reloads from paying twice.
    @discardableResult
    mutating func claimArena(id:UUID,format:ArenaFormat,difficulty:ArenaDifficulty,outcome:ArenaOutcome?) -> Int {
        guard outcome == .victory, !(arenaReceipts?.contains(id) ?? false) else { return 0 }
        let amount = format.victoryReward(for:difficulty)
        guard quarterCredits <= Int.max/4-amount*4 else { return 0 }
        if arenaReceipts == nil { arenaReceipts = [] }
        arenaReceipts?.insert(id)
        credits(amount)
        return amount
    }
    @discardableResult
    mutating func claimCityJob(id:UUID,credits amount:Int,report:CityJobReport? = nil) -> Bool {
        guard amount > 0, amount <= 1000, !(cityJobReceipts?.contains(id) ?? false) else { return false }
        if let report {
            guard report.id == id, report.credits == amount, (0...100).contains(report.condition),
                  (1...5).contains(report.stars), report.seconds.isFinite, report.seconds >= 0,
                  report.kilometres.isFinite, report.kilometres >= 0,
                  report.bonusCredits >= 0, report.bonusCredits <= report.contract.maximumBonus else { return false }
        }
        if cityJobReceipts == nil { cityJobReceipts = [] }
        cityJobReceipts?.insert(id)
        earn(lowFlightPoints:amount*4)
        if let report {
            if cityCareer == nil { cityCareer = CityCareer() }
            cityCareer?.record(report)
            if let faction = report.contract.faction {
                if factions == nil { factions = CityFactionProgress() }; factions?.record(faction)
            }
        }
        return true
    }
    @discardableResult
    mutating func buyHome(_ plot:CityPlot) -> Bool {
        guard housing?.owned.contains(plot) != true, quarterCredits >= plot.price*4 else { return false }
        quarterCredits -= plot.price*4
        if housing == nil { housing = CityHousing() }
        housing?.build(plot); return true
    }
    @discardableResult
    mutating func buyInterior(_ item:InteriorItem,in plot:CityPlot) -> Bool {
        guard housing?.owned.contains(plot) == true, housing?.owns(item,in:plot) != true,
              quarterCredits >= item.price*4 else { return false }
        guard housing?.furnish(item,in:plot) == true else { return false }
        quarterCredits -= item.price*4; return true
    }
    @discardableResult
    mutating func toggleInterior(_ item:InteriorItem,in plot:CityPlot) -> Bool { housing?.toggle(item,in:plot) == true }
    @discardableResult
    mutating func placeInterior(_ item:InteriorItem,in plot:CityPlot,at placement:RoomPlacement) -> Bool {
        housing?.place(item,in:plot,at:placement) == true
    }
    mutating func resetInteriorLayout(in plot:CityPlot,area:HomeArea? = nil) { housing?.resetLayout(in:plot,area:area) }
    @discardableResult
    mutating func interactInterior(_ item:InteriorItem,in plot:CityPlot) -> Bool { housing?.interact(item,in:plot) == true }
    @discardableResult
    mutating func restoreInteriorLayout(_ layout:[InteriorItem:RoomPlacement],in plot:CityPlot) -> Bool {
        housing?.restoreLayout(layout,in:plot) == true
    }
    @discardableResult
    mutating func claimBounty(_ id:UUID,contract:BountyContract) -> Bool {
        if factions == nil { factions = CityFactionProgress() }
        guard factions?.claimBounty(id) == true else { return false }
        credits(contract.reward); return true
    }
    private mutating func credits(_ amount:Int) { earn(lowFlightPoints:amount*4) }
    @discardableResult
    mutating func grant(_ ship:AircraftType, count amount:Int) -> String {
        guard ship.blueprintRequirement > 0, amount > 0 else { return "" }
        let wasUnlocked = unlocked(ship)
        let before = count(for:ship)
        let applied = wasUnlocked ? 0 : min(amount,ship.blueprintRequirement-before)
        blueprints[ship.rawValue] = before+applied
        let surplus = amount-applied
        if spareBlueprints == nil { spareBlueprints = [:] }
        let existing = extras(for:ship)
        spareBlueprints?[ship.rawValue] = existing+min(surplus,Int.max-existing)
        let unlockedNow = !wasUnlocked && count(for:ship) >= ship.blueprintRequirement
        if unlockedNow { unlockedShips?.insert(ship.rawValue) }
        let reward = BlueprintReward(ship:ship,collected:applied,duplicateCredits:0,unlockedNow:unlockedNow,spareCount:surplus)
        lastBlueprintRewards = [reward]
        return reward.receipt
    }
    private mutating func open<R:RandomNumberGenerator>(_ pack:BlueprintPack,rng:inout R) -> String {
        var rewards: [BlueprintReward] = []
        for _ in 0..<pack.cards {
            let roll = Int.random(in:0..<100,using:&rng)
            let index = roll < pack.weights[0] ? 0 : roll < pack.weights[0]+pack.weights[1] ? 1 : 2
            let candidates = AircraftType.blueprintFleet.filter { $0.blueprintRarityIndex == index }
            let ship = candidates[Int.random(in:0..<candidates.count,using:&rng)]
            grant(ship,count:1)
            rewards.append(contentsOf:lastBlueprintRewards ?? [])
        }
        // Rewards are committed before presentation. Revealing cards never draws again.
        lastBlueprintRewards = rewards
        return rewards.map(\.receipt).joined(separator:"\n")
    }
    mutating func buy<R:RandomNumberGenerator>(_ pack:BlueprintPack,rng:inout R) -> String? {
        guard quarterCredits >= pack.cost*4 else { return nil }
        quarterCredits -= pack.cost*4
        return open(pack,rng:&rng)
    }
    static func day(_ date:Date) -> Int { Int(floor(date.timeIntervalSince1970/86400)) }
    func canSpin(at date:Date) -> Bool { lastSpinDay.map { Self.day(date) > $0 } ?? true }
    mutating func spin<R:RandomNumberGenerator>(at date:Date,rng:inout R) -> DailyPrize? {
        guard canSpin(at:date) else { return nil }
        // Commit the day and reward together before presentation, so dismissing cannot reroll.
        lastBlueprintRewards = nil
        lastSpinDay = Self.day(date)
        let prize = DailyPrize.allCases[Int.random(in:0..<DailyPrize.allCases.count,using:&rng)]
        let reward: String
        switch prize {
        case .credits100: credits(100); reward = prize.label
        case .credits250: credits(250); reward = prize.label
        case .credits500: credits(500); reward = prize.label
        case .bWing: reward = grant(.bWing,count:2)
        case .shuttle: reward = grant(.imperialShuttle,count:2)
        case .defender: reward = grant(.tieDefender,count:1)
        case .scoutPack: reward = open(.scout,rng:&rng)
        case .elitePack: reward = open(.elite,rng:&rng)
        case .avatarAccessory: reward = awardAccessory(rng: &rng)
        case .slaveI: reward = grant(.slaveI,count:2)
        
        }
        lastSpinReceipt = reward == prize.label ? reward : prize.label + "\n" + reward
        return prize
    }
    mutating func editProfile(name: String, suit: String, species: String? = nil) {
        guard PilotProfile.colors.contains(suit) else { return }
        var value = profile ?? PilotProfile()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let species, ["Human", "Droid", "Alien"].contains(species) { value.species = species }
        value.name = trimmed.isEmpty ? "Star pilot" : String(trimmed.prefix(24)); value.suit = suit; profile = value
    }
    mutating func buyAccessory(_ item: AvatarAccessory) -> Bool {
        var value = profile ?? PilotProfile()
        guard !value.owned.contains(item), quarterCredits >= item.price*4 else { return false }
        quarterCredits -= item.price*4; value.owned.insert(item); value.equipped = item; profile = value; return true
    }
    mutating func equipAccessory(_ item: AvatarAccessory?) {
        var value = profile ?? PilotProfile()
        guard item == nil || value.owned.contains(item!) else { return }
        value.equipped = item; profile = value
    }
    mutating func awardAccessory<R: RandomNumberGenerator>(rng: inout R) -> String {
        var value = profile ?? PilotProfile()
        let available = AvatarAccessory.allCases.filter { !value.owned.contains($0) }
        guard let item = available.randomElement(using: &rng) else { credits(250); return "All accessories owned · 250 credits instead" }
        value.owned.insert(item); if value.equipped == nil { value.equipped = item }; profile = value
        return "Unlocked " + item.title
    }
    func save(to defaults:UserDefaults) { if let data = try? JSONEncoder().encode(self) { defaults.set(data,forKey:Self.key) } }
    static func load(from defaults:UserDefaults) -> Self {
        guard let data = defaults.data(forKey:key), var state = try? JSONDecoder().decode(Self.self,from:data) else { return Self() }
        if state.unlockedShips == nil {
            // Grandfather ships completed before the legendary requirement increased.
            state.unlockedShips = Set(AircraftType.blueprintFleet.filter {
                (state.blueprints[$0.rawValue] ?? 0) >= ($0 == .tieDefender ? 60 : $0.blueprintRequirement)
            }.map(\.rawValue))
        }
        if state.profile?.valid == false { state.profile = nil }
        if state.trading?.valid == false { state.trading = nil }
        if state.adventures?.valid == false { state.adventures = nil }
        if state.story?.valid == false { state.story = nil }
        if !state.validStoryRewards { state.previousStoryRewards = nil }
        state.quarterCredits = clamp(state.quarterCredits,0,Int.max/4)
        for ship in AircraftType.blueprintFleet where state.blueprints[ship.rawValue] != nil { state.blueprints[ship.rawValue] = state.count(for:ship) }
        return state
    }
}

struct FlightFuel {
    private(set) var metres: Double = 0
    var percent: Double { max(0,100-metres/5000) }
    var empty: Bool { percent <= 0 }
    mutating func travel(_ distance:Float) {
        guard distance.isFinite, distance > 0 else { return }
        metres = min(500000,metres+Double(distance))
    }
}

extension FlightEconomy {
    @discardableResult
    mutating func collectMineral(_ material: TradeMineral, quantity: Int) -> Int {
        var hold = trading ?? SpaceTrading()
        guard hold.valid, TradeMineral.all.contains(where:{$0.id == material.id}), quantity > 0 else { return 0 }
        let count = min(quantity,SpaceTrading.capacity-hold.used)
        guard count > 0 else { return 0 }
        hold.cargo[material.id,default:0] += count; hold.discovered.insert(material.id)
        hold.mined = min(1_000_000_000,hold.mined+count); trading = hold
        return count
    }
    @discardableResult
    mutating func openTradeRoute(_ route: SpaceTradeRoute) -> Bool {
        var hold = trading ?? SpaceTrading()
        guard hold.valid, let actual = SpaceTradeRoute.all.first(where:{$0.id == route.id}),
              !hold.routes.contains(actual.id), quarterCredits >= actual.cost*4 else { return false }
        quarterCredits -= actual.cost*4; hold.routes.insert(actual.id); trading = hold; return true
    }
    @discardableResult
    mutating func sellMineralCargo(at port: SpacePlanet) -> Int {
        var hold = trading ?? SpaceTrading()
        guard hold.valid, hold.used > 0, hold.canTrade(at:port) else { return 0 }
        let amount = hold.quote(at:port)
        guard amount > 0, quarterCredits <= Int.max/4-amount*4,
              hold.revenue <= 1_000_000_000-amount else { return 0 }
        quarterCredits += amount*4
        if hold.delivery?.destination == port {
            hold.deliveries = min(1_000_000_000,(hold.deliveries ?? 0)+1); hold.delivery = nil
        }
        hold.sold = min(1_000_000_000,hold.sold+hold.used); hold.revenue += amount
        hold.cargo.removeAll(); trading = hold; return amount
    }
    @discardableResult
    mutating func beginTradeRun(_ route: SpaceTradeRoute, from port: SpacePlanet) -> Bool {
        var hold = trading ?? SpaceTrading()
        guard hold.valid, hold.routes.contains(route.id),
              SpaceTradeRoute.all.first(where:{$0.id == route.id})?.serves(port) == true,
              hold.delivery == nil else { return false }
        hold.delivery = TradeDelivery(routeID:route.id,departure:port.rawValue); trading = hold; return true
    }
}

extension FlightEconomy {
    var adventureProgress: FlightAdventureProgress { adventures ?? FlightAdventureProgress() }
    @discardableResult
    mutating func recordCareer(_ path: PilotCareerPath) -> Int {
        if adventures == nil { adventures = FlightAdventureProgress() }
        let reward = adventures!.record(path); earn(lowFlightPoints:reward*4); return reward
    }
    mutating func discoverOre(_ material: TradeMineral) {
        if adventures == nil { adventures = FlightAdventureProgress() }
        if adventures!.scanned.insert(material.id).inserted { _ = recordCareer(.explorer) }
    }
    @discardableResult
    mutating func saveRoute(_ route: SavedFlightRoute) -> Bool {
        guard route.valid, adventureProgress.routes.count < 8 else { return false }
        if adventures == nil { adventures = FlightAdventureProgress() }
        adventures!.routes.append(route); return true
    }
    mutating func removeRoute(_ id: UUID) { adventures?.routes.removeAll { $0.id == id } }
    @discardableResult
    mutating func saveBestLap(_ ghost: LapGhost) -> Bool {
        if adventures == nil { adventures = FlightAdventureProgress() }
        return adventures!.saveLap(ghost)
    }
    @discardableResult
    mutating func claimEmergency(_ contract: EmergencyFlightContract) -> Int {
        guard contract.completed, !adventureProgress.missionReceipts.contains(contract.id) else { return 0 }
        if adventures == nil { adventures = FlightAdventureProgress() }
        adventures!.missionReceipts.insert(contract.id)
        let bonus = recordCareer(.courier)
        earn(lowFlightPoints:contract.kind.reward*4); return contract.kind.reward+bonus
    }
}

extension FlightEconomy {
    var campaignProgress: StoryCampaignProgress { story ?? StoryCampaignProgress() }
    var validStoryRewards: Bool { (previousStoryRewards ?? []).isSubset(of:Set(StoryChapter.allCases.map(\.id))) }
    func storyRewardAvailable(for chapter:StoryChapter) -> Bool { !(previousStoryRewards ?? []).contains(chapter.id) }
    mutating func restartStory() {
        previousStoryRewards = (previousStoryRewards ?? []).union(campaignProgress.completed)
        story = StoryCampaignProgress()
    }
    mutating func beginStory() {
        if story == nil { story = StoryCampaignProgress() }
        story?.begin()
    }
    @discardableResult
    mutating func recordStory(_ event:StoryEvent) -> StoryChapter? {
        guard let chapter = story?.record(event) else { return nil }
        if storyRewardAvailable(for:chapter) { earn(lowFlightPoints:chapter.reward*4) }
        return chapter
    }
    mutating func chooseStoryApproach(_ choice:StoryApproach) {
        if story == nil { story = StoryCampaignProgress() }; story?.selectApproach(choice)
    }
    mutating func chooseStoryRelay(_ choice:StoryRelayChoice) { story?.selectRelay(choice) }
    mutating func chooseStoryEnding(_ ending:StoryEnding) { story?.choose(ending) }
}

extension FlightEconomy {
    mutating func recordUniverseVisit(_ galaxy:Galaxy,star:Int?) {
        if adventures == nil { adventures = FlightAdventureProgress() }
        if adventures?.visitedGalaxies == nil { adventures?.visitedGalaxies = [] }
        adventures?.visitedGalaxies?.insert(galaxy.rawValue)
        if let star,(1...120500).contains(star),(adventures?.visitedStars?.count ?? 0)<128 {
            if adventures?.visitedStars == nil { adventures?.visitedStars = [] }
            adventures?.visitedStars?.insert(star)
        }
    }
}
