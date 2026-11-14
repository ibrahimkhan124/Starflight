import Foundation

/// Original characters and narrative, using the game's existing places and activities.
enum StoryChapter: Int, CaseIterable, Identifiable, Codable {
    case signal, salvage, whiteout, canopy, shadow, lifeline, dawn
    var id: String { "beacon.\(rawValue)" }
    var number: Int { rawValue+1 }
    var title: String {
        switch self {
        case .signal: return "A Voice in the Traffic"
        case .salvage: return "Ashes and Alloys"
        case .whiteout: return "The White Silence"
        case .canopy: return "Under the Canopy"
        case .shadow: return "The Warden's Courier"
        case .lifeline: return "One Engine, One Chance"
        case .dawn: return "The Last Beacon"
        }
    }
    var location: String {
        switch self {
        case .signal,.shadow: return "Coruscant"
        case .salvage: return "Tatooine and nearby orbit"
        case .whiteout: return "Hoth"
        case .canopy: return "Endor"
        case .lifeline: return "Deep space"
        case .dawn: return "Death Star trench"
        }
    }
    var planet: SpacePlanet? {
        switch self { case .signal,.shadow: return .coruscant; case .whiteout: return .hoth; case .canopy: return .endor; default: return nil }
    }
    var reward: Int { [150,250,300,300,450,350,1000][rawValue] }
    var briefing: String {
        switch self {
        case .signal: return "You came to Coruscant looking for ordinary work. Your droid catches a broken rescue transmission buried in the traffic chatter. Its sender, engineer Mira Senn, is hiding among the arriving passengers. Collect her at the spaceport and take her to the Neon Market before her pursuers notice. Then return to Coruscant orbit so she can explain on a secure channel."
        case .salvage: return "Mira built the Meridian Network: beacons that guide stranded ships home. Someone is silencing them. She needs fresh shielding alloy to rebuild a transmitter, and a contact on Tatooine can refine it. Mine three cargo units in orbit, then sell at least three at Tatooine to deliver the shipment."
        case .whiteout: return "The repaired transmitter points to Hoth. Captain Rhea Voss, once Meridian's rescue pilot, vanished while investigating a frozen relay. Three scout beacons still contain fragments of her flight log. Fly through the snow and recover their signal. Your droid can help hold a route, but cannot see every obstacle."
        case .canopy: return "Voss's log reveals that the disappearances were deliberate. An officer known as the Warden has been capturing rescue traffic. On Endor, two hidden scouts hold the location of his courier. Collect their readings and return to orbit before transmitting the coordinates."
        case .shadow: return "The courier is over Coruscant, using the towers as cover. Mira needs the courier's navigation recorder, not another lost pilot. Take the Neon Runner bounty and disable the marked ship with your guns. Its recorder should reveal where the Warden is taking the missing crews."
        case .lifeline: return "The recorder points to a control station inside the Death Star. As you transmit the discovery, a sabotaged coolant line trips your engine limiter. A maintenance platform is the only safe place to repair it. Reach the platform, dock, and keep the ship steady for three seconds. The mission depends on bringing everyone home."
        case .dawn: return "Mira has one chance to restore the rescue network. Fly the Death Star trench, survive its defenses and reach the final checkpoint before the station's timer runs out. While you draw the guns away, Voss will guide the missing crews out. At the end, the recovered beacon codes will be yours to decide."
        }
    }
    var dialogue: [(speaker:String,text:String)] {
        switch self {
        case .signal: return [("Droid","That signal is asking for help. It keeps repeating your ship's registration."),("Mira Senn","If you are my ride, please keep the engines running.")]
        case .salvage: return [("Mira Senn","It was a rescue network. No weapons, no borders. Just a way home."),("Droid","Then we should repair it. Three fresh cargo units will do.")]
        case .whiteout: return [("Rhea Voss · damaged recording","I followed the missing ships. Someone followed me."),("Droid","Three beacons. Three pieces of the same message.")]
        case .canopy: return [("Mira Senn","Voss is alive. She hid a second route beneath the forest canopy."),("Droid","Two scout readings, then transmit from orbit. Keep the trees outside the cockpit.")]
        case .shadow: return [("The Warden","Rescue signals are useful. They tell me exactly where frightened pilots will go."),("Mira Senn","Take his courier's recorder. We can still turn his trap into a route out.")]
        case .lifeline: return [("Droid","Engine limiter engaged. I can keep the ship stable, but I cannot invent coolant."),("Rhea Voss","Follow the platform lights. We need a pilot, not a hero-shaped crater.")]
        case .dawn: return [("Rhea Voss","I have the crews. You get us a clear signal."),("Mira Senn","Whatever happens in that trench, remember why we started."),("Droid","Route loaded. I would like to complain about it later. Let's survive first.")]
        }
    }
    var objective: String {
        switch self {
        case .signal: return "Complete Spaceport Connection, then return to Coruscant orbit."
        case .salvage: return "Mine 3 new cargo units, then sell 3 at Tatooine."
        case .whiteout: return "Recover the Hoth recordings, then transmit from orbit."
        case .canopy: return "Reach 2 Endor scout beacons, then return to orbit."
        case .shadow: return "Disable the Neon Runner, then escape to Coruscant orbit."
        case .lifeline: return "Complete the engine-trouble repair contract."
        case .dawn: return "Finish the Death Star trench before its timer expires."
        }
    }
    var hint: String {
        switch self {
        case .signal: return "Follow the gold job marker. Dock within 450 m along a clear avenue, wait for boarding, Depart, then Dock at the destination."
        case .salvage: return "Mining is enabled for this chapter. Scan and use MINE or F. If your hold is full, sell first. Approach Tatooine to trade, or enter its surface. The starter market connection is free. Your chosen plan determines the required cargo."
        case .whiteout: return "Follow the navigation marker to each scout. Watch ground clearance in low visibility, then use Flight tools → Return to orbit once all recordings are recovered. Manual steering takes over from droid assistance."
        case .canopy: return "Follow the scout markers. After the required readings, use Flight tools → Return to orbit, or climb above the planet's orbit altitude."
        case .shadow: return "Climb to about 1,000 m, follow the marked courier, and use Fire or F. Stay clear of the towers. Once the recorder is secured, use Flight tools → Return to orbit."
        case .lifeline: return "Follow the cyan platform. Slow inside 1.1 km and use Dock for repair when the path is clear within 450 m. The timer pauses in menus."
        case .dawn: return "Follow every checkpoint through the trench turns. Fire at the defenses and evade incoming shots. Crashing lets you retry this chapter."
        }
    }
    var debrief: String {
        switch self {
        case .signal: return "Mira reaches the workshop safely. She gives you a cracked beacon core and a promise: every ship you help will become another light in the dark."
        case .salvage: return "The shielding shipment reaches the refiner. Mira's transmitter wakes up, and a voice buried in Hoth's snow answers: Captain Voss is still out there."
        case .whiteout: return "The three recordings fit together. Voss survived, but her rescue route was turned into a trap. Her final coordinates lead to Endor."
        case .canopy: return "From orbit, the scout readings resolve into a live courier route. Voss answers your transmission. For the first time, you are no longer searching alone."
        case .shadow: return "The courier's recorder exposes the Warden's control station. Voss locates the missing crews. Mira finds a narrow window to restore the network."
        case .lifeline: return "The repair crew seals the coolant line. Your droid runs the engines twice, just to be certain. Voss sends the final course. There will not be another quiet approach."
        case .dawn: return "The last checkpoint flashes past. Mira's transmission floods the rescue channels, and Voss brings the missing crews into open space. The Warden's trap is broken. Now you hold the beacon codes."
        }
    }
}

enum StoryEnding: String, Codable, CaseIterable, Identifiable {
    case guardian, independent
    var id: String { rawValue }
    var title: String { self == .guardian ? "Keeper of the Lights":"Captain of Your Own Course" }
    var choice: String { self == .guardian ? "Share the codes with the rescue fleet":"Keep an independent rescue route" }
    var epilogue: String {
        self == .guardian
        ? "You give the codes to Mira and Voss. The beacons become a public lifeline, and your callsign travels with every rescued crew. Your droid files your new title under 'well earned': Keeper of the Lights."
        : "You keep your ship outside every chain of command, but leave a channel open for anyone in trouble. Mira smiles: the network has room for a free captain. Your droid names your route Home, then pretends it was a technical label."
    }
}

enum StoryApproach: String, Codable, CaseIterable, Identifiable {
    case rescue, covert
    var id: String { rawValue }
    var title: String { self == .rescue ? "Rescue first" : "Fly under the radar" }
    var detail: String { self == .rescue ? "Rebuild a public signal: 3 alloy units and 3 Hoth recordings through a snow squall." : "Build a shielded signal: 4 alloy units and 2 Hoth recordings through drifting mist." }
}
enum StoryRelayChoice: String, Codable, CaseIterable, Identifiable {
    case broadcast, silent
    var id: String { rawValue }
    var title: String { self == .broadcast ? "Broadcast a rescue call" : "Send an encrypted burst" }
    var detail: String { self == .broadcast ? "Read 2 Endor scouts. Warn stranded crews openly; the Warden will hear the warning too." : "Read 3 Endor scouts to build an encrypted route. Keep Voss's location hidden." }
}

enum StoryEvent {
    case cityJob(CityContract)
    case mined(Int)
    case sold(SpacePlanet,Int)
    case scout(SpacePlanet,Int)
    case orbit(SpacePlanet)
    case bounty(BountyContract)
    case repaired(EmergencyContractKind)
    case route(FlightLevel)
}

struct StoryCampaignProgress: Codable, Equatable {
    private(set) var completed: Set<String> = []
    private(set) var accepted = false
    private(set) var mined = 0
    private(set) var delivered = 0
    private(set) var scouts: Set<Int> = []
    private(set) var ending: StoryEnding?
    private(set) var approach: StoryApproach?
    private(set) var relayChoice: StoryRelayChoice?
    private(set) var milestones: Set<String>?
    var plan: StoryApproach { approach ?? .rescue }
    var relay: StoryRelayChoice { relayChoice ?? .broadcast }
    var cargoRequired: Int { plan == .covert ? 4 : 3 }
    var hothRequired: Int { plan == .covert ? 2 : 3 }
    var endorRequired: Int { relay == .silent ? 3 : 2 }
    var passengerSafe: Bool { milestones?.contains("passenger") == true }
    var recorderSafe: Bool { milestones?.contains("recorder") == true }
    var current: StoryChapter? { StoryChapter(rawValue:completed.count) }
    var lastCompleted: StoryChapter? { completed.isEmpty ? nil:StoryChapter(rawValue:completed.count-1) }
    var finished: Bool { completed.count == StoryChapter.allCases.count }
    var valid: Bool {
        completed == Set(StoryChapter.allCases.prefix(completed.count).map(\.id)) && completed.count <= StoryChapter.allCases.count
            && (0...cargoRequired).contains(mined) && (0...cargoRequired).contains(delivered) && scouts.isSubset(of:Set(0..<6))
            && delivered <= mined && (current == .salvage || (mined == 0 && delivered == 0))
            && (current == .whiteout || current == .canopy || scouts.isEmpty)
            && (milestones ?? []).isSubset(of:current == .signal ? ["passenger"] : current == .shadow ? ["recorder"] : [])
            && (!finished || !accepted) && (ending == nil || finished)
    }
    mutating func selectApproach(_ choice: StoryApproach) { if current == .signal && (!accepted || (approach == nil && !passengerSafe)) { approach = choice } }
    mutating func selectRelay(_ choice: StoryRelayChoice) { if current == .canopy && (!accepted || (relayChoice == nil && scouts.isEmpty)) { relayChoice = choice } }
    mutating func begin() {
        guard current != nil else { return }
        if current == .signal && approach == nil { approach = .rescue }
        if current == .canopy && relayChoice == nil { relayChoice = .broadcast }
        if !accepted { mined = 0; delivered = 0; scouts = [] }
        accepted = true
    }
    /// The next chapter waits for its briefing. Repeated events can never pay it early.
    mutating func record(_ event:StoryEvent) -> StoryChapter? {
        guard accepted,let chapter = current else { return nil }
        var success = false
        switch (chapter,event) {
        case (.signal,.cityJob(.spaceportLink)): milestones = ["passenger"]
        case (.signal,.orbit(.coruscant)): success = passengerSafe
        case (.salvage,.mined(let units)): mined = min(cargoRequired,mined+max(0,min(units,cargoRequired)))
        case (.salvage,.sold(.tatooine,let units)) where mined >= cargoRequired:
            delivered = min(cargoRequired,delivered+max(0,min(units,cargoRequired))); success = delivered >= cargoRequired
        case (.whiteout,.scout(.hoth,let id)) where (0..<6).contains(id): scouts.insert(id)
        case (.whiteout,.orbit(.hoth)): success = scouts.count >= hothRequired
        case (.canopy,.scout(.endor,let id)) where (0..<6).contains(id): scouts.insert(id)
        case (.canopy,.orbit(.endor)): success = scouts.count >= endorRequired
        case (.shadow,.bounty(.runaway)): milestones = ["recorder"]
        case (.shadow,.orbit(.coruscant)): success = recorderSafe
        case (.lifeline,.repaired(.engine)): success = true
        case (.dawn,.route(.deathStar)): success = true
        default: break
        }
        guard success else { return nil }
        completed.insert(chapter.id); accepted = false; mined = 0; delivered = 0; scouts = []; milestones = nil
        return chapter
    }
    mutating func choose(_ ending:StoryEnding) { if finished && self.ending == nil { self.ending = ending } }
    var objectiveProgress: String {
        guard let chapter = current else { return ending?.title ?? "Choose the future of the beacon network." }
        switch chapter {
        case .signal: return passengerSafe ? "Mira is safe · return to Coruscant orbit" : chapter.objective
        case .salvage: return mined < cargoRequired ? "Mine fresh cargo · \(mined)/\(cargoRequired) units":"Deliver to Tatooine · \(delivered)/\(cargoRequired) units sold"
        case .whiteout: return scouts.count < hothRequired ? "Recover Hoth recordings · \(scouts.count)/\(hothRequired) beacons" : "Recordings recovered · return to Hoth orbit"
        case .canopy: return scouts.count < endorRequired ? "Read Endor scouts · \(scouts.count)/\(endorRequired)":"Return to Endor orbit to transmit"
        case .shadow: return recorderSafe ? "Recorder secured · return to Coruscant orbit" : chapter.objective
        default: return chapter.objective
        }
    }
}

extension StoryCampaignProgress {
    func debrief(for chapter:StoryChapter) -> String {
        if chapter == .whiteout { return "The \(hothRequired) recordings fit together in orbit. Voss survived, but her rescue route was turned into a trap. Mira's authorization signature is on the access order. Her final coordinates lead to Endor, where you will have to decide how much to trust the network." }
        if chapter == .canopy { return relay == .silent ? "Your encrypted burst reaches Voss without exposing the families beneath Endor's canopy. The three scouts reveal the courier's live route. Mira stays on the channel, ready to answer for her mistake." : "Your open warning reaches stranded crews across the network. The Warden hears it too. Voss answers: civilian pilots are gathering to help, but the courier now knows you are coming." }
        return chapter.debrief
    }
    func dialogue(for chapter:StoryChapter) -> [(speaker:String,text:String)] {
        switch chapter {
        case .salvage: return [("Mira Senn","It was a rescue network. No weapons, no borders. Just a way home."),("Droid","We need \(cargoRequired) fresh units for this transmitter. I have questions about that authorization signature.")]
        case .whiteout: return [("Rhea Voss · damaged recording","I followed the missing ships. Someone followed me."),("Droid","\(hothRequired) recordings, then orbit. We should hear the whole message before we decide whom to trust.")]
        case .canopy: return [("Mira Senn","I gave him emergency access. I thought he was still rescuing people."),("Rhea Voss",relay == .silent ? "Keep this channel encrypted. We cannot risk those families." : "If you broadcast, make sure they hear the warning before he can rewrite it.")]
        default: return chapter.dialogue
        }
    }
    func objective(for chapter: StoryChapter) -> String {
        if chapter == .salvage { return "Mine \(cargoRequired) new cargo units, then sell \(cargoRequired) at Tatooine." }
        if chapter == .whiteout { return "Recover \(hothRequired) different Hoth recordings, then return to orbit." }
        if chapter == .canopy { return "Read \(endorRequired) Endor scouts, then return to orbit." }
        return chapter.objective
    }
    func briefing(for chapter: StoryChapter) -> String {
        switch chapter {
        case .salvage: return "Mira's Meridian Network was built to bring stranded crews home. Its distress traffic is now being intercepted. Your \(plan == .covert ? "shielded transmitter needs extra alloy to hide its signature" : "public rescue transmitter needs a stronger core"). Mine \(cargoRequired) fresh cargo units, then deliver them by selling at Tatooine. Mira suspects that someone inside the network gave away its access codes."
        case .whiteout: return "Voss left her logs on Hoth after discovering false rescue coordinates. Recover \(hothRequired) separate recordings and return to orbit to assemble them. \(plan == .covert ? "Your shielded link recovers two strong signals through the mist." : "Three weaker signals survive the snow squall; you need all three.") One recording carries Mira's own authorization signature. Was it stolen, or did she help build the trap?"
        case .canopy: return "Mira admits the Warden was once her rescue supervisor. She gave him emergency access before he began capturing crews, and has been trying to undo it ever since. Voss will risk another rescue only if you secure a way out. \(relay == .silent ? "Collect three scouts to send an encrypted burst without exposing her." : "Collect two scouts to broadcast a warning to every stranded ship, even though the Warden will hear it.") Return to orbit to transmit."
        default: return chapter.briefing
        }
    }
    var transmission: String {
        switch current {
        case .signal: return passengerSafe ? "Mira: Thank you. The workshop is watched. Take us above the traffic before I explain." : "Droid: Someone has copied our registration into the distress channel. This was meant for us."
        case .salvage: return mined >= cargoRequired ? "Mira: The alloy is aboard. Deliver it to my Tatooine contact; the old transmitter cannot be trusted." : "Voss · fragment: If Senn sent you, ask her who gave the Warden his codes."
        case .whiteout: return scouts.count >= hothRequired ? "Voss · recovered: Mira signed the access order. Bring this recording into orbit. I need to hear her answer." : "Droid: Separate recordings prevent one forged beacon from rewriting the whole message."
        case .canopy: return relay == .silent ? "Voss: Keep it encrypted. There are still families hiding down here." : "Mira: Warn them all. I will not let another frightened pilot follow my signal into his trap."
        case .shadow: return recorderSafe ? "The Warden: That recorder includes your engineer's signature. Ask her what else she omitted." : "Voss: Disable the courier. Its recorder is evidence; revenge will not bring the crews home."
        case .lifeline: return "Mira: I gave him access. I will live with that. Let me help you put it right."
        case .dawn: return relay == .silent ? "Voss: Our encrypted route is intact. I will guide the hidden crews while you open the station channel." : "Voss: Your warning brought civilian ships to help. Hold the trench while we organize their escape."
        case nil: return "Droid: The network is answering again. What happens next is your choice, Captain."
        }
    }
    var epilogue: String {
        guard let ending else { return "" }
        return ending.epilogue + " " + (plan == .covert ? "Your shielded transmitter becomes a refuge for crews who cannot risk a public signal." : "The rescue fleet keeps your public channel open for the next stranded pilot.") + " " + (relay == .silent ? "Voss's hidden Endor route remains secret." : "Your Endor broadcast is remembered as the warning that brought the scattered crews together.")
    }
    var evidence: [(String,String)] {
        let entries = [("A stolen callsign", "The distress message contained your ship's registration before you arrived."), ("A trusted signature", "The transmitter log contains Mira's authorization, not an anonymous intrusion."), ("Voss's testimony", "Mira granted emergency access before the Warden began taking crews."), ("The Endor decision", relay == .silent ? "You hid the evacuation route with an encrypted burst." : "You warned the stranded crews on an open channel."), ("The courier recorder", "The missing crews are alive. The Warden's station controls their rescue traffic."), ("Mira's confession", "She accepts responsibility and will stay on the channel for the final attempt."), ("The restored network", "The codes are recovered. The rescued crews can finally choose their own course.")]
        return Array(entries.prefix(completed.count))
    }
}
