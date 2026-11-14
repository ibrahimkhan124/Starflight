import SwiftUI
import simd

struct FlightAdventuresView: View {
    @ObservedObject var engine: GameEngine
    private enum ToolSection: String, CaseIterable { case missions, routes, careers, minerals, conditions }
    @State private var section = ToolSection.missions
    @State private var showRouteEditor = false
    @FocusState private var routeNameFocused: Bool
    @State private var name = ""
    @State private var stop = SpacePlanet.tatooine
    @State private var draft: [SpacePlanet] = []
    private var progress: FlightAdventureProgress { engine.economy.adventureProgress }
    var body: some View {
        VStack(spacing:0) {
            Picker("Tool section",selection:$section) {
                ForEach(ToolSection.allCases,id:\.self) { Text($0.rawValue.capitalized).tag($0) }
            }.pickerStyle(.segmented).padding(.horizontal).padding(.vertical,8).accessibilityIdentifier("Adventure sections")
            Text(engine.adventureMessage).font(.caption).foregroundStyle(FlightPalette.cyan).lineLimit(2)
                .frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal).padding(.bottom,6).accessibilityIdentifier("Adventure status")
        Form {
            if section == .missions {
            Section("Mission control") {
                if let mission = engine.activeEmergency {
                    Text(mission.kind.title).font(.headline)
                    Text("\(Int(ceil(mission.remaining))) s · \(HUDSnapshot.distanceLabel(simd_distance(engine.state.position,mission.target))) to platform")
                    Text("Slow within 1.1 km. Approach below 450 m along a clear path, then use Dock. Hold still for three seconds to finish.").font(.caption)
                    Button("Cancel emergency contract") { engine.cancelEmergency() }.flightButtonGlass()
                } else {
                    if engine.distressAvailable {
                        Button("Accept distress diversion · 90 credits") { engine.startEmergency(.rescue) }.flightButtonGlass()
                    }
                    ForEach(EmergencyContractKind.allCases.filter { $0 != .rescue }) { kind in
                        VStack(alignment:.leading,spacing:8) {
                            Text(kind.title).font(.headline)
                            Text(kind.briefing).font(.caption).foregroundStyle(FlightPalette.secondary)
                            Text("\(kind.reward) credits · requires \(kind.requiredCompletions) courier activities").font(.caption).foregroundStyle(FlightPalette.gold)
                            Button("Accept " + kind.title) { engine.startEmergency(kind) }.flightButtonGlass()
                                .disabled(!engine.canStartEmergency || progress.career["courier",default:0] < kind.requiredCompletions)
                                .accessibilityIdentifier("Accept emergency " + kind.rawValue)
                        }.padding(.vertical,6)
                    }
                    Text("Optional challenges in free roam. A fault is simulated only after you accept. Cancelling or timing out restores normal engines; no credits are charged.").font(.caption)
                }
            }
            }
            if section == .routes {
            Section("Navigation & assistance") {
                if let summary = engine.routeSummary {
                    Text(summary).foregroundStyle(FlightPalette.teal)
                    Button("Stop following route") { engine.cancelFlightRoute() }.flightButtonGlass()
                }
                Text("Visit each planet's surface in order. Return to orbit between stops; route guidance advances when you arrive. Route following guides the droid, and never teleports the ship.").font(.caption)
                ForEach(DroidAssistMode.allCases) { mode in
                    Button(mode.title) { engine.setDroidAssist(mode) }.flightButtonGlass()
                        .accessibilityIdentifier("Navigation assist " + mode.rawValue)
                        .disabled(engine.phase == .title || engine.aircraft.isPodracer || engine.arenaSelected)
                }
                NavigationLink("Space map") { SpaceMapView(engine:engine) }.disabled(!engine.isRelaxedSpace)
                Button("Create saved route") { showRouteEditor.toggle() }.flightButtonGlass().accessibilityIdentifier("Create saved route")
                if showRouteEditor {
                    TextField("Route name",text:$name).focused($routeNameFocused).submitLabel(.done)
                        .onSubmit { routeNameFocused = false }.accessibilityIdentifier("Saved route name")
                    Picker("Next stop",selection:$stop) { ForEach(SpacePlanet.allCases) { Text($0.name).tag($0) } }
                    Button("Add stop") { routeNameFocused = false; if draft.count < 8 { draft.append(stop) } }.flightButtonGlass().disabled(draft.count >= 8 || draft.last == stop)
                    Text(draft.map(\.name).joined(separator:" → ")).font(.caption)
                    HStack {
                        Button("Clear draft") { draft = [] }.flightButtonGlass()
                        Button("Save route") {
                            routeNameFocused = false
                            if engine.saveFlightRoute(name:name,planets:draft) { draft = []; name = ""; showRouteEditor = false }
                        }.flightButtonGlass()
                            .disabled(draft.isEmpty || progress.routes.count >= 8)
                    }.buttonStyle(.borderless)
                }
                ForEach(progress.routes) { route in
                    VStack(alignment:.leading,spacing:8) {
                        Text(route.name).font(.headline)
                        Text(route.destinations.map(\.name).joined(separator:" → ")).font(.caption)
                        HStack {
                            Button("Follow " + route.name) { engine.followFlightRoute(route) }.flightButtonGlass().disabled(!engine.isRelaxedSpace)
                            Button("Remove",role:.destructive) { engine.removeFlightRoute(route) }.flightButtonGlass()
                        }.buttonStyle(.borderless)
                    }
                }
            }
            }
            if section == .careers {
            Section("Pilot careers") {
                ForEach(PilotCareerPath.allCases) { path in
                    let count = progress.career[path.rawValue,default:0]
                    VStack(alignment:.leading,spacing:8) {
                        HStack { Text(path.title).font(.headline); Spacer(); Text(PilotCareerPath.rank(count)).foregroundStyle(FlightPalette.gold) }
                        Text(path.activity).font(.caption)
                        Text("\(count) activities · promotions at 2, 6 and 12").font(.caption).monospacedDigit()
                        ProgressView(value:Double(min(12,count)),total:12).tint(FlightPalette.teal)
                        Text("One-time promotion rewards: 100 / 250 / 500 credits.").font(.caption).foregroundStyle(FlightPalette.secondary)
                        if path == .courier { Text("Licensed: fuel-leak contracts · Veteran: precision repair contracts").font(.caption).foregroundStyle(FlightPalette.cyan) }
                    }.padding(.vertical,5)
                }
                Text("City contracts are in Flight tools → Coruscant jobs; bounties are in Contacts & bounties.").font(.caption)
            }
            }
            if section == .minerals {
            Section("Mineral discovery log") {
                Text("\(progress.scanned.count) identified · \(engine.economy.trading?.discovered.count ?? 0) mined · \(TradeMineral.all.count) materials")
                    .foregroundStyle(FlightPalette.teal).accessibilityIdentifier("Mineral discovery totals")
                Text("A new ore discovery advances Explorer. Scan before mining; the scanner shows distance at the moment of the scan.").font(.caption)
                ForEach(MineralRarity.allCases,id:\.self) { rarity in
                    DisclosureGroup(rarity.name) {
                        ForEach(TradeMineral.all.filter { $0.rarity == rarity }) { mineral in
                            HStack {
                                Text(mineral.name)
                                Spacer()
                                Text(engine.economy.trading?.discovered.contains(mineral.id) == true ? "MINED" : progress.scanned.contains(mineral.id) ? "SCANNED":"UNDISCOVERED")
                                    .font(.caption2).foregroundStyle(FlightPalette.secondary)
                            }
                        }
                    }.foregroundStyle(FlightPalette.mineral(rarity))
                }
            }
            }
            if section == .conditions {
            Section("Conditions briefing") {
                Picker("Weather",selection:$engine.settings.weather) { ForEach(FlightWeather.allCases) { Text($0.title).tag($0) } }
                Text(engine.settings.weather.briefing).font(.caption).foregroundStyle(FlightPalette.cyan)
                if let conditions = engine.storyConditions { Text("Campaign conditions: " + conditions + ". Your normal setting returns after this story flight.").font(.caption).foregroundStyle(FlightPalette.gold) }
                Text("Weather affects atmospheric and planet-surface flight. Space and race visibility remain clear.").font(.caption)
            }
            Section("Replay & racing") {
                Text("Pause flight → Watch last 15 seconds. Playback ends back at your paused flight or crash report.").font(.caption)
                Text("Flight-path replay: scenery and hazards are frozen. No rewards, fuel use or collisions are calculated during playback.").font(.caption)
                FlightSwitchRow("Best-lap ghost",isOn:$engine.settings.showGhost).tint(FlightPalette.cyan)
                if let best = engine.ghostBestTime { Text(String(format:"Best for this pod and track: %.2f s",best)) }
                Text("Finish a complete valid lap to save its ghost. A faster lap replaces it. The translucent cyan ship has no collision and gives no slipstream.").font(.caption)
            }
            }
        }
        }
        .navigationTitle("Navigation & missions")
        .onDisappear { engine.applySettings() }
    }
}

struct FlightReplayControls: View {
    @ObservedObject var engine: GameEngine
    var body: some View {
        VStack {
            Text("FLIGHT-PATH REPLAY · GAMEPLAY PAUSED").font(.caption.bold()).padding(10).background(.black.opacity(0.8),in:Capsule())
            Spacer()
            HStack(spacing: 10) {
                Text(String(format:"%.0f / %.0fs",engine.replayFraction*engine.replaySeconds,engine.replaySeconds))
                    .font(.caption2.monospacedDigit()).fixedSize()
                Slider(value:Binding(get:{Double(engine.replayFraction)},set:{engine.seekReplay(Float($0))}),in:0...1)
                    .accessibilityLabel("Replay position").accessibilityIdentifier("Replay timeline")
                Button { engine.stopReplay() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel("Close replay").accessibilityIdentifier("Close replay")
            }.padding(.horizontal, 12).frame(maxWidth: 360).background(.black.opacity(0.8), in: Capsule())
        }.padding(24).foregroundStyle(.white)
    }
}

struct EmergencyFlightHUD: View {
    @ObservedObject var engine: GameEngine
    var body: some View {
        if let mission = engine.activeEmergency {
            HStack(spacing:8) {
                Text(mission.kind.title + " · \(Int(ceil(mission.remaining))) s").font(.caption.bold()).accessibilityIdentifier("Emergency contract HUD")
                if engine.emergencyCanDock { Button("Dock for repair") { engine.dockEmergency() }.flightButtonGlass().accessibilityLabel("Dock for emergency repair").accessibilityIdentifier("Dock for emergency repair") }
            }.padding(10).background(.black.opacity(0.85),in:Capsule()).foregroundStyle(FlightPalette.teal)
        } else if engine.distressAvailable {
            Text("DISTRESS SIGNAL · OPTIONAL RESCUE IN FLIGHT TOOLS").font(.caption.bold()).padding(8).foregroundStyle(FlightPalette.gold)
                .background(.black.opacity(0.8),in:Capsule())
        }
    }
}
