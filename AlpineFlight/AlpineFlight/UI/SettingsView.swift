import SwiftUI

struct SettingsView: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var showAccount = false
    @State private var previewIntro = false
    private var settingsSections: [String] {
        var sections = ["About Starflight", "Account", "App icon", "Camera hand control", "Droid copilot", "Flight controls", "Hangar preview", "Help & voice commands", "Navigation & activities", "Opening intro", "Sound & graphics", "The expedition"]
#if os(iOS) && !targetEnvironment(macCatalyst)
        sections.append("Home Screen widget")
#endif
        return sections.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    private var settingsMaximumWidth: CGFloat {
#if targetEnvironment(macCatalyst)
        .infinity
#else
        800
#endif
    }
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            Form {
                Section("About Starflight") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "—")
                        .accessibilityIdentifier("App version")
                    LabeledContent("Build", value: Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "—")
                    DisclosureGroup("Planet imagery credits") {
                        Text("Earth: NASA/GSFC Scientific Visualization Studio, Reto Stockli and NASA Earth Observatory. Mars: NASA/JPL & Caltech, Viking imagery processed at USGS. Venus radar surface: NASA/JPL-Caltech. Jupiter: NASA/JPL/Space Science Institute. Procedural flight landscapes are artistic, not measured terrain.")
                            .font(.caption).foregroundStyle(FlightPalette.secondary)
                        Link("NASA imagery and media guidelines", destination: URL(string: "https://www.nasa.gov/nasa-brand-center/images-and-media/")!)
                    }
                }
                    .id("About Starflight")
                AccountSettingsSection(engine:engine) { showAccount = true }
                    .id("Account")
                StarflightIconSettings()
                    .id("App icon")
                HandControlSettings(engine: engine, hand: engine.hand)
                    .id("Camera hand control")
                Section("Droid copilot") {
                    HStack {
                        Image(systemName: "cpu.fill").foregroundStyle(engine.settings.droid.tint)
                        VStack(alignment: .leading) {
                            Text(engine.settings.droid.name)
                            Text(engine.settings.droid.role).font(.caption2).foregroundStyle(FlightPalette.secondary)
                        }
                    }
                    Text("Choose a droid in the Flight Planner. In cockpit view, its optic window appears on the right. Tap the microphone and say “Hey droid, set throttle to 75 percent.” Voice listening is optional and only runs while enabled.")
                        .font(.caption).foregroundStyle(FlightPalette.secondary)
                    DroidPermissionSettings(voice: engine.droidVoice)
                        .onDisappear { engine.droidVoice.stop() }
                }
                    .id("Droid copilot")
                Section("Flight controls") {
                    VStack(alignment: .leading, spacing: 6) {
                    FlightSwitchRow("Device tilt", isOn: $engine.settings.tiltEnabled)
                        .tint(FlightPalette.teal)
                        .disabled(!engine.motion.available || (engine.settings.handControlEnabled && engine.hand.available))
                    Text("Steer your spaceship by tilting your device.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                    FlightSwitchRow("Invert pitch", isOn: $engine.settings.invertPitch)
                        .tint(FlightPalette.teal)
                    Text("Reverse the joystick’s up and down movement.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Control sensitivity · \(engine.settings.sensitivity, specifier: "%.1f")×")
                        Text("Adjust how quickly your spaceship responds to your controls.").font(.subheadline).foregroundStyle(.secondary)
                        Slider(value: $engine.settings.sensitivity, in: 0.5...2.5, step: 0.1).accessibilityLabel("Control sensitivity").accessibilityValue(String(format: "%.1f times", engine.settings.sensitivity))
                        HStack { Text("Precise"); Spacer(); Text("Responsive") }.font(.caption).foregroundStyle(FlightPalette.cyan)
                    }
                    DisclosureGroup("How to Fly") {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Joystick: Pull down to raise the spaceship’s nose. Invert Pitch reverses this.", systemImage: "arrow.up.and.down")
                            Label("Banking: Move left or right to bank and turn.", systemImage: "airplane")
                            Label("Rudder: Use the arrow buttons to control the rudder.", systemImage: "arrow.left.arrow.right")
                            Label("Device Tilt: Tilt the device to steer when enabled.", systemImage: "iphone")
                            Label("Neutral Position: The device’s position when flight begins or resumes becomes its neutral position.", systemImage: "scope")
                            Label("Touch Priority: Touch controls take priority over tilt controls.", systemImage: "hand.draw")
#if !os(iOS) || targetEnvironment(macCatalyst)
                    Text(engine.level.isPodRace ? "A/D steer · Shift skid · B boost · F fire · +/− throttle · C camera · Space pause." : (engine.settings.invertPitch ? "W/↑ lowers the nose · S/↓ raises it." : "W/↑ raises the nose · S/↓ lowers it.") + " A/D bank · Q/E rudder · +/− throttle · Hold F to fire · C camera · Space pause.")
                        .font(.subheadline).foregroundStyle(FlightPalette.cyan)
                        .accessibilityIdentifier("Platform control guide")
                    Text("Start with short steering inputs and watch heading and bank. The on-screen joystick and throttle also work with your mouse.")
                        .font(.caption).foregroundStyle(FlightPalette.secondary)
#endif
                        }.font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 10)
                    }.accessibilityIdentifier("How to Fly")
                    if !engine.motion.available {
                        Label("Device motion is unavailable here. Touch controls remain available.", systemImage: "iphone.slash")
                            .font(.caption).foregroundStyle(FlightPalette.secondary)
                    }
                }
                    .id("Flight controls")
                Section("Hangar preview") {
                    Picker("Menu scenery", selection: $engine.settings.hangarPreview) {
                        ForEach(HangarPreviewStyle.allCases) { Text($0.title).tag($0) }
                    }.accessibilityIdentifier("Hangar scenery style")
                    Text("Show your ship in the orbiting showroom, or preview it above the level selected in Flight Planner. Inspect ship always opens the interactive showroom.").font(.caption).foregroundStyle(.secondary)
                }.id("Hangar preview")
                Section("Help & voice commands") {
                    DisclosureGroup("Droid command reference") {
                        Text("Start each command with “Hey droid”. Commands act while flying; the settings microphone test only checks what it hears.")
                            .font(.caption).foregroundStyle(FlightPalette.secondary)
                        Text("Set throttle to 75 percent · Full throttle · Cut throttle").foregroundStyle(FlightPalette.gold)
                        Text("Level my ship · Hold altitude · Follow my route · Scan ore").foregroundStyle(FlightPalette.teal)
                        Text("Turn left · Turn right · Climb · Descend").foregroundStyle(FlightPalette.teal)
                        Text("Fire weapons · Cease fire · Boost").foregroundStyle(FlightPalette.gold)
                        Text("Repair shields · Shield status · Scan for enemies").foregroundStyle(FlightPalette.cyan)
                        Text("Next checkpoint · Switch camera · Pause · Cancel assist · Help").foregroundStyle(FlightPalette.violet)
                        Text("Steering lasts 1.5 seconds and your controls take priority. Fire is a 3-second burst. Pod boost lasts 2 seconds and uses normal boost charge. Repairs restore 20 shield points with a 45-second recharge. Climb and descend are unavailable on pod tracks. Switching out of the cockpit or pausing stops listening.")
                            .font(.caption).foregroundStyle(FlightPalette.secondary)
                    }
                }
                    .id("Help & voice commands")
#if os(iOS) && !targetEnvironment(macCatalyst)
                Section("Home Screen widget") {
                    Label("Starflight shortcuts", systemImage: "square.grid.2x2")
                    Text("Touch and hold an empty area of your Home Screen, choose Edit → Add Widget, then search for Starflight. Small opens the hangar; Medium also has Flight planner and Space free roam shortcuts.")
                        .font(.subheadline).textCase(nil)
                    Text("If a flight is already open, it stays paused. Return to base to follow the shortcut.")
                        .font(.caption).textCase(nil)
                }
                    .id("Home Screen widget")
#endif
                Section("Navigation & activities") {
                    NavigationLink("Story campaign · The Last Beacon") { StoryCampaignView(engine:engine) }
                    NavigationLink("Routes, careers & discoveries") { FlightAdventuresView(engine:engine) }
                    Picker("Weather",selection:$engine.settings.weather) { ForEach(FlightWeather.allCases) { Text($0.title).tag($0) } }
                    Text(engine.settings.weather.briefing).font(.caption).foregroundStyle(FlightPalette.cyan)
                    FlightSwitchRow("Best-lap racing ghost",isOn:$engine.settings.showGhost).tint(FlightPalette.cyan)
                }
                    .id("Navigation & activities")
                Section("Opening intro") {
                    Picker("Intro style", selection: $engine.settings.introStyle) {
                        ForEach(LaunchIntroStyle.allCases) { style in Text(style.title).tag(style) }
                    }.accessibilityIdentifier("Opening intro style")
                    Button("Preview selected intro") { previewIntro = true }
                        .buttonStyle(MenuActionButtonStyle(expands: false)).accessibilityIdentifier("Preview selected intro")
                    Text("Choose the Canva cinematic or the original yellow Star Wars title. Plays next time you open Starflight; either intro can be skipped.")
                        .font(.caption).foregroundStyle(FlightPalette.secondary)
                }
                    .id("Opening intro")
                Section("Sound & graphics") {
                    FlightSwitchRow("Sound effects", isOn: $engine.settings.soundEnabled)
                        .tint(FlightPalette.teal)
                    HStack {
                        Text("Effects volume")
                        Slider(value:$engine.settings.soundVolume,in:0...1)
                            .accessibilityLabel("Effects volume")
                            .accessibilityIdentifier("Effects volume")
                        Text("\(Int(engine.settings.soundVolume*100))%")
                            .monospacedDigit().foregroundStyle(FlightPalette.cyan).frame(width:45,alignment:.trailing)
                    }.disabled(!engine.settings.soundEnabled)
                    Button { engine.testGameSound() } label: { Label("Test sound",systemImage:"speaker.wave.2.fill") }
                        .accessibilityIdentifier("Test game sound")
                    Text(engine.soundTestMessage).font(.caption).foregroundStyle(FlightPalette.cyan)
                        .accessibilityIdentifier("Game sound test status")
                    Text("Sound effects use media volume and can play in Silent Mode. The in-game sound switch and volume still control them.")
                        .font(.caption).foregroundStyle(FlightPalette.secondary)
                    FlightSwitchRow("Performance mode", isOn: $engine.settings.performanceMode)
                        .tint(FlightPalette.teal)
                    Text("For older devices: targets 30 flight updates per second, simplifies terrain, reduces clouds, uses a light glow on buttons and panels, and turns off HDR and grounding shadows. Turn this off for the full interface glow. Terrain changes apply when the next region is prepared.")
                        .font(.caption).foregroundStyle(FlightPalette.secondary)
                    FlightSwitchRow("Reduced scenery detail", isOn: $engine.settings.reducedDetail)
                        .tint(FlightPalette.teal)
                    Text("Reduced detail prepares a simpler version of the complete region. Terrain remains fixed once preparation finishes; tiles are never swapped while you fly. Changes made during flight apply to the next region preparation.")
                        .font(.caption).foregroundStyle(FlightPalette.secondary)
                }
                    .id("Sound & graphics")
                Section("The expedition") {
                    Text("Fly north through \(engine.gateCount) amber gates in order on \(engine.levelName). Each gate sits beyond a mountain saddle. Follow the bearing arrow; if you miss a gate, circle back and approach from the south. Wind strengthens and haze increases as you enter the higher passes.")
                    Text("Altitude is metres above the region’s sea level; Ground clearance is the height directly beneath your ship. Airspeed is shown in knots. Follow the objective for your chosen flight, race or activity; free roam lets you explore at your own pace.").textCase(nil)
                }.font(.caption)
                    .id("The expedition")
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Menu {
                    ForEach(settingsSections, id: \.self) { section in
                        Button(section) { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(section, anchor: .top) } }
                    }
                } label: {
                    Label("Jump to section", systemImage: "list.bullet")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(FlightPalette.cyan)
                        .background(Color(red: 0.06, green: 0.08, blue: 0.1))
                }.buttonStyle(.plain).accessibilityIdentifier("Settings quick jump")
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.035, green: 0.045, blue: 0.06), in: RoundedRectangle(cornerRadius: 24))
            .frame(maxWidth: settingsMaximumWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .tint(FlightPalette.cyan)
            .toggleStyle(.switch)
            .navigationTitle("Flight settings")
#if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.buttonStyle(MenuActionButtonStyle(expands: false)).accessibilityIdentifier("Done") } }
            }
        }.fullScreenCover(isPresented:$showAccount) { AccountView(engine:engine,account:engine.account) }
            .fullScreenCover(isPresented: $previewIntro) {
                if engine.settings.introStyle == .canva, let url = Bundle.main.url(forResource: "StarflightIntro", withExtension: "mp4") {
                    VideoLaunchIntro(url: url, muted: !engine.settings.soundEnabled) { previewIntro = false }
                } else { LaunchTitleAnimation { previewIntro = false } }
            }
        .font(.body).textCase(nil).preferredColorScheme(.dark)
            .onDisappear { if engine.hand.checking { engine.hand.finishCheck() } }
    }
}

private struct HandControlSettings: View {
    @ObservedObject var engine: GameEngine
    @ObservedObject var hand: HandController
    var body: some View {
        Section("Camera hand control") {
            if hand.available {
                FlightSwitchRow("Hand steering", isOn: $engine.settings.handControlEnabled).tint(FlightPalette.teal)
                    .accessibilityIdentifier("Hand steering")
                    .onChange(of: engine.settings.handControlEnabled) { _, enabled in
                        if enabled { engine.settings.tiltEnabled = false; hand.beginCheck() }
                        else { hand.stop() }
                    }
                Text("Position your device so its camera faces you. Switch on hand steering, then show one hand and hold it still until the check turns green. Move left or right to bank, up to climb, and down to descend. You have a wide movement area: small moves start a gentle turn, larger moves bank harder. Tap the hand status during flight to recenter.")
                    .font(.caption).foregroundStyle(FlightPalette.secondary)
                Text("Your center stays paired during tracking. If your hand becomes too small to track or leaves the camera view, steering pauses; move it closer to resume. Touch takes priority. The camera runs during this check and flight; images are never recorded.")
                    .font(.caption).foregroundStyle(FlightPalette.secondary)
                Text("Ship gestures: pinch thumb and index finger with your other fingers open to fire; release to stop. Hold a peace sign for camera, then open your hand before switching again. Hold thumbs up/down to adjust throttle gradually. Normal palm movement still steers. Gesture actions require a paired, visible hand.")
                    .font(.caption).foregroundStyle(FlightPalette.secondary).accessibilityIdentifier("Hand gesture guide")
                Text(hand.status).font(.caption).accessibilityIdentifier("Hand control status")
                if engine.settings.handControlEnabled {
                    Label(hand.paired ? "Hand paired" : "Hand check", systemImage: hand.paired ? "checkmark.circle.fill" : "hand.raised.fill")
                        .foregroundStyle(FlightPalette.secondary)
                    if hand.checking && !hand.paired { ProgressView(value: Double(hand.checkProgress)).accessibilityLabel("Hand check progress") }
                    Button("Check hand again") { hand.beginCheck() }.flightButtonGlass()
                }
#if os(iOS)
                if hand.permissionDenied {
                    Button("Open camera permission settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }.flightButtonGlass()
                }
#endif
            } else {
                Text("Hand steering requires iPhone 16 or newer, an iPad running iPadOS 18 or newer, or a Mac running macOS 15 or newer with a camera. It is unavailable on older iPhones and simulators.")
                    .font(.caption).foregroundStyle(FlightPalette.secondary).accessibilityIdentifier("Hand control unavailable")
            }
        }
    }
}

private enum StarflightIcon: String, CaseIterable, Identifiable {
    case standard, classic, hyperspace, gold
    var id: String { rawValue }
    var title: String {
        switch self { case .standard: return "Starflight"; case .classic: return "Original"; case .hyperspace: return "Hyperspace"; case .gold: return "Gold" }
    }
    var alternateName: String? {
        switch self { case .standard: return nil; case .classic: return "AppIcon"; case .hyperspace: return "HyperspaceIcon"; case .gold: return "GoldIcon" }
    }
    var preview: String { "IconPreview_\(rawValue)" }
}

private struct StarflightIconSettings: View {
    @State private var selected: StarflightIcon = .standard
    @State private var changing = false
    @State private var error: String?
    @State private var requestID = UUID()
    @State private var monitor: Task<Void, Never>?
    private var supported: Bool {
#if canImport(UIKit)
        UIApplication.shared.supportsAlternateIcons
#else
        false
#endif
    }
    var body: some View {
        Section("App icon") {
            ForEach(StarflightIcon.allCases) { icon in
                Button { change(to: icon) } label: {
                    HStack(spacing: 14) {
                        Image(icon.preview).resizable().scaledToFit().frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 11)).accessibilityHidden(true)
                        Text(icon.title).foregroundStyle(.primary)
                        Spacer()
                        if selected == icon { Image(systemName: "checkmark").foregroundStyle(FlightPalette.teal) }
                    }
                }.buttonStyle(.plain).disabled(changing || !supported)
                    .accessibilityIdentifier("App icon \(icon.rawValue)")
                    .accessibilityValue(selected == icon ? "Selected" : "")
            }
            if changing { ProgressView("Changing app icon…") }
            Text(supported ? "Choose a still icon for your Home Screen. Your choice stays until you change it again. iPadOS may show a confirmation notice." : "This platform does not support changing the app icon while running. These choices are available on iPhone and iPad.")
                .font(.caption).foregroundStyle(FlightPalette.secondary)
            if let error { Text(error).font(.caption).foregroundStyle(FlightStyle.orange).accessibilityIdentifier("App icon error") }
        }.onAppear { refresh() }.onDisappear {
            monitor?.cancel()
            requestID = UUID()
            changing = false
        }
    }
    private func refresh() {
#if canImport(UIKit)
        selected = StarflightIcon.allCases.first { $0.alternateName == UIApplication.shared.alternateIconName } ?? .standard
#endif
    }
    private func change(to icon: StarflightIcon) {
#if canImport(UIKit)
        guard supported, !changing, selected != icon else { return }
        error = nil; changing = true
        let request = UUID()
        requestID = request
        monitor?.cancel()
        // Some system icon services delay or omit the completion callback.
        // Read the actual selection and never leave the controls disabled forever.
        monitor = Task { @MainActor in
            for _ in 0..<40 {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, requestID == request else { return }
                if UIApplication.shared.alternateIconName == icon.alternateName {
                    refresh(); changing = false
                    return
                }
            }
            refresh(); changing = false
            error = "The system hasn't completed the icon change. Try again, or reopen the app."
        }
        UIApplication.shared.setAlternateIconName(icon.alternateName) { failure in
            DispatchQueue.main.async {
                guard requestID == request else { return }
                monitor?.cancel()
                changing = false
                if let failure { error = failure.localizedDescription }
                refresh()
            }
        }
#endif
    }
}

private struct DroidPermissionSettings: View {
    @ObservedObject var voice: DroidVoiceController
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button(action: voice.requestPermissions) {
            Label(voice.state == .requestingPermission ? "Requesting voice access…" : "Enable droid voice access", systemImage: "mic.fill")
                .frame(minHeight: 24)
        }.buttonStyle(MenuActionButtonStyle())
        .disabled(voice.state == .requestingPermission || voice.listening)
        .accessibilityIdentifier("Enable droid voice access")

        Text(voice.permissionStatus).font(.caption).foregroundStyle(FlightPalette.secondary)
            .accessibilityIdentifier("Droid permission status")
        Button(action: voice.toggle) {
            Label(voice.listening ? "Stop microphone test" : "Test microphone", systemImage: voice.listening ? "stop.circle" : "waveform")
                .frame(minHeight: 24)
        }.buttonStyle(MenuActionButtonStyle())
        .disabled(voice.state == .requestingPermission)
        .accessibilityIdentifier("Test droid microphone")
        
        Text(voice.status).font(.caption).textSelection(.enabled)
            .accessibilityIdentifier("Droid microphone test status")
        if voice.listening {
            ProgressView(value: Double(voice.inputLevel)).tint(.green)
                .accessibilityLabel("Microphone input level")
            Text("Speak to check the meter and transcript. If the meter stays empty, choose an input in System Settings → Sound → Input and check its volume. Speech recognition may use Apple’s online service if local recognition is unavailable.")
                .font(.caption).foregroundStyle(FlightPalette.secondary)
        }
        if voice.needsSettings {
            Button("Open system settings") {
#if os(iOS) && !targetEnvironment(macCatalyst)
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
#else
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") { openURL(url) }
#endif
            }.flightButtonGlass()
        }
    }
}
