import SwiftUI

enum PlannerTab: String, Identifiable, CaseIterable {
    case aircraft = "Aircraft", droids = "Droids", levels = "Levels"
    var id: String { rawValue }
}

struct FlightPlannerView: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var tab: PlannerTab
    @ScaledMetric(relativeTo: .headline) private var titleHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var summaryHeight: CGFloat = 76

    init(engine: GameEngine, initialTab: PlannerTab) {
        self.engine = engine
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Flight planner", selection: $tab) {
                        ForEach(PlannerTab.allCases) { Text($0.rawValue).flightButtonGlow().font(FlightStyle.displayFont(11)).textCase(.lowercase).tag($0) }
                    }.pickerStyle(.segmented)
                        .padding(6)
                        .flightGlass(in: RoundedRectangle(cornerRadius: 50))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tab == .aircraft ? "Find your wings." : tab == .droids ? "Choose your copilot." : "Pick your next run.").flightButtonGlow()
                            .font(FlightStyle.displayFont(25)).textCase(.lowercase).lineLimit(2).minimumScaleFactor(0.7)
                        Text(tab == .aircraft ? "\(AircraftType.allCases.filter { engine.economy.unlocked($0) }.count) available craft. Collect blueprints in the Shop to reveal \(AircraftType.blueprintFleet.count) more ships." : tab == .droids ? "\(DroidType.allCases.count) copilots. Select a droid for its cockpit feed and voice controls." : "\(FlightLevel.allCases.count) destinations. Choose a story flight, race circuit, or free roam.").flightButtonGlow()
                            .font(.subheadline).foregroundStyle(.white).textCase(nil)
                        Text("\(itemCount) available · Tap a card to select")
                            .font(.caption).textCase(nil).accessibilityIdentifier("Planner results")
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                        if tab == .aircraft {
                            ForEach(availableAircraft) { type in aircraftCard(type) }
                        } else if tab == .droids {
                            ForEach(DroidType.allCases) { type in droidCard(type) }
                        } else {
                            ForEach(FlightLevel.allCases) { level in levelCard(level) }
                        }
                    }
                }.padding()
            }
            .background { PlannerBackdrop() }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(engine.aircraftName) · \(engine.settings.droid.name)", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                    Text(engine.levelName).font(.caption)
                    Text("Done returns to the hangar. Take flight starts your selected route.").font(.caption)
                }.textCase(nil).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                    .background(FlightStyle.ink.opacity(0.96))
                    .accessibilityIdentifier("Planner selection summary")
            }
            .navigationTitle("Flight planner")
#if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.padding(.horizontal, 12).frame(minHeight: 36).flightButtonGlass().accessibilityIdentifier("Planner done") } }
        }
        .tint(.white).foregroundStyle(.white)
        .font(FlightStyle.displayFont(12)).textCase(.lowercase).preferredColorScheme(.dark)
    }

    private var availableAircraft: [AircraftType] {
        AircraftType.allCases.filter { engine.economy.unlocked($0) }
    }
    private var itemCount: Int {
        switch tab {
        case .aircraft: return availableAircraft.count
        case .droids: return DroidType.allCases.count
        case .levels: return FlightLevel.allCases.count
        }
    }

    private func droidCard(_ type: DroidType) -> some View {
        let selected = engine.settings.droid == type
        return Button { engine.selectDroid(type) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(type.role).flightButtonGlow().font(FlightStyle.displayFont(8)).textCase(.lowercase).tracking(1)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").flightButtonGlow()
                }.foregroundStyle(.white).frame(height: 22)
                Text(type.name).flightButtonGlow().font(FlightStyle.displayFont(22)).textCase(.lowercase).lineLimit(2).minimumScaleFactor(0.7).frame(height: titleHeight, alignment: .topLeading)
                Text(type.summary).flightButtonGlow().font(.system(size: 12)).foregroundStyle(.white).lineLimit(5).frame(height: summaryHeight, alignment: .topLeading)
                Divider().overlay(.white.opacity(0.12))
                HStack {
                    Text("COPILOT")
                    Spacer()
                    Text("OPTIC + VOICE")
                }.font(.system(size: 10, weight: .medium, design: .monospaced)).frame(height: 24)
                Text(selected ? "SELECTED DROID" : "SELECT DROID").flightButtonGlow()
                    .font(FlightStyle.displayFont(8)).textCase(.lowercase).tracking(1.3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(FlightStyle.mint.opacity(selected ? 0.18 : 0.06), in: Capsule())
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16)

        }.buttonStyle(PlannerCardButtonStyle(selected: selected))
            .accessibilityLabel("Select \(type.name)")
            .accessibilityValue(selected ? "Selected" : type.role)
            .accessibilityIdentifier("droid-\(type.rawValue)")
    }

    private func aircraftCard(_ type: AircraftType) -> some View {
        let selected = engine.aircraft == type && engine.customShip == nil
        return Button { engine.selectAircraft(type) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(type.category).flightButtonGlow().font(FlightStyle.displayFont(8)).textCase(.lowercase).tracking(1)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").flightButtonGlow()
                }.foregroundStyle(.white).frame(height: 22)
                Text(type.name).flightButtonGlow().font(FlightStyle.displayFont(21)).textCase(.lowercase).lineLimit(2).minimumScaleFactor(0.7).frame(height: titleHeight, alignment: .topLeading)
                Text(type.summary).flightButtonGlow().font(.system(size: 12)).foregroundStyle(.white)
                    .lineLimit(5).frame(height: summaryHeight, alignment: .topLeading)
                Divider().overlay(.white.opacity(0.12))
                HStack {
                    Label("\(Int(type.cruiseSpeed * 1.94384)) KT", systemImage: "speedometer").flightButtonGlow()
                    Spacer()
                    Text(type.handling).flightButtonGlow()
                }.font(.system(size: 10, weight: .medium, design: .monospaced)).frame(height: 24)
                Text(selected ? "SELECTED AIRCRAFT" : "SELECT AIRCRAFT").flightButtonGlow()
                    .font(FlightStyle.displayFont(8)).textCase(.lowercase).tracking(1.3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(FlightStyle.mint.opacity(selected ? 0.18 : 0.06), in: Capsule())
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16)

        }
        .buttonStyle(PlannerCardButtonStyle(selected: selected))
        .accessibilityLabel("Select \(type.name)")
        .accessibilityValue(selected ? "Selected" : type.category)
        .accessibilityIdentifier("aircraft-\(type.rawValue)")
    }

    private func levelCard(_ level: FlightLevel) -> some View {
        let selected = engine.level == level && engine.customLevel == nil
        let best = engine.best(for: level)
        return Button { engine.selectLevel(level) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(level.isFreeRoam ? "∞" : String(format: "%02d", level.number)) / \(level.challenge)").flightButtonGlow()
                        .font(FlightStyle.displayFont(8)).textCase(.lowercase).tracking(1)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").flightButtonGlow()
                }.foregroundStyle(.white).frame(height: 22)
                Text(level.name).flightButtonGlow().font(FlightStyle.displayFont(19)).textCase(.lowercase).lineLimit(2).minimumScaleFactor(0.7)
                    .frame(height: titleHeight, alignment: .topLeading)
                Text(level.subtitle).flightButtonGlow().font(.system(size: 12)).foregroundStyle(.white)
                    .lineLimit(5).frame(height: summaryHeight, alignment: .topLeading)
                Divider().overlay(.white.opacity(0.12))
                HStack {
                    Text(level.isFreeRoam ? "UNLIMITED" : String(format: "%.1f KM", level.routeLength / 1000)).flightButtonGlow()
                    Spacer()
                    Text(level.isFreeRoam ? "NO GATES" : level.isPodRaceTrack ? "3 LAPS" : "\(level.gateCount) GATES").flightButtonGlow()
                    Spacer()
                    Text(level.isFreeRoam ? "EXPLORE" : best == level.totalCheckpoints ? "COMPLETE ✓" : "BEST \(best)/\(level.totalCheckpoints)").flightButtonGlow()
                }.font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.white).frame(height: 24)
                Text(selected ? "SELECTED LEVEL" : "SELECT LEVEL").flightButtonGlow()
                    .font(FlightStyle.displayFont(8)).textCase(.lowercase).tracking(1.3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(FlightStyle.mint.opacity(selected ? 0.18 : 0.06), in: Capsule())
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16)

        }.buttonStyle(PlannerCardButtonStyle(selected: selected))
            .accessibilityLabel("Select \(level.name)")
            .accessibilityValue(selected ? "Selected" : level.challenge)
            .accessibilityIdentifier("level-\(level.rawValue)")
    }

}

/// One shaped glass surface per card, with an explicit selected state.
private struct PlannerCardButtonStyle: ButtonStyle {
    let selected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.flightGlowCovered, true)
            .background(reduceTransparency ? FlightStyle.ink : .black.opacity(0.45), in: RoundedRectangle(cornerRadius: 50))
            .flightButtonGlass(in: RoundedRectangle(cornerRadius: 50))
            .overlay {
                RoundedRectangle(cornerRadius: 50)
                    .strokeBorder(selected ? .white.opacity(0.9) : .white.opacity(0.18), lineWidth: selected ? 2.5 : 1)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 50))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

/// Static light and colour behind clear glass; no animated blur during scrolling.
private struct PlannerBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.156, green: 0.146, blue: 0.248), FlightStyle.ink], startPoint: .topLeading, endPoint: .topTrailing)
            RadialGradient(colors: [.cyan.opacity(0.16), .clear], center: .bottomTrailing, startRadius: 20, endRadius: 600)
            RadialGradient(colors: [.indigo.opacity(0.22), .clear], center: .bottomLeading, startRadius: 20, endRadius: 500)
        }.ignoresSafeArea().allowsHitTesting(false)
    }
}
