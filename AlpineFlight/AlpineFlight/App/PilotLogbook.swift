import Foundation

enum PilotFlightOutcome: String, Codable { case returned, completed, crashed, interrupted }

struct PilotFlightRecord: Codable, Equatable, Identifiable {
    var id = UUID()
    var startedAt: Date
    var endedAt: Date
    var aircraft: String
    var route: String
    var outcome: PilotFlightOutcome = .interrupted
    var seconds: Double = 0
    var metres: Double = 0
    var stallSeconds: Double = 0
    var closeShaves = 0
    var controlledTurns = 0
    var soaringClimbs = 0
    var visitedPlanets: Set<String> = []
    var hothRoundTrip = false
    var ranked: Bool {
        outcome != .interrupted && (outcome == .crashed || (seconds >= 60 && metres >= 1000) || (outcome == .completed && seconds >= 15))
    }
    var score: Double {
        let control = 25 * max(0,1-stallSeconds/max(seconds,1)*5)
        let skill = min(20,Double(controlledTurns)*2+Double(soaringClimbs)*3+Double(min(closeShaves,2)))
        return min(100,max(0,(outcome == .crashed ? 0:55)+control+skill))
    }
}

enum PilotRank: String, Codable {
    case cadet = "Cadet", wingPilot = "Wing pilot", flightOfficer = "Flight officer", squadronLeader = "Squadron leader", ace = "Ace", legend = "Flight legend"
    static func at(score: Double) -> Self {
        switch score { case ..<40:return .cadet; case ..<60:return .wingPilot; case ..<75:return .flightOfficer; case ..<90:return .squadronLeader; case ..<97:return .ace; default:return .legend }
    }
}

struct PilotRankReview: Codable, Equatable, Identifiable {
    var id = UUID()
    let date: Date
    let flightNumber: Int
    let score: Double
    let crashes: Int
    let closeShaves: Int
    let turns: Int
    let soars: Int
    var rank: PilotRank { .at(score:score) }
}

enum PilotAchievement: String, CaseIterable, Codable, Identifiable {
    case km20, km100, km1000, km10000, km20000, flights10, flights30, flights100, closeShaves10, turns50, soars25, hothReturn, worlds4, safe10
    var id:String { rawValue }
    var title:String {
        switch self {
        case .km20:return "First 20 kilometres"; case .km100:return "Century flyer"; case .km1000:return "Thousand-kilometre explorer"
        case .km10000:return "Ten-thousand-kilometre voyager"; case .km20000:return "20,000-kilometre legend"
        case .flights10:return "Taking flight"; case .flights30:return "First pilot review"; case .flights100:return "Flight veteran"
        case .closeShaves10:return "Close-shave specialist"; case .turns50:return "Master of the turn"; case .soars25:return "Above the clouds"
        case .hothReturn:return "Northern Hoth expedition"; case .worlds4:return "Four-world explorer"; case .safe10:return "Safe hands"
        }
    }
    var detail:String {
        switch self {
        case .km20,.km100,.km1000,.km10000,.km20000:return "Fly \(Int(target).formatted()) kilometres in total. Hyperspace and travel jumps do not count."
        case .flights10,.flights30,.flights100:return "Finish \(Int(target)) review-eligible flights."
        case .closeShaves10:return "Recover safely from 10 close shaves: skim 8–25 m above ground, then climb clear."
        case .turns50:return "Complete 50 controlled turns of at least 90°, levelling your wings between turns."
        case .soars25:return "Complete 25 soaring climbs: climb at least 100 m over 10 steady seconds, without stalling."
        case .hothReturn:return "On Hoth's planet surface, fly 14.4 km north from arrival, then return within 800 m of arrival without leaving the surface."
        case .worlds4:return "Explore the surfaces of Tatooine, Hoth, Endor and Coruscant."
        case .safe10:return "Finish 10 consecutive review-eligible flights without crashing."
        }
    }
    var target:Double {
        switch self { case .km20:return 20; case .km100:return 100; case .km1000:return 1000; case .km10000:return 10000; case .km20000:return 20000; case .flights10,.closeShaves10,.safe10:return 10; case .flights30:return 30; case .flights100:return 100; case .turns50:return 50; case .soars25:return 25; case .worlds4:return 4; case .hothReturn:return 1 }
    }
}

struct PilotLogbook: Codable, Equatable {
    var flights: [PilotFlightRecord] = []
    var reviews: [PilotRankReview] = []
    var awards: [String:Date] = [:]
    var rankedFlights:[PilotFlightRecord] { flights.filter(\.ranked) }
    var latestReview:PilotRankReview? { reviews.last }
    func progress(_ achievement:PilotAchievement,draft:PilotFlightRecord? = nil) -> Double {
        let records = flights+(draft.map { [$0] } ?? [])
        switch achievement {
        case .km20,.km100,.km1000,.km10000,.km20000:return records.reduce(0) { $0+$1.metres }/1000
        case .flights10,.flights30,.flights100:return Double(rankedFlights.count)
        case .closeShaves10:return Double(records.reduce(0) { $0+$1.closeShaves })
        case .turns50:return Double(records.reduce(0) { $0+$1.controlledTurns })
        case .soars25:return Double(records.reduce(0) { $0+$1.soaringClimbs })
        case .worlds4:return Double(records.reduce(into:Set<String>()) { $0.formUnion($1.visitedPlanets) }.count)
        case .hothReturn:return records.contains(where:\.hothRoundTrip) ? 1:0
        case .safe10:return Double(rankedFlights.reversed().prefix(while:{ $0.outcome != .crashed }).count)
        }
    }
    @discardableResult mutating func unlock(draft:PilotFlightRecord? = nil,at date:Date) -> [PilotAchievement] {
        let earned = PilotAchievement.allCases.filter { awards[$0.rawValue] == nil && progress($0,draft:draft) >= $0.target }
        for achievement in earned { awards[achievement.rawValue] = date }
        return earned
    }
    /// A flight ID may be committed only once, even after recovery or repeated menu actions.
    @discardableResult mutating func append(_ flight:PilotFlightRecord) -> Bool {
        guard !flights.contains(where:{ $0.id == flight.id }) else { return false }
        flights.append(flight)
        if flight.ranked {
            let eligible = rankedFlights
            if eligible.count.isMultiple(of:30) {
                let batch = eligible.suffix(30)
                reviews.append(PilotRankReview(date:flight.endedAt,flightNumber:eligible.count,score:batch.reduce(0) { $0+$1.score }/30,
                    crashes:batch.filter { $0.outcome == .crashed }.count,closeShaves:batch.reduce(0) { $0+$1.closeShaves },
                    turns:batch.reduce(0) { $0+$1.controlledTurns },soars:batch.reduce(0) { $0+$1.soaringClimbs }))
            }
        }
        return true
    }
}

/// Drafts are small and separate from history; checkpointing never rewrites years of records.
@MainActor
struct PilotLogbookStore {
    static let processSession = UUID()
    static let key = "starflight.pilot-logbook.v1"
    static let draftKey = "starflight.pilot-drafts.v1"
    struct Draft: Codable { let session:UUID; let flight:PilotFlightRecord }
    let defaults:UserDefaults
    var session:UUID = Self.processSession
    func load() -> PilotLogbook {
        guard let data = defaults.data(forKey:Self.key), let value = try? JSONDecoder().decode(PilotLogbook.self,from:data) else { return PilotLogbook() }
        return value
    }
    func save(_ book:PilotLogbook) { if let data = try? JSONEncoder().encode(book) { defaults.set(data,forKey:Self.key) } }
    private func drafts() -> [String:Draft] {
        guard let data = defaults.data(forKey:Self.draftKey) else { return [:] }
        return (try? JSONDecoder().decode([String:Draft].self,from:data)) ?? [:]
    }
    private func saveDrafts(_ drafts:[String:Draft]) { if let data = try? JSONEncoder().encode(drafts) { defaults.set(data,forKey:Self.draftKey) } }
    func checkpoint(_ flight:PilotFlightRecord) {
        var current = drafts(); current[flight.id.uuidString] = Draft(session:session,flight:flight); saveDrafts(current)
    }
    func clearDraft(_ id:UUID) { var current = drafts(); current.removeValue(forKey:id.uuidString); saveDrafts(current) }
    func recover(at date:Date = Date()) -> PilotLogbook {
        var book = load(), current = drafts()
        for (id,draft) in current where draft.session != session {
            var flight = draft.flight; flight.outcome = .interrupted
            // Use the last observed date, not time spent away from the game.
            if flight.seconds > 0 { book.append(flight) }
            current.removeValue(forKey:id)
        }
        _ = book.unlock(at:date); save(book); saveDrafts(current)
        return book
    }
}

enum PilotChartPeriod: String, CaseIterable, Identifiable {
    case days30 = "Last 30 days", month = "Calendar month", year = "Calendar year"
    var id:String { rawValue }
    func interval(ending anchor:Date,calendar:Calendar) -> DateInterval {
        if self == .month { return calendar.dateInterval(of:.month,for:anchor)! }
        if self == .year { return calendar.dateInterval(of:.year,for:anchor)! }
        let end = calendar.date(byAdding:.day,value:1,to:calendar.startOfDay(for:anchor))!
        return DateInterval(start:calendar.date(byAdding:.day,value:-30,to:end)!,end:end)
    }
}

struct PilotPerformancePoint: Identifiable {
    let date:Date
    let score:Double
    let flights:Int
    var id:Date { date }
}

extension PilotLogbook {
    func chartFlights(period:PilotChartPeriod,ending date:Date,calendar:Calendar = .current) -> [PilotFlightRecord] {
        let range = period.interval(ending:date,calendar:calendar)
        return rankedFlights.filter { $0.endedAt >= range.start && $0.endedAt < range.end }.sorted { $0.endedAt < $1.endedAt }
    }
    func chartReviews(period:PilotChartPeriod,ending date:Date,calendar:Calendar = .current) -> [PilotRankReview] {
        let range = period.interval(ending:date,calendar:calendar)
        return reviews.filter { $0.date >= range.start && $0.date < range.end }.sorted { $0.date < $1.date }
    }
    func performance(period:PilotChartPeriod,ending date:Date,calendar:Calendar = .current) -> [PilotPerformancePoint] {
        let groups = Dictionary(grouping:chartFlights(period:period,ending:date,calendar:calendar)) {
            period == .year ? calendar.dateInterval(of:.month,for:$0.endedAt)!.start : calendar.startOfDay(for:$0.endedAt)
        }
        return groups.map { PilotPerformancePoint(date:$0.key,score:$0.value.reduce(0) { $0+$1.score }/Double($0.value.count),flights:$0.value.count) }.sorted { $0.date < $1.date }
    }
}
