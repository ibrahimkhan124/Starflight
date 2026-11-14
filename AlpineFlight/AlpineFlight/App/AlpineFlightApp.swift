import SwiftUI

@main
struct AlpineFlightApp: App {
    init() { FlightStyle.registerFonts() }

    var body: some Scene {
        WindowGroup { GameView().buttonStyle(GlowingFlightButton()).foregroundStyle(.white).tint(.white).preferredColorScheme(.dark) }
    }
}

/// Widget URLs are local navigation requests, never commands to start or abandon a flight.
enum StarflightShortcut: String, Hashable {
    case hangar, planner, space
    init?(url: URL) {
        guard url.scheme?.lowercased() == "starflight",
              let host = url.host?.lowercased(), url.path.isEmpty || url.path == "/",
              let destination = Self(rawValue: host) else { return nil }
        self = destination
    }
    var title: String {
        switch self { case .hangar: return "the hangar"; case .planner: return "Flight planner"; case .space: return "Space free roam" }
    }
}
