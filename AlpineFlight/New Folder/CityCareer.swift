import Foundation
import simd

enum CityContract: String, CaseIterable, Identifiable, Codable, Sendable {
    case shuttleShift, spaceportLink, senateCircuit
    case courierRun, fragileTechnology, medicalSupplies
    case emergencyTransfer, clinicEvacuation, senateRescue
    case districtPatrol, trafficSurvey, deepScan
    case republicRelief, republicEvacuation, imperialDispatch, imperialSurvey

    var faction: CityFaction? {
        switch self { case .republicRelief,.republicEvacuation: return .republic; case .imperialDispatch,.imperialSurvey: return .empire; default: return nil }
    }

    var id: String { rawValue }
    var kind: CityJobKind {
        switch self {
        case .shuttleShift, .spaceportLink, .senateCircuit: return .shuttle
        case .courierRun, .fragileTechnology, .medicalSupplies, .republicRelief, .imperialDispatch: return .courier
        case .emergencyTransfer, .clinicEvacuation, .senateRescue, .republicEvacuation: return .rescue
        case .districtPatrol, .trafficSurvey, .deepScan, .imperialSurvey: return .patrol
        }
    }
    static func standard(for kind: CityJobKind) -> CityContract {
        switch kind {
        case .shuttle: return .shuttleShift
        case .courier: return .courierRun
        case .rescue: return .emergencyTransfer
        case .patrol: return .districtPatrol
        }
    }
    var title: String {
        switch self {
        case .republicRelief: return "Republic Relief Convoy"
        case .republicEvacuation: return "Republic Civilian Evacuation"
        case .imperialDispatch: return "Imperial Classified Dispatch"
        case .imperialSurvey: return "Imperial Surveillance Sweep"
        case .shuttleShift: return "City Shuttle Shift"
        case .spaceportLink: return "Spaceport Connection"
        case .senateCircuit: return "Senate Staff Shuttle"
        case .courierRun: return "Express Courier"
        case .fragileTechnology: return "Fragile Technology"
        case .medicalSupplies: return "Medical Supply Run"
        case .emergencyTransfer: return "Emergency Transfer"
        case .clinicEvacuation: return "Clinic Evacuation"
        case .senateRescue: return "Senate Medical Response"
        case .districtPatrol: return "District Patrol"
        case .trafficSurvey: return "Sky Lane Survey"
        case .deepScan: return "Deep Sensor Sweep"
        }
    }
    var brief: String {
        switch self {
        case .republicRelief: return "Deliver aid to the Medical Centre and Neon Market. Keep the supplies intact to support the Republic."
        case .republicEvacuation: return "Evacuate civilians from the Industrial Quarter to the Medical Centre for the Republic."
        case .imperialDispatch: return "Carry encrypted Imperial dispatches from the Senate to the Industrial Quarter. Avoid rough handling."
        case .imperialSurvey: return "Perform eight-second Imperial sensor sweeps over the Spaceport, Senate and Industrial Quarter."
        case .shuttleShift: return "Three pickup and drop-off pairs. Keep your passengers comfortable between the towers."
        case .spaceportLink: return "Pick up an arriving traveller at the Spaceport and take them to the Neon Market. A short first shift."
        case .senateCircuit: return "Carry two groups of Senate staff. Gentle turns earn a better passenger rating."
        case .courierRun: return "Three deliveries across the city. All packages are loaded when you accept."
        case .fragileTechnology: return "Deliver delicate navigation processors. Hard banking and sudden acceleration can damage the cargo."
        case .medicalSupplies: return "Deliver preloaded medical supplies to the Medical Centre and Neon Market. Protect the cargo and beat the deadline."
        case .emergencyTransfer: return "Collect a patient in the Industrial Quarter and deliver them to the Medical Centre."
        case .clinicEvacuation: return "Evacuate two patients, one at a time. Return to the Medical Centre after each pickup."
        case .senateRescue: return "Reach the Senate, collect the patient and fly a steady transfer to the Medical Centre."
        case .districtPatrol: return "Visit four districts and stop to scan. This is a survey assignment, with no enemy wave."
        case .trafficSurvey: return "Check the Spaceport, Market and Medical Centre sky lanes. Each survey takes five seconds while docked."
        case .deepScan: return "Complete four detailed sensor sweeps. Hold position for eight seconds at each district."
        }
    }
    var stops: [CityStation] {
        switch self {
        case .republicRelief: return [.medical,.market]
        case .republicEvacuation: return [.industrial,.medical]
        case .imperialDispatch: return [.senate,.industrial]
        case .imperialSurvey: return [.spaceport,.senate,.industrial]
        case .shuttleShift, .courierRun, .emergencyTransfer, .districtPatrol: return kind.stops
        case .spaceportLink: return [.spaceport,.market]
        case .senateCircuit: return [.senate,.spaceport,.market,.senate]
        case .fragileTechnology: return [.industrial,.senate,.spaceport]
        case .medicalSupplies: return [.medical,.market]
        case .clinicEvacuation: return [.industrial,.medical,.market,.medical]
        case .senateRescue: return [.senate,.medical]
        case .trafficSurvey: return [.spaceport,.market,.medical]
        case .deepScan: return [.senate,.industrial,.medical,.spaceport]
        }
    }
    var requiredJobs: Int {
        switch self { case .senateCircuit, .clinicEvacuation, .deepScan: return 3; case .senateRescue: return 8; default: return 0 }
    }
    var baseCredits: Int {
        switch self {
        case .republicRelief: return 230
        case .republicEvacuation: return 270
        case .imperialDispatch: return 150
        case .imperialSurvey: return 140
        case .shuttleShift, .courierRun, .emergencyTransfer, .districtPatrol: return kind.rewardCredits
        case .spaceportLink: return 255
        case .senateCircuit: return 315
        case .fragileTechnology: return 525
        case .medicalSupplies: return 90
        case .clinicEvacuation: return 190
        case .senateRescue: return 170
        case .trafficSurvey: return 75
        case .deepScan: return 120
        }
    }
    var maximumBonus: Int {
        switch self {
        case .republicRelief,.imperialDispatch: return 15
        case .republicEvacuation,.imperialSurvey: return 20
        case .shuttleShift, .courierRun, .emergencyTransfer, .districtPatrol: return 0
        case .spaceportLink, .medicalSupplies, .trafficSurvey: return 10
        case .senateCircuit, .fragileTechnology, .senateRescue, .deepScan: return 20
        case .clinicEvacuation: return 40
        }
    }
    var minimumBonus: Int {
        switch self {
        case .republicRelief,.imperialDispatch: return 10
        case .republicEvacuation,.imperialSurvey: return 5
        case .shuttleShift, .courierRun, .emergencyTransfer, .districtPatrol: return 0
        case .spaceportLink, .medicalSupplies, .trafficSurvey: return 2
        case .senateCircuit, .fragileTechnology, .senateRescue, .deepScan: return 10
        case .clinicEvacuation: return 10
        }
    }
    var timeLimit: Float? {
        switch self {
        case .republicRelief,.imperialDispatch,.republicEvacuation: return 540
        case .imperialSurvey: return nil
        case .courierRun, .emergencyTransfer: return 300
        case .fragileTechnology: return 480
        case .medicalSupplies: return 300
        case .clinicEvacuation: return 600
        case .senateRescue: return 480
        default: return nil
        }
    }
    var serviceSeconds: Float { self == .trafficSurvey ? 5 : (self == .deepScan || self == .imperialSurvey) ? 8 : 3 }
    var conditionLabel: String {
        switch kind { case .shuttle: return "Passenger comfort"; case .courier: return "Cargo integrity"; case .rescue: return "Patient condition"; case .patrol: return "Survey quality" }
    }
    var payloadCount: Int { kind == .shuttle || kind == .rescue ? stops.count / 2 : kind == .courier ? stops.count : 0 }
    var routeDistance: Float { zip(stops,stops.dropFirst()).reduce(0) { $0 + simd_distance($1.0.position,$1.1.position) } }
}

/// Quality only changes during actual flight with a payload, never in menus or while docked.
struct CityRideQuality: Sendable {
    private(set) var condition: Float = 100
    private(set) var flightSeconds: Float = 0
    private(set) var metres: Float = 0
    private var previousVelocity: SIMD3<Float>?

    mutating func observe(state: FlightState, kind: CityJobKind, carrying: Bool, flying: Bool, firing: Bool, dt: Float) {
        guard flying, carrying, dt.isFinite, dt > 0, dt <= 0.25, state.airspeed.isFinite,
              state.pitch.isFinite, state.roll.isFinite,
              state.velocity.x.isFinite, state.velocity.y.isFinite, state.velocity.z.isFinite else {
            previousVelocity = nil; return
        }
        flightSeconds += dt
        metres += max(0,state.airspeed)*dt
        let sensitivity: Float = kind == .rescue ? 1.35 : kind == .courier ? 1.15 : 1
        let bank = max(0,abs(state.roll)-0.65)*2.2
        let pitch = max(0,abs(state.pitch)-0.42)*2
        let acceleration = previousVelocity.map { max(0,simd_length(state.velocity-$0)/dt-85)*0.008 } ?? 0
        let alarm: Float = firing && kind == .shuttle ? 0.35 : 0
        condition = max(0,condition-min(3,(bank+pitch+acceleration+alarm)*sensitivity)*dt)
        previousVelocity = state.velocity
    }
    var stars: Int { condition >= 95 ? 5 : condition >= 85 ? 4 : condition >= 70 ? 3 : condition >= 50 ? 2 : 1 }
}

struct CityJobReport: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let contract: CityContract
    let completedAt: Date
    let seconds: Float
    let kilometres: Float
    let condition: Int
    let stars: Int
    let bonusCredits: Int
    var credits: Int { contract.baseCredits + bonusCredits }
    var summary: String {
        switch contract.kind {
        case .shuttle: return "\(contract.payloadCount) passengers delivered"
        case .courier: return "\(contract.stops.count) deliveries completed"
        case .rescue: return "\(contract.payloadCount) patients transferred"
        case .patrol: return "\(contract.stops.count) districts scanned"
        }
    }
}

struct CityCareer: Codable, Equatable {
    private(set) var recent: [CityJobReport] = []
    private(set) var ratedJobs = 0
    private(set) var conditionTotal = 0
    private(set) var passengers = 0
    private(set) var deliveries = 0
    private(set) var patients = 0
    private(set) var scans = 0
    private(set) var creditsEarned = 0
    var averageCondition: Int? { ratedJobs > 0 ? conditionTotal/ratedJobs : nil }
    mutating func record(_ report: CityJobReport) {
        recent.insert(report,at:0); recent = Array(recent.prefix(20))
        creditsEarned += report.credits
        if report.contract.kind != .patrol { ratedJobs += 1; conditionTotal += report.condition }
        switch report.contract.kind {
        case .shuttle: passengers += report.contract.payloadCount
        case .courier: deliveries += report.contract.stops.count
        case .rescue: patients += report.contract.payloadCount
        case .patrol: scans += report.contract.stops.count
        }
    }
    static let ranks: [(jobs:Int,title:String)] = [(0,"New Recruit"),(3,"Licensed City Pilot"),(8,"Senior City Pilot"),(16,"Elite City Pilot"),(30,"Coruscant Master"),(40,"Junior Senator"),(50,"Senator"),(66,"Vice Empire"),(76,"Empire"),(86,"Vice Space Master"),(96,"Space Master"),(100,"Galaxy master")]
    static func rank(completed: Int) -> String { ranks.last { completed >= $0.jobs }?.title ?? ranks[0].title }
    static func nextRank(completed: Int) -> (jobs:Int,title:String)? { ranks.first { completed < $0.jobs } }
}
