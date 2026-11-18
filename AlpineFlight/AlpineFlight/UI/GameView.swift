import SwiftUI
import RealityKit

struct GameView: View {
    @StateObject private var engine = GameEngine(defaults:AetherReleaseValidation.defaults())
    @Environment(\.scenePhase) private var scenePhase
    @State private var showIntro = true
    @State private var inspectHangar = false
    @State private var showFlightTools = false
    @State private var showTradingConsole = false
    @State private var resumeAfterTrading = false
    @State private var showSpaceMap = false
    @State private var showUniverse = false
    @State private var showSettings = false
    @State private var showWorkshop = false
    @State private var showShop = false
    @State private var showArena = false
    @State private var showStory = false
    @State private var showPilotLogbook = false
    @State private var showCrashMenu = false
    @State private var planner: PlannerTab?
    @State private var pendingShortcut: StarflightShortcut?
    @State private var homeSelection: HomeMenuAction = .flight
    @State private var homeSection: HomeMenuAction = .planner
    @State private var showHomeWorkspace = false

    private var usesOriginalLaunchTitle: Bool {
#if DEBUG
        ProcessInfo.processInfo.environment["STARFLIGHT_INTRO_LAYOUT_TEST"] == "1" || engine.settings.introStyle == .starWars
#else
        engine.settings.introStyle == .starWars
#endif
    }

    private var keepsScreenAwake: Bool { scenePhase == .active && (engine.phase == .flying || engine.interiorHome != nil || AetherReleaseValidation.configuration != nil) }

    private func openPendingShortcut() {
        guard let shortcut = pendingShortcut else { return }
        inspectHangar = false
        showHomeWorkspace = false
        showTradingConsole = false
        showSettings = false; showFlightTools = false; showSpaceMap = false
        showWorkshop = false; showShop = false; showArena = false; showPilotLogbook = false
        planner = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard pendingShortcut == shortcut, engine.phase == .title else { return }
            pendingShortcut = nil
            switch shortcut {
            case .hangar: break
            case .planner: openHomeAction(.planner)
            case .space: openHomeAction(.space)
            }
        }
    }

    private func updateScreenIdleTimer(_ keepAwake: Bool) {
#if os(iOS) && !targetEnvironment(macCatalyst)
        UIApplication.shared.isIdleTimerDisabled = keepAwake
#endif
    }

    private var homeWorkspace: some View {
        HomeWorkspaceView(engine: engine, section: homeSection)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if engine.phase == .title { homeDock }
            }
    }
    private func finishHomeWorkspace() {
        if homeSection == .settings && engine.phase == .title { engine.applySettings() }
        if homeSection == .story { engine.dismissStoryDebrief() }
        if homeSelection == homeSection { homeSelection = .flight }
    }

    private var homeDock: some View {
        HomeNavigationDock(engine: engine, selection: homeSelection, onSelect: openHomeAction)
            .padding(.horizontal, 12).padding(.vertical, 8)
    }
    private func openHomeAction(_ action: HomeMenuAction) {
        guard engine.phase == .title else { return }
        if showHomeWorkspace && homeSection == .settings { engine.applySettings() }
        homeSelection = action
        switch action {
        case .flight:
            guard engine.ready, engine.error == nil else { return }
            showHomeWorkspace = false
            engine.start()
        case .freeRoam:
            engine.selectLevel(.freeRoam); showHomeWorkspace = false
        case .space:
            engine.selectSpaceFreeRoam(); showHomeWorkspace = false
        default:
            homeSection = action
            showHomeWorkspace = true
        }
    }

    var body: some View {
        GeometryReader { viewport in
        ZStack {
            FlightSceneView(engine: engine, isVisible: (engine.phase != .title || engine.settings.hangarPreview == .selectedLevel) && engine.interiorHome == nil).ignoresSafeArea()
                .allowsHitTesting(engine.phase != .title && engine.interiorHome == nil)
            if engine.phase == .title && engine.arrivingPlanetName == nil && !inspectHangar && !showHomeWorkspace && engine.settings.hangarPreview == .hangar {
                HangarSceneView(engine: engine, isActive: !showHomeWorkspace && !showSettings && planner == nil && !showWorkshop && !showShop && !showArena && !showPilotLogbook && !showStory).ignoresSafeArea()
            }
            LinearGradient(colors: [.black.opacity(0.38), .clear, .black.opacity(0.22)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea().allowsHitTesting(false)
            if engine.replayActive {
                FlightReplayControls(engine:engine)
            } else if engine.phase == .flying {
                if engine.cameraMode == .cockpit {
                    CockpitOverlay(hud: engine.hud).ignoresSafeArea().allowsHitTesting(false)
                }
                if engine.arenaSelected {
                    ArenaFlightHUD(engine:engine)
                } else {
                HUDView(engine: engine, onOpenTools: { showFlightTools = true; engine.pause() },onOpenMap:{ engine.pause(); showSpaceMap = true }, onOpenUniverse:{ engine.pause(); showUniverse = true }, onOpenTrade: {
                    resumeAfterTrading = engine.phase == .flying
                    engine.pause(); showTradingConsole = true
                })
                }
#if !os(iOS) || targetEnvironment(macCatalyst)
                if engine.cameraMode == .cockpit {
                    VStack { HStack { Spacer(); DroidVisionView(engine: engine) }; Spacer() }
                        .padding(.top, 72).padding(.trailing, 18)
                }
#endif
            } else if engine.phase == .title {
                if engine.arrivingPlanetName == nil {
                StartScreen(engine: engine)
                }
            } else if engine.arenaSelected && engine.phase == .completed {
                ArenaResultView(engine:engine)
            } else if engine.starInspection != nil {
                EmptyView()
            } else if engine.phase != .crashed || showCrashMenu {
                FlightMenu(engine: engine, showSettings: $showSettings,showPilotLogbook:$showPilotLogbook)
            } else {
                Color.red.opacity(0.1).ignoresSafeArea().allowsHitTesting(false)
            }
            if let error = engine.error {
                VStack(spacing: 12) {
                    Label("Unable to load region", systemImage: "exclamationmark.triangle").flightButtonGlow()
                    Text(error).flightButtonGlow().font(.caption)
                    Text("Close and reopen the app to retry.").flightButtonGlow().font(.caption)
                }.modifier(FlightPanel()).padding()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if engine.phase == .title && !showIntro && engine.arrivingPlanetName == nil && !showHomeWorkspace {
                homeDock
            }
        }
        .overlay {
            if let inspection = engine.starInspection { StarFactCallout(engine: engine, inspection: inspection) }
        }
        .overlay {
            if engine.phase == .flying,let entry=engine.hud.planetEntry {
                PlanetEntryOverlay(entry:entry,canCancel:engine.galaxyJumpActive,reducedDetail:engine.settings.performanceMode || engine.settings.terrainReducedDetail,onCancel:engine.cancelUniverseJump,onPause:engine.pause).ignoresSafeArea()
            }
        }
        .overlay(alignment: .center) { AsteroidScanOverlay(engine: engine).ignoresSafeArea().allowsHitTesting(false) }
        .overlay {
            if let planet = engine.arrivingPlanetName, engine.error == nil {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 18) {
                        Text(engine.storyLaunching ? planet : "Approaching " + planet).font(.title).foregroundStyle(.white)
                        ProgressView(value: Double(engine.preparationProgress)).frame(maxWidth: 280).tint(.white)
                        Text("Preparing the complete region…").font(.caption).foregroundStyle(.white)
                    }
                }
            }
        }
        .overlay {
            if showIntro {
                if !usesOriginalLaunchTitle, let movie = Bundle.main.url(forResource: "StarflightIntro", withExtension: "mp4") {
                    VideoLaunchIntro(url: movie, muted: !engine.settings.soundEnabled) { showIntro = false }
                } else {
                    LaunchTitleAnimation { showIntro = false }
                }
            }
        }
        .frame(width: viewport.size.width, height: viewport.size.height)
        .foregroundStyle(.white)
        .overlay(alignment:.top) {
            if let notice = engine.pilotNotice {
                Text(notice).font(.system(size:12,weight:.semibold)).multilineTextAlignment(.center)
                    .padding(12).frame(maxWidth:340).background(FlightStyle.ink.opacity(0.94),in:RoundedRectangle(cornerRadius:14))
                    .overlay(RoundedRectangle(cornerRadius:14).stroke(FlightStyle.mint.opacity(0.5)))
                    .padding(.top,engine.phase == .flying ? 110:70).allowsHitTesting(false).accessibilityIdentifier("Pilot notification")
            }
        }
        .task(id:engine.pilotNotice) {
            guard let notice = engine.pilotNotice else { return }
            do { try await Task.sleep(for:.seconds(7)) } catch { return }
            engine.dismissPilotNotice(notice)
        }
#if targetEnvironment(macCatalyst)
        .fullScreenCover(isPresented: $showHomeWorkspace, onDismiss: finishHomeWorkspace) { homeWorkspace }
#else
        .sheet(isPresented: $showHomeWorkspace, onDismiss: finishHomeWorkspace) {
            homeWorkspace.presentationDetents([.large]).presentationDragIndicator(.visible)
        }
#endif
        .fullScreenCover(isPresented: $inspectHangar) { InteractiveHangarView(engine: engine) }
        .sheet(isPresented: $showTradingConsole, onDismiss: {
            if resumeAfterTrading && engine.phase == .paused { engine.resume() }
            resumeAfterTrading = false
        }) { NavigationStack { SpaceTradeView(engine: engine) } }
        .sheet(isPresented: $showFlightTools, onDismiss: { if engine.phase == .paused { engine.resume() } }) { FlightToolsView(engine: engine) }
        .sheet(isPresented:$showUniverse,onDismiss:{ if engine.phase == .paused { engine.resume() } }) { NavigationStack { UniverseNavigationView(engine:engine) } }
        .onChange(of:engine.universeTravelID) { _,_ in
            showUniverse = false; showSpaceMap = false; showFlightTools = false; showSettings = false
            resumeAfterTrading = false; showTradingConsole = false
        }
        .sheet(isPresented:$showSpaceMap,onDismiss:{ if engine.phase == .paused { engine.resume() } }) { SpaceMapView(engine:engine) }
#if targetEnvironment(macCatalyst)
        .fullScreenCover(isPresented: $showSettings, onDismiss: { engine.applySettings() }) { SettingsView(engine: engine) }
#else
        .sheet(isPresented: $showSettings, onDismiss: { engine.applySettings() }) { SettingsView(engine: engine) }
#endif
        .sheet(isPresented:$showPilotLogbook) { PilotLogbookView(engine:engine) }
        .sheet(isPresented: $showShop) { FlightShopView(engine:engine) }
        .sheet(isPresented:$showArena) { ArenaSetupView(engine:engine) }
        .sheet(isPresented:$showStory,onDismiss:{ engine.dismissStoryDebrief() }) { NavigationStack { StoryCampaignView(engine:engine) } }
        .onChange(of:engine.storyLaunching) { _, launching in
            if launching { showHomeWorkspace = false; showStory = false; showFlightTools = false; showSettings = false; resumeAfterTrading = false; showTradingConsole = false }
        }
        .onChange(of:engine.storyDebrief) { _, completed in
            guard completed else { return }
            resumeAfterTrading = false; showTradingConsole = false; showFlightTools = false; showSpaceMap = false; showSettings = false
            Task { @MainActor in
                try? await Task.sleep(for:.milliseconds(400))
                if engine.storyDebrief { showStory = true }
            }
        }
        .sheet(isPresented: $showWorkshop) { WorkshopView(engine: engine) }
        .fullScreenCover(item:Binding(get:{ engine.interiorHome },set:{ if $0 == nil { engine.exitResidence() } }),onDismiss:{ engine.exitResidence() }) { plot in
            HomeInteriorView(engine:engine,plot:plot)
        }
        .sheet(item: $planner) { tab in FlightPlannerView(engine: engine, initialTab: tab) }
        .overlay(alignment: .top) {
            if let shortcut = pendingShortcut, engine.phase != .title {
                Text("Return to base to open \(shortcut.title). Your current session is still here.")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .padding(12).background(FlightStyle.ink.opacity(0.96), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.top, 12).padding(.horizontal)
                    .accessibilityIdentifier("Widget shortcut waiting")
            }
        }
        .onOpenURL { url in
            guard let shortcut = StarflightShortcut(url: url) else { return }
            showIntro = false
            pendingShortcut = shortcut
            if engine.phase == .title { openPendingShortcut() } else { engine.pause() }
        }
        .onChange(of: engine.phase) { _, phase in
            if phase == .title { openPendingShortcut() }
            else { showHomeWorkspace = false }
        }
        .environment(\.fullFlightGlow, !engine.settings.performanceMode)
        // Motion and camera controls do not generate touch events. Keep the display
        // awake only while this scene is active and flight is actually running.
        .onChange(of: keepsScreenAwake, initial: true) { _, keepAwake in
            updateScreenIdleTimer(keepAwake)
        }
        .onDisappear { updateScreenIdleTimer(false) }
        .onReceive(NotificationCenter.default.publisher(for:UIApplication.didReceiveMemoryWarningNotification)) { _ in
            AetherReleaseProbe.shared?.memoryWarning()
        }
        .task {
            if AetherReleaseValidation.configuration != nil {
                showIntro = false
                await engine.runAetherReleaseCheck()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // System permission sheets temporarily make the app inactive. Let the
            // requested microphone authorization finish; backgrounding still stops it.
            if phase == .inactive && engine.droidVoice.state == .requestingPermission { return }
            if phase == .inactive && engine.hand.requestingPermission { return }
            engine.setActive(phase == .active)
        }
        .task(id: engine.phase) {
            if engine.phase == .title { await engine.autoSavePlayerIfReady() }
            showCrashMenu = false
            if engine.phase == .crashed {
                try? await Task.sleep(for: .seconds(1.1))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) { showCrashMenu = true }
            }
        }
        }
        .ignoresSafeArea(.keyboard)
#if canImport(UIKit)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
#endif
    }
}

private struct HangarShipSelector: View {
    @ObservedObject var engine: GameEngine
    var body: some View {
        HStack(spacing: 8) {
            Button { engine.cycleHangarShip(-1) } label: { Image(systemName: "chevron.left").frame(width: 24, height: 24) }
                .buttonStyle(MenuActionButtonStyle(expands: false)).accessibilityLabel("Previous ship").accessibilityIdentifier("Previous hangar ship")
            Text("Ship").font(.caption).foregroundStyle(FlightPalette.cyan)
            Button { engine.cycleHangarShip(1) } label: { Image(systemName: "chevron.right").frame(width: 24, height: 24) }
                .buttonStyle(MenuActionButtonStyle(expands: false)).accessibilityLabel("Next ship").accessibilityIdentifier("Next hangar ship")
        }.disabled(engine.phase != .title)
    }
}

private struct InteractiveHangarView: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HangarSceneView(engine: engine).ignoresSafeArea()
            .overlay(alignment: .top) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(engine.aircraftName).font(.headline)
                        Text("Drag to orbit · Pinch or scroll to zoom").font(.caption)
                    }.allowsHitTesting(false)
                    Spacer()
                    HangarShipSelector(engine: engine)
                    Button("Done") { dismiss() }.flightButtonGlass()
                        .accessibilityIdentifier("Close interactive hangar")
                }.foregroundStyle(.white).padding(20)
            }
    }
}

private enum HomeMenuAction: Int, CaseIterable, Identifiable {
    case flight, planner, freeRoam, space, story, arena, creations, shop, logbook, inspect, settings
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .flight: return "Take flight"
        case .planner: return "Flight planner"
        case .freeRoam: return "Free roam"
        case .space: return "Space free roam"
        case .story: return "Story"
        case .arena: return "Arena"
        case .creations: return "Creations"
        case .shop: return "Shop"
        case .logbook: return "Logbook"
        case .inspect: return "Inspect ship"
        case .settings: return "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .flight: return "airplane"
        case .planner: return "list.bullet.rectangle"
        case .freeRoam: return "mountain.2"
        case .space: return "sparkles"
        case .story: return "book.closed"
        case .arena: return "scope"
        case .creations: return "wrench.and.screwdriver"
        case .shop: return "bag"
        case .logbook: return "rosette"
        case .inspect: return "view.3d"
        case .settings: return "slider.horizontal.3"
        }
    }
    var shortTitle: String {
        switch self {
        case .flight: return "Fly"
        case .planner: return "Planner"
        case .freeRoam: return "Roam"
        case .space: return "Space"
        case .creations: return "Create"
        case .inspect: return "Hangar"
        default: return title
        }
    }
    var detail: String {
        switch self {
        case .flight: return "Launch your selected ship and route"
        case .planner: return "Choose your ship, level and droid"
        case .freeRoam: return "Explore mountains at your own pace"
        case .space: return "Discover planets, mine and trade"
        case .story: return "Continue The Last Beacon"
        case .arena: return "Challenge rivals in duels and trios"
        case .creations: return "Build ships, landscapes and room flights"
        case .shop: return "Blueprint packs and pilot accessories"
        case .logbook: return "Achievements, profile and flight history"
        case .inspect: return "Rotate and zoom around your ship"
        case .settings: return "Controls, sound and personal preferences"
        }
    }
    var accessibilityID: String {
        switch self {
        case .planner: return "Choose Flight planner"
        case .freeRoam: return "Choose Free roam"
        case .space: return "Choose Space free roam"
        case .story: return "Story campaign"
        case .arena: return "Arena duels"
        case .creations: return "My creations"
        case .logbook: return "Pilot logbook"
        case .inspect: return "Inspect hangar"
        default: return title
        }
    }

}

private struct HomeWorkspaceView: View {
    @ObservedObject var engine: GameEngine
    let section: HomeMenuAction
    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch section {
                case .planner: FlightPlannerView(engine: engine, initialTab: .aircraft)
                case .story: NavigationStack { StoryCampaignView(engine: engine) }
                case .arena: ArenaSetupView(engine: engine)
                case .creations: WorkshopView(engine: engine)
                case .shop: FlightShopView(engine: engine)
                case .logbook: PilotLogbookView(engine: engine)
                case .inspect: InteractiveHangarView(engine: engine)
                case .settings: SettingsView(engine: engine)
                case .flight, .freeRoam, .space: Color.clear
                }
            }.id(section).frame(maxWidth: .infinity, maxHeight: .infinity)
        }.background(FlightStyle.ink)
    }
}

/// One pinned glass navigation row; narrow screens can scroll without wrapping.
private struct HomeNavigationDock: View {
    @ObservedObject var engine: GameEngine
    let selection: HomeMenuAction
    let onSelect: (HomeMenuAction) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var highlight
    @ScaledMetric(relativeTo: .caption2) private var navigationLabelSize = 9.0
    @ScaledMetric(relativeTo: .caption) private var minimumCellWidth = 54.0
    @ScaledMetric(relativeTo: .caption) private var minimumCellHeight = 56.0
    private var launchTitle: String {
        if !engine.ready { return "Preparing \(Int(engine.preparationProgress*100))%" }
        if engine.arenaSelected { return engine.arenaFormat == .trio ? "Battle now" : "Duel now" }
        return engine.level.isPodRace ? "Race now" : "Take flight"
    }
    var body: some View {
        GeometryReader { geometry in
        ScrollView(.horizontal, showsIndicators: true) {
        HStack(spacing: 4) {
            ForEach(HomeMenuAction.allCases) { item in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { onSelect(item) }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol).font(.system(size: 20, weight: .medium))
                            .accessibilityHidden(true)
                        Text(item == .flight && !engine.ready ? "Preparing" : item.shortTitle)
                            .font(.system(size: navigationLabelSize, weight: .semibold)).lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4).padding(.vertical, 6)
                    .frame(minWidth: max(54, minimumCellWidth), maxWidth: .infinity, minHeight: minimumCellHeight)
                    .background {
                        if selection == item {
                            Capsule().fill(.white.opacity(0.18))
                                .matchedGeometryEffect(id: "Home dock selection", in: highlight)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(item == .flight && (!engine.ready || engine.error != nil))
                .opacity(item == .flight && (!engine.ready || engine.error != nil) ? 0.45 : 1)
                .accessibilityLabel(item == .flight ? launchTitle : item.title)
                .accessibilityHint(item.detail)
                .accessibilityIdentifier(item.accessibilityID)
                .accessibilityValue(selection == item ? "Selected" : "")
                .accessibilityAddTraits(selection == item ? .isSelected : [])
                .help(item.detail)
            }
        }
        .frame(minWidth: geometry.size.width)
        }
        }
        .frame(height: minimumCellHeight + 12)
        .padding(6).frame(maxWidth: 1280)
        .modifier(HomeDockGlass(solid: reduceTransparency))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Starflight main navigation")
        .accessibilityIdentifier("Home action slider")
        .preferredColorScheme(.dark)
    }
}

private struct HomeDockGlass: ViewModifier {
    let solid: Bool
    @ViewBuilder func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        if solid {
            content.background(FlightStyle.ink, in: shape)
                .overlay(shape.stroke(.white.opacity(0.25), lineWidth: 1))
        } else if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

private struct StartScreen: View {
    @ObservedObject var engine: GameEngine
    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 500
            ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: compact ? 6 : 24) {
                HStack {
                    Text("Hangar · Inspect ship to rotate and zoom").font(FlightStyle.displayFont(compact ? 8 : 10)).textCase(.lowercase)
                        .foregroundStyle(.white).allowsHitTesting(false)
                    Spacer()
                    HangarShipSelector(engine: engine)
                    Text("v\(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "—") · build \(Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "—")")
                        .font(.system(size:compact ? 9 : 11,design:.monospaced))
                        .foregroundStyle(.white).accessibilityIdentifier("Home version")
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 24) {
                    VStack(alignment: .leading, spacing: compact ? 6 : 20) {
                        Text("Starflight").flightButtonGlow()
                            .font(FlightStyle.displayFont(compact ? 32 : 66)).textCase(.lowercase)
                            .lineLimit(1).minimumScaleFactor(0.65)
                            .tracking(-3).lineSpacing(compact ? -16 : -25)
                            .shadow(color: .black.opacity(0.2), radius: 15, y: 6)
                            .shadow(color: .blue.opacity(0.6),radius: 5)
                            .shadow(color: .pink.opacity(0.1),radius: 5)
                            .shadow(color: .purple.opacity(0.4),radius: 5)
                        Text(engine.arenaSelected ? "Outfly your rival. Break its shields. Win the duel." : engine.level.isPodRace ? "Charge the energy binders. Skid the hairpins. Fight for the racing line." : engine.isRelaxedSpace ? "Explore planets, mine asteroids, and open trade routes." : engine.level.isFreeRoam ? "Explore the mountains, earn low-flight points, and travel into space." : "Find your line through the mountains.").flightButtonGlow()
                            .font(.system(size: compact ? 12 : 17)).foregroundStyle(.white)
   
                        Text("\(engine.aircraftName) · \(engine.levelName)").flightButtonGlow()
                            .font(.system(size: compact ? 10 : 13, weight: .medium)).foregroundStyle(FlightPalette.cyan)
                            .accessibilityIdentifier("Current flight selection")
                        if let ending = engine.storyProgress.ending { Text(ending.title).font(.caption).foregroundStyle(FlightPalette.gold) }
                        Text("DROID CREW · \(engine.settings.droid.name) · \(engine.economy.creditsLabel) CR").flightButtonGlow()
                            .padding(compact ? 0 : 10)
                            .font(.system(size: compact ? 10 : 12, weight: .medium))
                            .foregroundStyle(FlightPalette.gold)
                        Text(engine.arenaSelected ? "AIM   /   EVADE   /   RECHARGE SHIELDS" : engine.level.isPodRace ? "BANK THROUGH THE GATES   /   HOLD BOOST   /   BLAST PAST RIVALS" : engine.isRelaxedSpace ? "EXPLORE PLANETS   /   MINE ASTEROIDS   /   TRADE CARGO" : engine.level.isFreeRoam ? "LOW FLIGHT POINTS   /   HYPERSPACE   /   SPACE FREE ROAM" : "PULL BACK TO CLIMB   /   BANK TO TURN   /   FLY THROUGH THE GATES").flightButtonGlow()
                            .font(.system(size: compact ? 6 : 8, weight: .medium, design: .monospaced))
                            .tracking(0.5).foregroundStyle(.white)
                        #if targetEnvironment(macCatalyst)
                        Text("W/S PITCH  ·  A/D BANK  ·  Q/E RUDDER  ·  +/− THROTTLE  ·  SPACE PAUSE").flightButtonGlow()
                            .font(.system(size: compact ? 7 : 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                        #endif
                    }
                    Spacer(minLength: 0)
                    if proxy.size.width >= 1050 {
                        VStack(alignment: .leading, spacing: compact ? 10 : 18) {
                            Text(engine.arenaSelected ? "ARENA · \(engine.arenaDifficulty.rawValue.uppercased()) RIVAL" : engine.customLevel == nil ? "LEVEL 0\(engine.level.number) · \(engine.level.challenge)" : "MY CREATIONS · MOUNTAIN ROUTE").flightButtonGlow()
                                .font(FlightStyle.displayFont(8)).textCase(.lowercase).tracking(1)
                                .foregroundStyle(.white)
                            Text(engine.levelName).flightButtonGlow().font(FlightStyle.displayFont(compact ? 19 : 25)).textCase(.lowercase).lineLimit(2).minimumScaleFactor(0.7)
                            Text(engine.isRelaxedSpace ? "Explore planetary surfaces, mine asteroids in orbit, and connect markets with trade routes." : engine.level.isFreeRoam ? "Explore the mountains at your own pace, or visit the portals for an asteroid challenge." : engine.customLevel == nil ? engine.level.subtitle : "Your own seeded landscape, with checkpoints placed above its valleys.").flightButtonGlow().font(.system(size: 10)).foregroundStyle(.white)
                            Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
                            HStack(spacing: 20) {
                                routeStat(engine.level.isFreeRoam ? "∞" : String(format: "%.1f", engine.level.routeLength / 1000), label: engine.level.isFreeRoam ? "DISTANCE" : "KM ROUTE")
                                routeStat(engine.level.isFreeRoam ? "—" : "\(engine.gateCount)", label: "GATES")
                                routeStat("\(AircraftType.allCases.filter { engine.economy.unlocked($0) }.count)", label: "VEHICLES")
                            }
                            if !engine.level.isFreeRoam { HStack(spacing: 5) {
                                ForEach(0..<engine.gateCount, id: \.self) { i in
                                    Capsule().fill(i < engine.bestGates ? FlightStyle.mint : .white.opacity(0.17)).frame(height: 3)
                                }
                            } }
                            Text(engine.level.isFreeRoam ? "No checkpoints · explore at your own pace" : "\(engine.bestGates) / \(engine.gateCount) gates · personal best").flightButtonGlow()
                                .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white)
                        }.modifier(FlightPanel()).frame(width: compact ? 242 : 282)
                    }
                }
            }
            .frame(minHeight: max(0, proxy.size.height - (compact ? 36 : 96)), alignment: .bottomLeading)
            .padding(compact ? 18 : 48)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .background(LinearGradient(colors: [FlightStyle.ink.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing).ignoresSafeArea().allowsHitTesting(false))
        }
    }
    private func routeStat(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).flightButtonGlow().font(.system(size: 22, weight: .light, design: .monospaced))
            Text(label).flightButtonGlow().font(FlightStyle.displayFont(7)).textCase(.lowercase).tracking(1).opacity(0.9)
        }
    }
}

private struct FlightMenu: View {
    @ObservedObject var engine: GameEngine
    @Binding var showSettings: Bool
    @Binding var showPilotLogbook: Bool
    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 500
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: compact ? 12 : 20) {
                    Label(engine.phase == .paused ? (engine.level.isPodRace ? "RACE PAUSED" : "FLIGHT PAUSED") : engine.phase == .crashed ? "FLIGHT RECORDER" : engine.level.isPodRace ? "RACE RESULTS" : "EXPEDITION COMPLETE",
                          systemImage: engine.phase == .crashed ? "waveform.path.ecg" : engine.level.isPodRace ? "flag.checkered" : "mountain.2").flightButtonGlow()
                        .font(FlightStyle.displayFont(9)).textCase(.lowercase).tracking(2)
                        .foregroundStyle(.white)
                    Text(engine.phase == .paused ? "Take a breath." : engine.phase == .crashed ?
                         FlightCrashAdvice(cause:engine.crashCause ?? "Flight ended").title : "Above and beyond.").flightButtonGlow()
                        .font(FlightStyle.displayFont(compact ? 24 : 30)).textCase(.lowercase).lineLimit(2).minimumScaleFactor(0.7)
                    if engine.hud.fuelPercent <= 0 {
                        Text("Fuel empty. Restart flight or return to base for a free refill.").font(.subheadline).foregroundStyle(.white)
                    }
                    Text(engine.phase == .paused ? "Your aircraft is holding here until you return." : engine.phase == .crashed ?
                         FlightCrashAdvice(cause:engine.crashCause ?? "Flight ended").advice :
                         (engine.level.isPodRace ? "Finished \(engine.racePositionLabel) against the rival pack in \(engine.levelName)." : "\(engine.gateCount) gates cleared in \(engine.levelName). A safe passage.")).flightButtonGlow()
                        .font(.system(size: 12)).foregroundStyle(.white)
                    HStack(spacing: 26) {
                        metric(String(format: "%.1f km", engine.hud.distance / 1000), label: "FLOWN")
                        metric("\(engine.hud.lowFlightPoints)", label: "LOW FLIGHT POINTS")
                        metric(engine.level.isFreeRoam ? "FREE" : "\(engine.hud.passed) / \(engine.gateCount)", label: engine.level.isFreeRoam ? "MODE" : "GATES")
                        metric(String(format: "%02d:%02d", Int(engine.hud.elapsed) / 60, Int(engine.hud.elapsed) % 60), label: "AIR TIME")
                    }
                    HStack {
                        Button(engine.phase == .paused ? "Resume flight" : "Fly again") {
                            if engine.phase == .paused { engine.resume() } else { engine.start() }
                        }.flightButtonGlass().buttonStyle(PrimaryFlightButton())
                            .accessibilityIdentifier(engine.phase == .paused ? "Resume flight" : "Fly again")
                            .disabled(engine.phase == .paused && engine.hud.fuelPercent <= 0)
                        if engine.phase == .completed, engine.nextLevel != nil {
                            Button("Next level", action: engine.prepareNextLevel).flightButtonGlass().buttonStyle(PrimaryFlightButton())
                                .accessibilityIdentifier("Next level")
                        }
                        if engine.phase == .paused {
                            InstrumentButton(icon: "slider.horizontal.3", label: "Settings") { showSettings = true }
                        }
                    }
                    HStack(spacing: 22) {
                        if engine.phase == .paused { Button("Restart flight", action: engine.start).flightButtonGlass() }
                        Button("Pilot logbook") { showPilotLogbook = true }.flightButtonGlass().accessibilityIdentifier("Pilot logbook")
                        Button("Back to base", action: engine.returnToTitle).flightButtonGlass()
                    }.font(.system(size: 11)).foregroundStyle(.white).buttonStyle(GlowingFlightButton())
                    if engine.canWatchReplay {
                        Button("Watch last 15 seconds",action:engine.watchReplay).flightButtonGlass().accessibilityIdentifier("Watch last 15 seconds")
                    }
                }.modifier(FlightPanel()).frame(maxWidth: 430)
                if engine.phase != .crashed || proxy.size.width < 600 { Spacer() }
            }.padding(18).frame(maxWidth: .infinity, maxHeight: .infinity,
                alignment: engine.phase == .crashed && proxy.size.width >= 600 ? .bottomTrailing : .center)
        }
    }
    private func metric(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).flightButtonGlow().font(.system(size: 18, weight: .light, design: .monospaced))
            Text(label).flightButtonGlow().font(FlightStyle.displayFont(8)).textCase(.lowercase).tracking(1.5).opacity(0.9)
        }
    }
}

struct LaunchTitleAnimation: View {
    let finish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var receding = false
    @State private var fading = false
    @State private var started = Date()
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
                Canvas { context, size in
                    let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSince(started)
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    for index in 0..<90 {
                        let angle = Double(index) * 2.39996
                        let progress = (Double(index % 23) / 23 + elapsed * 0.13).truncatingRemainder(dividingBy: 1)
                        let radius = progress * max(size.width, size.height) * 0.8
                        let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                        let tail = reduceMotion ? 0 : progress * 18
                        var streak = Path()
                        streak.move(to: point)
                        streak.addLine(to: CGPoint(x: point.x + cos(angle) * tail, y: point.y + sin(angle) * tail))
                        context.stroke(streak, with: .color(.white.opacity(0.2 + progress * 0.7)), lineWidth: index.isMultiple(of: 9) ? 2 : 1)
                    }
                }
            }.ignoresSafeArea().allowsHitTesting(false)
            GeometryReader { geometry in
                let inset = min(24.0, geometry.size.height * 0.05)
                let titleSize = min(76.0, max(24.0, (geometry.size.height - 100) * 0.22), geometry.size.width * 0.14)
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Text("STAR\nWARS").raisedTitle().font(FlightStyle.displayFont(titleSize)).multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.5)
                        .foregroundStyle(Color(red: 1, green: 0.84, blue: 0.08))
                        .shadow(color: .yellow.opacity(0.3), radius: 8)
                        .scaleEffect(receding ? 0.22 : 1)
                        .rotation3DEffect(.degrees(receding ? 38 : 0), axis: (x: 1, y: 0, z: 0))
                        .opacity(receding ? 0 : 1)
                        .accessibilityIdentifier("Intro title")
                    Text("STARFLIGHT").font(.system(size: min(16, titleSize * 0.25), weight: .medium, design: .monospaced))
                        .tracking(min(7, titleSize * 0.09)).lineLimit(1).minimumScaleFactor(0.5)
                        .foregroundStyle(.white).opacity(receding ? 1 : 0)
                    Spacer(minLength: 0)
                    Button("Skip intro", action: finish).flightButtonGlass().font(.system(size: 13))
                        .foregroundStyle(.white).frame(minHeight: 44)
                        .accessibilityIdentifier("Skip intro")
                }.padding(inset).frame(width: geometry.size.width, height: geometry.size.height)
            }
        }.opacity(fading ? 0 : 1)
            .task {
                started = Date()
#if DEBUG
                // Freeze the largest title frame for phone safe-area UI checks.
                if ProcessInfo.processInfo.environment["STARFLIGHT_INTRO_LAYOUT_TEST"] == "1" { return }
#endif
                if !reduceMotion { withAnimation(.easeIn(duration: 2.6)) { receding = true } }
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.5 : 2.6))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.35)) { fading = true }
                try? await Task.sleep(for: .seconds(0.35))
                if !Task.isCancelled { finish() }
            }
    }
}
