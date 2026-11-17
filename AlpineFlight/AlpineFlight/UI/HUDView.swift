import SwiftUI

struct HUDView: View {
    @ObservedObject var engine: GameEngine
    var onOpenTools: () -> Void = {}
    var onOpenMap: () -> Void = {}
    var onOpenUniverse: () -> Void = {}
    var onOpenTrade: () -> Void = {}
    @State private var showCockpitDetails = false
    var body: some View {
        GeometryReader { geometry in
#if os(iOS) && !targetEnvironment(macCatalyst)
            MobileFlightHUD(engine: engine, onOpenTools: onOpenTools, onOpenMap: onOpenMap, onOpenUniverse:onOpenUniverse,onOpenTrade: onOpenTrade)
#else
            let compact = geometry.size.height < 500
            VStack(spacing: 12) {
            ScrollView(.vertical) {
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: compact ? 18 : 34) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STARFLIGHT").flightButtonGlow().font(FlightStyle.displayFont(compact ? 9 : 12)).textCase(.lowercase).tracking(2)
                        Text("\(engine.aircraftName.uppercased()) / \(engine.levelName.uppercased())").flightButtonGlow()
                            .font(.system(size: 7, weight: .medium, design: .monospaced)).tracking(1).opacity(0.9)
                    }.padding(.top, 5)
                    Spacer(minLength: 0)
                    FlightInstruments(engine: engine)
                    if engine.isRelaxedSpace && engine.hud.inSpace {
                        HyperspaceHUDButton(action:onOpenUniverse)
                        InstrumentButton(icon:"map",label:"Space map",action:onOpenMap)
                    }
                    ShipLightsHUDButton(engine:engine)
                    InstrumentButton(icon: "slider.horizontal.3", label: "Flight tools", action: onOpenTools)
                    InstrumentButton(icon: "pause.fill", label: "Pause flight") { engine.pause() }
                }
                UniverseFlightStrip(engine:engine)
                EmergencyFlightHUD(engine:engine).allowsHitTesting(engine.activeEmergency != nil)
                StoryFlightBadge(engine:engine)
                if engine.level.isFreeRoam && engine.cityJobs.active == nil && engine.bounty.contract == nil && engine.nearbyResidence == nil {
                    HStack(spacing: 10) {
                        Image(systemName: engine.hud.inHyperspace ? "light.beacon.max.fill" : engine.hud.inSpace ? "aqi.medium" : "sparkles").flightButtonGlow()
                            .foregroundStyle(.white)
                        if engine.hud.inHyperspace {
                            Text("HYPERSPACE").flightButtonGlow().font(FlightStyle.displayFont(9)).textCase(.lowercase).tracking(1.3)
                            Text(engine.hud.checkpointName.uppercased()).flightButtonGlow().foregroundStyle(.white)
                            Text(String(format: "%.1F SEC", engine.hud.hyperspaceRemaining)).flightButtonGlow().monospacedDigit().foregroundStyle(.white)
                        } else {
                            Text(engine.currentSurfacePlanet.map { $0.name.uppercased() + " · FREE ROAM" } ?? (engine.hud.inSpace ? engine.currentGalaxy.name.uppercased() : "FREE ROAM · \(engine.hud.freeRoamSector.uppercased())")).flightButtonGlow().tracking(1.3)
                                .accessibilityIdentifier(engine.hud.inSpace ? engine.currentGalaxy.name.uppercased() : "FREE ROAM")
                            Image(systemName: "location.north.fill").flightButtonGlow()
                                .rotationEffect(.radians(Double(engine.hud.checkpointBearing)))
                            Text(engine.hud.checkpointName.uppercased()).flightButtonGlow()
                            Text(engine.hud.checkpointDistanceLabel.uppercased()).flightButtonGlow().foregroundStyle(.white)
                            Text(String(format: "%.1f KM FLOWN", engine.hud.distance / 1000)).flightButtonGlow().foregroundStyle(.white)
                            if engine.hud.inSpace && engine.currentSurfacePlanet == nil {
                                Text("DESTROYED \(engine.hud.asteroidsDestroyed)").flightButtonGlow().foregroundStyle(.white)
                            }
                        }
                    }.font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(FlightStyle.ink.opacity(0.65), in: Capsule())
                    if !engine.hud.inSpace && !engine.hud.inHyperspace {
                        HStack(spacing: 7) {
                            ForEach(engine.hud.portals) { portal in
                                HStack(spacing: 4) {
                                    Circle().fill(portalColor(portal.id)).frame(width: 6, height: 6)
                                    Text(portal.name.uppercased()).flightButtonGlow()
                                    Text(String(format: "%.0F M", portal.distance)).flightButtonGlow().foregroundStyle(.white)
                                }
                                .padding(.horizontal, 7).padding(.vertical, 5)
                                .background(FlightStyle.ink.opacity(0.62), in: Capsule())
                            }
                        }.font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                } else if !engine.level.isFreeRoam {
                HStack(spacing: 10) {
                    Image(systemName: "location.north.fill").flightButtonGlow()
                        .rotationEffect(.radians(Double(engine.hud.checkpointBearing)))
                        .foregroundStyle(.white)
                    Text(engine.hud.checkpointName.uppercased()).flightButtonGlow().tracking(1.3)
                    Text(engine.hud.checkpointDistanceLabel.uppercased()).flightButtonGlow().foregroundStyle(.white)
                    Text("\(engine.hud.passed)/\(engine.gateCount)").flightButtonGlow().foregroundStyle(.white)
                    if let remaining = engine.hud.timeRemaining {
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 13)
                        Image(systemName: "timer").flightButtonGlow().foregroundStyle(remaining < 25 ? .red : FlightStyle.orange)
                        Text("DETONATION").flightButtonGlow().font(FlightStyle.displayFont(9)).textCase(.lowercase).foregroundStyle(.white)
                        Text(String(format: "%02d:%02d", Int(ceil(remaining)) / 60, Int(ceil(remaining)) % 60)).flightButtonGlow()
                            .monospacedDigit().foregroundStyle(.white)
                            .accessibilityIdentifier("Death Star countdown")
                        if engine.hud.pursuers > 0 {
                            Text("TIE PURSUIT \(engine.hud.pursuers)").flightButtonGlow().foregroundStyle(.white)
                        }
                    }
                }.font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(FlightStyle.ink.opacity(0.65), in: Capsule())
                if engine.level.isPodRace {
                    HStack(spacing: 12) {
                        Image(systemName: "flag.checkered").flightButtonGlow().font(.system(size: 17, weight: .black)).foregroundStyle(FlightStyle.orange)
                        Text(engine.racePositionTitle).flightButtonGlow().font(FlightStyle.displayFont(14)).textCase(.lowercase)
                            .contentTransition(.numericText()).accessibilityIdentifier("Race position")
                        Text("\(engine.hud.racePosition)/\(engine.hud.raceFieldSize)").flightButtonGlow().foregroundStyle(.white)
                        Text("LAP \(engine.hud.lap)/3").flightButtonGlow().foregroundStyle(.white)
                        RaceMiniMap(level: engine.level,
                                    playerProgress: engine.hud.racePlayerProgress,
                                    checkpointProgress: engine.hud.raceCheckpointProgress,
                                    rivalProgress: engine.hud.raceRivalProgress)
                            .frame(width: 92, height: 42)
                            .accessibilityLabel("Pod race circuit map")
                        Text(engine.hud.raceEnergyLabel).flightButtonGlow().font(FlightStyle.displayFont(9)).textCase(.lowercase)
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("Race energy status")
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.18))
                                Capsule().fill(FlightStyle.mint).frame(width: proxy.size.width * CGFloat(engine.hud.boostCharge) / 100)
                            }
                        }.frame(width: 92, height: 6)
                        Text("\(engine.hud.boostCharge)%").flightButtonGlow().monospacedDigit().foregroundStyle(.white)
                            .accessibilityLabel("Boost charge, \(engine.hud.boostCharge) percent")
                    }.font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.8)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(FlightStyle.ink.opacity(0.75), in: Capsule())
                }
                if engine.level == .deathStar {
                    let distance = engine.hud.scannerDistance
                    HStack(spacing: 8) {
                        Image(systemName: distance == nil ? "dot.radiowaves.left.and.right" : "dot.radiowaves.forward").flightButtonGlow()
                            .foregroundStyle(.blue)
                        Text(distance == nil ? "SCANNER · CLEAR" : "SCANNER · \(engine.hud.pursuers) SHIP\(engine.hud.pursuers == 1 ? "" : "S")").flightButtonGlow()
                        if let distance {
                            Text(String(format: "%.0f M", distance)).flightButtonGlow().foregroundStyle(.white)
                        }
                    }.font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background((distance == nil ? FlightStyle.ink : (distance ?? 0) < 110 ? Color.red.opacity(0.28) : FlightStyle.ink).opacity(0.75), in: Capsule())
                        .accessibilityIdentifier("Ship scanner")
                }
                }
                if engine.cameraMode == .cockpit {
                    HStack {
                        Button { showCockpitDetails.toggle() } label: {
                            Label(showCockpitDetails ? "Hide flight details" : "Flight details", systemImage: showCockpitDetails ? "chevron.up" : "gauge.with.dots.needle.33percent")
                        }.buttonStyle(MenuActionButtonStyle(expands: false))
                            .accessibilityIdentifier("Toggle cockpit details")
                        Spacer()
                    }
                }
                if engine.level.isFreeRoam && !engine.hud.inSpace && !engine.hud.inHyperspace && (engine.cameraMode != .cockpit || showCockpitDetails) {
                    FreeRoamConsole(engine: engine, compact: compact)
                }
                if engine.cameraMode == .cockpit && showCockpitDetails && engine.cityJobs.active == nil && engine.bounty.contract == nil && engine.nearbyResidence == nil {
                    CockpitSystems(engine: engine).frame(maxWidth: .infinity, alignment: .leading)
                }
                if let warning = engine.hud.warning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill").flightButtonGlow()
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.5)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color(red: 0.75, green: 0.2, blue: 0.11), in: Capsule())
                        .accessibilityIdentifier("Terrain warning")
                }
                if engine.settings.handControlEnabled && engine.hand.available {
                    HandSteeringStatus(hand: engine.hand)
                }
                if !engine.motionStatus.isEmpty {
                    Text(engine.motionStatus).flightButtonGlow().font(.caption2).padding(6).background(FlightStyle.ink.opacity(0.8), in: Capsule())
                }
                CityJobFlightControls(engine:engine)
                ResidenceFlightControls(engine:engine)
                Spacer()
                if !compact && engine.cameraMode != .cockpit {
                    HStack {
                        Text(engine.hud.inHyperspace ? "LIGHTSPEED TRANSIT · HOLD COURSE" : engine.currentSurfacePlanet != nil ? "\(engine.hud.clearance) M ABOVE GROUND" : engine.hud.inSpace ? (engine.isRelaxedSpace ? "EXPLORE THE PLANETS · CHOOSE A COURSE IN FLIGHT TOOLS" : "SHIELD \(engine.hud.shield)% · FIRE TO BREAK THE ATTACK WAVES") : "\(engine.hud.clearance) M ABOVE GROUND").flightButtonGlow()
                        Spacer()
                        Text(engine.weatherDescription).flightButtonGlow()
                    }.font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1.2)
                }
                HStack(spacing: 12) {
#if targetEnvironment(macCatalyst)
                    Text(engine.level.isPodRace ? "A/D STEER   SHIFT SKID   B BOOST   F FIRE   +/− THROTTLE   C CAMERA" : "W/S PITCH   A/D BANK   Q/E RUDDER   +/− THROTTLE   C CAMERA   SPACE PAUSE   R RESTART").flightButtonGlow()
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white).lineLimit(2)
#endif
                    Spacer(minLength: 0)
                    if engine.level.isFreeRoam {
                        MiningTradeHUDButton(engine: engine, action: onOpenTrade)
                    }
                }
            }.frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden).scrollBounceBehavior(.basedOnSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            TouchControls(engine: engine, compact: compact, availableWidth: geometry.size.width - (compact ? 36 : 60))
            }
            .padding(.horizontal, compact ? 18 : 30).padding(.top, 12).padding(.bottom, compact ? 10 : 24)
#endif
        }
        .foregroundStyle(.white)
        .overlay { WeaponFeedback(engine:engine) }
        .simultaneousGesture(SpatialTapGesture(coordinateSpace: .global).onEnded { value in
            engine.inspectUnobstructedSky(at: value.location)
        })
    }

    private func instrument(_ title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).flightButtonGlow().font(FlightStyle.displayFont(8)).textCase(.lowercase).tracking(1.5).opacity(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).flightButtonGlow().font(.system(size: 27, weight: .light, design: .monospaced)).monospacedDigit()
                Text(unit).flightButtonGlow().font(.system(size: 9, weight: .medium, design: .monospaced)).opacity(0.9)
            }
        }.shadow(color: .black.opacity(0.3), radius: 3)
    }

    private func portalColor(_ id: Int) -> Color {
        switch id { case 0: return .cyan; case 1: return .purple; case 2: return .orange; default: return .green }

    }
}

private extension HUDSnapshot {
    var raceEnergyLabel: String {
        if raceBurst { return "TURBO" }
        if raceDriftCharge > 0 { return "DRIFT \(raceDriftCharge)%" }
        if raceDrafting { return "DRAFT" }
        return "BOOST"
    }

    var raceEnergySummary: String {
        raceEnergyLabel == "BOOST" ? "boost \(boostCharge)%" : raceEnergyLabel.lowercased()
    }

    var raceEnergyColor: Color {
        raceBurst || raceDriftCharge > 0 ? FlightStyle.orange : FlightStyle.mint
    }
}

private struct RaceMiniMap: View {
    let level: FlightLevel
    let playerProgress: Float
    let checkpointProgress: Float
    let rivalProgress: [Float]

    var body: some View {
        Canvas { context, size in
            let circuit = RaceCircuit(level: level)
            let samples = (0...96).map { circuit.point(at: Float($0) / 96 * circuit.length) }
            guard let minX = samples.map(\.x).min(), let maxX = samples.map(\.x).max(),
                  let minZ = samples.map(\.z).min(), let maxZ = samples.map(\.z).max() else { return }
            let padding: CGFloat = 4
            let width = max(maxX - minX, 1), depth = max(maxZ - minZ, 1)
            func map(_ point: SIMD3<Float>) -> CGPoint {
                CGPoint(x: padding + CGFloat((point.x - minX) / width) * (size.width - padding * 2),
                        y: padding + CGFloat((point.z - minZ) / depth) * (size.height - padding * 2))
            }
            func marker(progress: Float, color: Color, radius: CGFloat) {
                let center = map(circuit.point(at: progress * circuit.length))
                context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                     width: radius * 2, height: radius * 2)), with: .color(color))
            }
            var track = Path()
            for (index, point) in samples.enumerated() {
                if index == 0 { track.move(to: map(point)) } else { track.addLine(to: map(point)) }
            }
            context.stroke(track, with: .color(.white.opacity(0.38)), lineWidth: 2)
            if circuit.hasShortcut {
                var branch = Path(); branch.move(to: map(circuit.shortcutPoint(0))); branch.addLine(to: map(circuit.shortcutPoint(1)))
                context.stroke(branch, with: .color(FlightPalette.cyan), style: StrokeStyle(lineWidth: 2, dash: [3,2]))
            }
            marker(progress: checkpointProgress, color: FlightStyle.orange, radius: 3.2)
            for progress in rivalProgress { marker(progress: progress, color: .red.opacity(0.85), radius: 2.1) }
            marker(progress: playerProgress, color: FlightStyle.mint, radius: 3.4)
        }
        .padding(2)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 7))
        .flightButtonGlow()
    }
}

struct CockpitOverlay: View {
    let hud: HUDSnapshot
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Path { path in
                    let w = proxy.size.width, h = proxy.size.height
                    path.move(to: CGPoint(x: w * 0.18, y: h))
                    path.addLine(to: CGPoint(x: w * 0.3, y: 0))
                    path.move(to: CGPoint(x: w * 0.82, y: h))
                    path.addLine(to: CGPoint(x: w * 0.7, y: 0))
                }.stroke(FlightStyle.ink.opacity(0.85), lineWidth: 10)
                VStack(spacing: 6) {
                    Rectangle().frame(width: 68, height: 1)
                    Image(systemName: "chevron.up").flightButtonGlow().font(.system(size: 17, weight: .light))
                    Rectangle().frame(width: 34, height: 1)
                }.foregroundStyle(.white)
                    .rotationEffect(.radians(Double(-hud.roll)))
                    .offset(y: CGFloat(hud.pitch) * 90)
                VStack { Spacer(); Rectangle().fill(FlightStyle.ink).frame(height: 20) }
            }
        }.flightButtonGlow().allowsHitTesting(false)
    }
}

private struct FreeRoamConsole: View {
    @ObservedObject var engine: GameEngine
    let compact: Bool
    @State var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FREE ROAM").font(.headline)
            Button("Go to hyperspace portals") { engine.navigateFreeRoam(to: .portals) }.flightButtonGlass().buttonStyle(GlowingFlightButton())
            Button("Space free roam") { engine.enterSpaceFreeRoam() }.flightButtonGlass().buttonStyle(GlowingFlightButton())
            Text("Explore freely or fly through a portal for an asteroid challenge.").font(.caption)
        }
        .padding(10).frame(maxWidth: compact ? 430 : 520, alignment: .leading)
        .flightSurfaceBackground(FlightStyle.ink.opacity(0.86), in: RoundedRectangle(cornerRadius: 12)).flightGlass(in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(.white)
    }
}

private struct CockpitSystems: View {
    @ObservedObject var engine: GameEngine
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("ENGINE \(Int(engine.throttle * 100))%")
                ProgressView(value: Double(engine.throttle)).tint(FlightStyle.orange).frame(width: 80)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("SHIELDS \(engine.hud.shield)%")
                ProgressView(value: Double(engine.hud.shield), total: 100).tint(.white).frame(width: 80)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(String(format: "V/S %+.1f M/S", engine.hud.verticalSpeed))
                Text(engine.hud.landed ? "LANDED" : engine.hud.clearance < 50 && !engine.hud.inSpace ? "LOW CLEARANCE" : "FLIGHT SYSTEMS READY")
                    .foregroundStyle(.white)
            }
        }.font(.system(size: 8, weight: .medium, design: .monospaced))
            .padding(8).flightSurfaceBackground(FlightStyle.ink.opacity(0.7), in: RoundedRectangle(cornerRadius: 8)).flightGlass(in: RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier("Cockpit systems")
    }
}

/// Essentials remain visible; secondary instruments and activity choices are opened on demand.
/// Status content has a bounded area; it cannot move the bottom flight controls.
private struct MobileFlightHUD: View {
    @ObservedObject var engine: GameEngine
    let onOpenTools: () -> Void
    let onOpenMap: () -> Void
    let onOpenUniverse: () -> Void
    let onOpenTrade: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 500
            let primaryUniverse=engine.galaxyJumpActive || engine.solarSystemActive || engine.currentSolarSurface != nil
            VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        FlightInstruments(engine: engine).frame(maxWidth: .infinity)
                        if engine.isRelaxedSpace && engine.hud.inSpace {
                            toolbarButton("map", label: "Space map", action: onOpenMap)
                        }
                        toolbarButton("slider.horizontal.3", label: "Flight tools", action: onOpenTools)
                        toolbarButton("pause.fill", label: "Pause flight") { engine.pause() }
                    }.padding(.horizontal, 8).frame(height: 50)
                        .flightSurfaceBackground(FlightStyle.ink.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                        .flightGlass(in: RoundedRectangle(cornerRadius: 12))
                    HStack(spacing: 8) {
                        if primaryUniverse {
                            UniverseFlightStrip(engine:engine).font(.caption).fixedSize(horizontal:false,vertical:true).layoutPriority(1)
                            Spacer(minLength:0)
                        } else if engine.cityJobs.active == nil && engine.bounty.contract == nil && engine.nearbyResidence == nil {
                            objective.frame(maxWidth: .infinity)
                        } else { Spacer(minLength: 0) }
                        if engine.isRelaxedSpace && engine.hud.inSpace {
                            HyperspaceHUDButton(action: onOpenUniverse)
                        }
                    }
                    ScrollView(.vertical) {
                        VStack(spacing: 6) {
                            if !primaryUniverse { UniverseFlightStrip(engine:engine) }
                            EmergencyFlightHUD(engine:engine).allowsHitTesting(engine.activeEmergency != nil)
                            StoryFlightBadge(engine:engine)
                            if let warning = engine.hud.warning {
                                Text(warning).font(.system(size: 11, weight: .bold)).lineLimit(2)
                                    .padding(7).background(.red.opacity(0.75), in: Capsule())
                                    .accessibilityIdentifier("Terrain warning")
                            }
                            CityJobFlightControls(engine:engine)
                            ResidenceFlightControls(engine:engine)
                        }.frame(maxWidth: .infinity)
                    }.scrollIndicators(.hidden).scrollBounceBehavior(.basedOnSize)
                    auxiliaryControls
                    TouchControls(engine: engine, compact: compact, availableWidth: geometry.size.width)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .foregroundStyle(.white).tint(.white)
    }

    private var objective: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.north.fill").rotationEffect(.radians(Double(engine.hud.checkpointBearing)))
            Text(engine.hud.checkpointName).lineLimit(1).truncationMode(.tail)
                .accessibilityIdentifier(engine.level.isFreeRoam ? "FREE ROAM" : "Flight objective")
            Text(engine.hud.checkpointDistanceLabel).monospacedDigit().fixedSize()
                .accessibilityIdentifier("Objective distance")
            if let remaining = engine.hud.timeRemaining {
                Text(String(format: "%02d:%02d", Int(ceil(remaining)) / 60, Int(ceil(remaining)) % 60))
                    .accessibilityIdentifier("Death Star countdown")
            }
            if engine.level.isPodRace {
                Text("\(engine.racePositionLabel) · lap \(engine.hud.lap)/3 · \(engine.hud.raceEnergySummary)")
                    .lineLimit(1).minimumScaleFactor(0.75).accessibilityIdentifier("Race position")
            }
        }.font(.system(size: 11, weight: .medium, design: .monospaced))
            .padding(.horizontal, 10).frame(minHeight: 44)
            .background(FlightStyle.ink.opacity(0.55), in: Capsule())
    }

    private var auxiliaryControls: some View {
        HStack(spacing: 8) {
            ShipLightsHUDButton(engine:engine)
            if engine.settings.handControlEnabled && engine.hand.available { HandSteeringStatus(hand: engine.hand) }
            if engine.hud.landed {
                Button("Take off") { engine.takeOffFreeRoam() }.flightButtonGlass().buttonStyle(GlowingFlightButton())
            } else if engine.hud.nearLandingPad && engine.level.isFreeRoam && !engine.hud.inSpace {
                Button(engine.hud.landingAssist ? "Assist on" : "Landing assist") { engine.toggleLandingAssist() }
                    .flightButtonGlass().buttonStyle(GlowingFlightButton()).accessibilityIdentifier("Landing assist")
            }
            Spacer(minLength: 0)
            if engine.level.isFreeRoam { MiningTradeHUDButton(engine: engine, action: onOpenTrade) }
            if engine.cameraMode == .cockpit {
                toolbarButton(engine.droidVoice.listening ? "mic.fill" : "mic", label: engine.droidVoice.listening ? "Stop droid voice control" : "Start droid voice control") { engine.toggleDroidVoice() }
            }
        }.frame(minHeight: 44)
    }

    private func toolbarButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 19)).frame(width: 24, height: 24)
                .flightButtonGlass().contentShape(Capsule())
        }.buttonStyle(.plain).fixedSize()
            .accessibilityLabel(label).accessibilityIdentifier(label)
    }
}

private struct HyperspaceHUDButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("HYPERSPACE", systemImage: "sparkles")
                .font(.system(size: 13, weight: .bold)).lineLimit(1)
                .foregroundStyle(FlightPalette.gold)
                .padding(.horizontal, 4).frame(height: 28)
                .flightButtonGlass().contentShape(Capsule())
        }
        .buttonStyle(.plain).fixedSize()
        .background(FlightStyle.ink.opacity(0.9), in: Capsule())
        .overlay(Capsule().stroke(FlightPalette.gold.opacity(0.65), lineWidth: 1))
        .accessibilityLabel("Hyperspace").accessibilityIdentifier("Hyperspace")
        .accessibilityHint("Opens galaxy destinations and five-second hyperspace travel.")
    }
}

/// Direct access to the existing console; presentation and pause lifetime belong to GameView.
private struct MiningTradeHUDButton: View {
    @ObservedObject var engine: GameEngine
    let action: () -> Void
    var body: some View {
        HStack(spacing: 8) {
        if engine.miningAvailable {
            Button(action: engine.scanOre) { Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 18)).frame(width: 24, height: 24) }
                .flightButtonGlass().accessibilityLabel("Scan asteroid ore").accessibilityIdentifier("Scan asteroid ore")
        }
        Button(action: action) {
            Label("Mining & Trade", systemImage: "shippingbox")
                .font(.system(size: 12, weight: .semibold)).textCase(nil)
                .foregroundStyle(FlightPalette.cyan).lineLimit(1)
                .frame(minHeight: 24)
                .flightButtonGlass()
                .contentShape(Capsule())
        }.buttonStyle(.plain)
            .accessibilityLabel("Mining & Trade")
            .accessibilityIdentifier("Mining & Trade")
            .accessibilityHint("Pauses flight and opens cargo, markets, and trade routes.")
        }
    }
}

/// A fixed-height horizontal strip keeps all instruments on the same baseline.
private struct FlightInstruments: View {
    @ObservedObject var engine: GameEngine
    @AppStorage("hiddenFlightInstruments") private var hidden = ""
    @State private var editing = false
    private let choices = ["Height above ground", "Airspeed", "Altitude above sea level", "Heading", "Climb or descent rate", "Throttle", "Shields", "Fuel remaining", "Mining cargo", "Credits balance", "Low flight score"]
    private func visible(_ label: String) -> Bool { !hidden.split(separator: "|").contains(Substring(label)) }
    private var noGround: Bool { (engine.hud.inSpace && !engine.hud.nearPlanetSurface) || engine.hud.inHyperspace }
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 16) {
            readout("GROUND CLEARANCE", noGround ? "—" : "\(engine.hud.clearance) m", label: "Height above ground",
                    color: noGround || engine.hud.landed || engine.aircraft.isPodracer ? FlightStyle.cream : engine.hud.clearance < 50 ? .red : engine.hud.clearance < 100 ? FlightStyle.orange : FlightPalette.teal)
            readout("AIRSPEED", "\(engine.hud.airspeed) kt", label: "Airspeed")
            if engine.cityJobs.active == nil && engine.bounty.contract == nil && engine.nearbyResidence == nil {
                readout("ALTITUDE", "\(engine.hud.altitude) m", label: "Altitude above sea level")
            }

            readout("HEADING", String(format: "%03d°", engine.hud.heading), label: "Heading")
            if engine.cameraMode != .cockpit && engine.cityJobs.active == nil && engine.bounty.contract == nil && engine.nearbyResidence == nil {
            readout("CLIMB / SINK", String(format: "%+.1f m/s", engine.hud.verticalSpeed), label: "Climb or descent rate")
            readout("THROTTLE", "\(Int((engine.throttle * 100).rounded()))%", label: "Throttle")
            }
            if engine.hud.pursuers > 0 || (engine.hud.inSpace && engine.currentSurfacePlanet == nil) || engine.level == .deathStar || engine.hud.shieldNeedsAttention {
                readout("SHIELD", "\(engine.hud.shield)%", label: "Shields",
                        color: engine.hud.shield <= 25 ? .red : engine.hud.shield < 60 ? FlightStyle.orange : FlightStyle.cream)
            }
            readout("FUEL",String(format:"%.1f%%",engine.hud.fuelPercent),label:"Fuel remaining",color:engine.hud.fuelPercent < 10 ? .red : engine.hud.fuelPercent < 20 ? FlightStyle.orange : FlightPalette.teal)
            if engine.isRelaxedSpace && engine.hud.inSpace { readout(engine.miningEnabled ? "MINING CARGO" : "CARGO", "\(engine.economy.trading?.used ?? 0)/\(SpaceTrading.capacity)",label:"Mining cargo",color:FlightPalette.cyan) }
            if engine.cameraMode != .cockpit && engine.cityJobs.active == nil && engine.bounty.contract == nil && engine.nearbyResidence == nil {
            readout("CREDITS",engine.economy.creditsLabel,label:"Credits balance",color:FlightPalette.gold)
            readout("LOW FLIGHT", "\(engine.hud.lowFlightPoints) pts", label: "Low flight score",color:FlightPalette.teal)
            }
            if choices.allSatisfy({ !visible($0) }) { Text("Hold to edit instruments").font(.caption).foregroundStyle(FlightPalette.gold) }
          }.fixedSize(horizontal: true, vertical: false).padding(.vertical, 6)
        }.frame(height: 46)
            .accessibilityIdentifier("Flight instruments")
            .contentShape(Rectangle())
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.6, maximumDistance: 24).onEnded { _ in openEditor() })
            .accessibilityAction(named: "Edit instruments") { openEditor() }
            .onDisappear { engine.editingFlightBanner = false }
            .sheet(isPresented: $editing, onDismiss: {
                engine.editingFlightBanner = false
            }) {
                NavigationStack {
                    Form {
                        Section("Visible instruments") {
                            ForEach(choices, id: \.self) { label in
                                Toggle(label, isOn: Binding(get: { visible(label) }, set: { enabled in
                                    var values = Set(hidden.split(separator: "|").map(String.init))
                                    if enabled { values.remove(label) } else { values.insert(label) }
                                    hidden = values.sorted().joined(separator: "|")
                                })).tint(FlightPalette.teal)
                            }
                        }
                        Section {
                            Button("Restore all instruments") { hidden = "" }
                            Text("Choices are saved on this device. Some instruments appear only when relevant to your flight. Terrain warnings remain enabled.").font(.caption)
                        }
                    }.navigationTitle("Edit flight banner")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { editing = false } } }
                }.preferredColorScheme(.dark)
            }

    }
    private func openEditor() {
        engine.editingFlightBanner = true
        engine.stick = .zero
        engine.rudder = 0
        engine.firing = false
        editing = true
    }
    @ViewBuilder
    private func readout(_ title: String, _ value: String, label: String, color: Color = FlightStyle.cream) -> some View {
        if visible(label) {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                if label == "Height above ground", !noGround, !engine.hud.landed, !engine.aircraft.isPodracer, engine.hud.clearance < 100 {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(color)
                }
                Text(title).foregroundStyle(.white)
            }.font(.system(size: 9, weight: .semibold))
            Text(value).font(.system(size: 15, weight: .medium, design: .monospaced))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.8).foregroundStyle(color)
        }.accessibilityElement(children: .ignore).accessibilityLabel(label)
            .accessibilityValue(value).accessibilityIdentifier(label)
        }
    }
}

private struct HandSteeringStatus: View {
    @ObservedObject var hand: HandController
    var body: some View {
        Button { hand.recenter() } label: {
            Label(hand.status, systemImage: "hand.raised.fill")
                .font(.system(size: 10, weight: .medium)).lineLimit(1)
                .padding(8).frame(minHeight: 44)
                .background(FlightStyle.ink.opacity(0.65), in: Capsule())
        }.flightButtonGlass().accessibilityLabel("Recenter hand steering").accessibilityValue(hand.status)
    }
}

private enum CityToolsDestination: Hashable {
    case jobs, map, career, homes, factions
    case contracts(CityJobKind)
}

struct FlightToolsView: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var cityPath: [CityToolsDestination] = []
    var body: some View {
        NavigationStack(path:$cityPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if engine.universeAvailable {
                        NavigationLink("Galaxy map & hyperspace") { UniverseNavigationView(engine:engine) }
                            .buttonStyle(MenuActionButtonStyle(accent:FlightPalette.gold)).accessibilityIdentifier("Universe navigation")
                    }
                    if engine.currentSolarSurface?.name == "Earth" {
                        Button { engine.visitWildlifeLookout();dismiss() } label: {
                            Label("Earth wildlife lookout",systemImage:"pawprint.fill").frame(maxWidth:.infinity).padding(10)
                        }.flightButtonGlass().accessibilityIdentifier("Visit Earth wildlife lookout")
                        ViewThatFits(in:.horizontal) {
                        HStack(spacing:8) {
                            ForEach(EarthWildlife.ScenicStop.allCases,id:\.self) { stop in
                                Button { engine.visitEarthScenicStop(stop);dismiss() } label: {
                                    Label(stop.title,systemImage:stop == .river ? "water.waves":stop == .city ? "building.2":"sun.horizon")
                                        .frame(maxWidth:.infinity).padding(10)
                                }.flightButtonGlass().accessibilityIdentifier("Visit Earth "+stop.rawValue)
                            }
                        }
                        VStack(spacing:8) {
                            ForEach(EarthWildlife.ScenicStop.allCases,id:\.self) { stop in
                                Button(stop.title) { engine.visitEarthScenicStop(stop);dismiss() }
                                    .flightButtonGlass().accessibilityIdentifier("Visit Earth "+stop.rawValue)
                            }
                        }
                        }
                    }
                    if engine.level.isFreeRoam && engine.isRelaxedSpace && engine.homePlanetsAvailable {
                        HStack(spacing:12) {
                            Button { engine.visitWildlifeLookout();dismiss() } label: {
                                Label("Wildlife lookout",systemImage:"pawprint.fill").frame(maxWidth:.infinity).padding(10)
                            }.flightButtonGlass().accessibilityIdentifier("Visit wildlife lookout")
                            Button { engine.visitCanyonForks();dismiss() } label: {
                                Label("Canyon forks",systemImage:"arrow.triangle.branch").frame(maxWidth:.infinity).padding(10)
                            }.flightButtonGlass().accessibilityLabel("Explore canyon forks")
                        }
                    }
                    NavigationLink("Story campaign") { StoryCampaignView(engine:engine) }
                        .buttonStyle(MenuActionButtonStyle()).accessibilityIdentifier("Flight story campaign")
                    NavigationLink("Navigation & missions") { FlightAdventuresView(engine:engine) }
                        .buttonStyle(MenuActionButtonStyle()).accessibilityIdentifier("Navigation and missions")
                    Text("Flight paused while you use these tools.").font(.caption).foregroundStyle(.white)
                    if engine.canWatchReplay {
                        Button("Watch last 15 seconds") { engine.watchReplay(); dismiss() }.flightButtonGlass()
                    }
                    DisclosureGroup("Controls & flying tips") {
                        VStack(alignment:.leading,spacing:10) {
                            Text("1 · Steer gently. Hold A/D or Left/Right to bank and turn. Smaller joystick movements make gentler turns. Q/E turns the nose directly. The joystick dot shows your input; PITCH and BANK show the ship's actual attitude.")
                            Text(engine.settings.invertPitch ? "2 · Pitch is inverted: W/Up lowers the nose and S/Down raises it. On touch, drag up to climb." : "2 · W/Up raises the nose; S/Down lowers it. On touch, drag the stick down to climb, up to descend.")
                            Text("3 · Use +/− or the throttle slider for speed. Hold F or toggle Fire to shoot; C changes camera. Space pauses. Resume restores keyboard focus.")
                            Text("City jobs: follow the gold beacon. Approach assist slows you inside 1.1 km. Press Dock inside 450 m along a clear avenue, wait for service, then press Depart.")
                        }.font(.caption).padding(.vertical,8)
                    }.accessibilityIdentifier("Flight controls tutorial")
                    Text("\(engine.aircraftName) · \(engine.hud.altitude) m altitude · \(Int(engine.throttle*100))% throttle · \(engine.economy.creditsLabel) credits · \(engine.hud.lowFlightPoints) low-flight points")
                        .font(.caption).foregroundStyle(.white)
                 
                    if !engine.level.isFreeRoam {
                        Button("Return to space free roam") { engine.travelToSpace(); dismiss() }.flightButtonGlass()
                    }
                    if engine.level.isFreeRoam && engine.hud.inSpace {
                        if engine.isRelaxedSpace {
                            if let planet = engine.currentSurfacePlanet {
                                Text("\(planet.name) surface").font(.headline)
                                Text("Explore 24 km of terrain. Follow six lit scout beacons to earn points, or fly freely. Climb above \(Int(PlanetExploration(planet: planet).orbitAltitude)) m to return to orbit.").font(.caption)
                                if planet == .coruscant {
                                    Button("Coruscant jobs") { cityPath.append(.jobs) }.flightButtonGlass()
                                        .accessibilityIdentifier("Coruscant jobs")
                                    Button("Homes & interior shop") { cityPath.append(.homes) }.flightButtonGlass().accessibilityIdentifier("Coruscant homes")
                                    Button("Contacts & bounties") { cityPath.append(.factions) }.flightButtonGlass().accessibilityIdentifier("Coruscant factions")
                                    Button("Coruscant city map") { cityPath.append(.map) }.flightButtonGlass()
                                        .accessibilityIdentifier("Coruscant city map")
                                }
                                Button("Return to orbit") { engine.returnToPlanetOrbit(); dismiss() }.flightButtonGlass()
                            }
                            if engine.homePlanetsAvailable {
                            Text("Planet destinations").font(.headline)
                            ForEach(SpacePlanet.allCases) { planet in
                                let selected = engine.selectedSpacePlanet == planet
                                let distance = HUDSnapshot.distanceLabel(engine.distanceToPlanet(planet))
                                Button { engine.selectSpaceDestination(planet) } label: {
                                    HStack {
                                        Image(systemName: selected ? "checkmark.circle.fill" : "globe")
                                            .foregroundStyle(.white)
                                        Text(planet.name + " · " + planet.description)
                                        Spacer()
                                        Text(distance).monospacedDigit().foregroundStyle(.white)
                                    }.padding(10)
                                }.flightButtonGlass().buttonStyle(GlowingFlightButton())
                                    .accessibilityLabel("Navigate to " + planet.name)
                                    .accessibilityValue((selected ? "Selected · " : "") + distance)
                            }
                            ForEach(SpacePlanet.allCases) { planet in
                                Button("Enter " + planet.name) { engine.enterPlanetSurface(planet); dismiss() }
                                    .padding(10)
                                    .flightButtonGlass()
                            }
                            }
                            if engine.homePlanetsAvailable {
                            Button("Navigate to return portal") { engine.selectSpaceDestination(nil) }
                                .padding(10)
                                .flightButtonGlass()
                            Text("Follow the bearing and distance. Fly within 220 m of a planet to descend into its surface area, or choose Enter below.").font(.caption)
                            } else { Text("Use Galaxy map & hyperspace to explore this sector or return to the Milky Way home sector.").font(.caption).foregroundStyle(FlightPalette.cyan) }
                        } else {
                            Text("Switch to peaceful free roam to visit planets.").font(.caption)
                            Button("Space free roam") { engine.enterSpaceFreeRoam() }.flightButtonGlass()
                        }
                    }
                    if engine.level.isFreeRoam && !engine.hud.inSpace && !engine.hud.inHyperspace {
                        FreeRoamConsole(engine: engine, compact: false, expanded: true)
                    }
                    if engine.cameraMode != .cockpit || !engine.level.isFreeRoam || engine.hud.inSpace || engine.hud.inHyperspace {
                        CockpitSystems(engine: engine)
                    }
                    Text(engine.hud.nearPlanetSurface ? "\(engine.hud.clearance) m clear of planet surface" : engine.hud.inSpace || engine.hud.inHyperspace ? "Space flight · no ground beneath you" : "\(engine.hud.clearance) m above ground").font(.caption)
                    Text("Low-flight score: \(engine.hud.lowFlightPoints) points").font(.caption).monospacedDigit()
                    Text(engine.hud.activityStatus).font(.caption)
                    if !engine.hud.portals.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hyperspace destinations").font(.headline)
                            ForEach(engine.hud.portals) { portal in
                                Text("\(portal.name) · \(Int(portal.distance)) m")
                            }
                        }.font(.caption)
                    }
                    if engine.level.isPodRace {
                        Text("Cyan arches and the dashed cyan map line mark a narrow shortcut before the first checkpoint. Take the wider main track or cut through for two extra boost pads; all checkpoints are still required.")
                            .font(.caption).foregroundStyle(FlightPalette.cyan)
                    }
                    Text("Droid flight assistance").font(.headline)
                    Text("Current: " + engine.droidAssistMode.title).font(.caption).foregroundStyle(FlightPalette.teal)
                        .accessibilityIdentifier("Droid assist status")
                    Text("Hold climb input for a full loop. Left/right steering banks to turn, with a limited bank angle. Leave enough altitude. Assist uses normal flight controls; keep watching for obstacles.").font(.caption).foregroundStyle(FlightPalette.secondary)
                    ForEach(DroidAssistMode.allCases) { mode in
                        Button { engine.setDroidAssist(mode) } label: {
                            Label(mode.title, systemImage: engine.droidAssistMode == mode ? "checkmark.circle.fill" : "circle")
                        }.buttonStyle(MenuActionButtonStyle()).accessibilityIdentifier("Droid assist " + mode.rawValue)
                    }
                    Text("Droid: \(engine.settings.droid.name)").font(.headline)
                    Text(engine.droidMessage ?? engine.droidVoice.status).font(.caption)
                    Text("Use the microphone button during cockpit flight for voice commands.").font(.caption).foregroundStyle(.white)
                }.padding()
            }.background(FlightStyle.ink)
                .navigationTitle("Flight tools")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Resume") { dismiss() }.flightButtonGlass() } }
                .navigationDestination(for:CityToolsDestination.self) { destination in
                    switch destination {
                    case .jobs:
                        CityJobsView(engine:engine,onOpenMap:{ cityPath.append(.map) },
                                     onOpenCareer:{ cityPath.append(.career) },
                                     onOpenContracts:{ cityPath.append(.contracts($0)) })
                    case .homes: CityHomesView(engine:engine,onVisit:{ dismiss() })
                    case .factions: CityFactionBoard(engine:engine,onAccepted:{ dismiss() })
                    case .map: CityMapView(engine:engine)
                    case .career: CityCareerView(engine:engine)
                    case .contracts(let kind): CityContractsView(engine:engine,kind:kind,onAccepted:{ dismiss() })
                    }
                }
        }.preferredColorScheme(.dark).tint(.white)
    }
}


private struct ResidenceFlightControls:View {
    @ObservedObject var engine:GameEngine
    var body:some View {
        if let plot = engine.nearbyResidence,engine.cityJobs.active == nil,engine.bounty.contract == nil {
            VStack(spacing:6) {
                Text(plot.name).font(.subheadline.bold())
                if engine.homeLanding.landed {
                    Text("Parked on your landing terrace").font(.caption)
                    HStack {
                        Button("Enter home") { _ = engine.enterResidence() }.flightButtonGlass().buttonStyle(GlowingFlightButton()).accessibilityIdentifier("Enter landed home")
                        Button("Depart") { _ = engine.departResidence() }.flightButtonGlass().buttonStyle(GlowingFlightButton()).accessibilityIdentifier("Depart home")
                    }
                } else if engine.homeLanding.plot != nil {
                    Text(engine.homeLanding.phase == .departing ? "Lifting off · clearing the terrace":"Auto landing · aligning and descending").font(.caption).accessibilityIdentifier("Home autopilot status")
                } else {
                    HStack {
                        Image(systemName:"location.north.fill").rotationEffect(.radians(Double(engine.hud.checkpointBearing)))
                        Text("Landing terrace · \(HUDSnapshot.distanceLabel(HomeDocking.distance(to:plot,state:engine.state,aircraft:engine.aircraft))) away")
                    }.font(.caption)
                    Button("Land at home") { _ = engine.landAtResidence() }.flightButtonGlass().buttonStyle(GlowingFlightButton())
                        .disabled(!engine.canLandAtResidence).accessibilityIdentifier("Land at home")
                }
            }.padding(10).frame(maxWidth:540)
                .background(FlightStyle.ink.opacity(0.92),in:RoundedRectangle(cornerRadius:14))
                .accessibilityElement(children:.contain).accessibilityIdentifier("Home landing controls")
        }
    }
}

private struct CityJobFlightControls: View {
    @ObservedObject var engine:GameEngine
    var body: some View {
        if engine.currentSurfacePlanet == .coruscant {
            if let notice = engine.cityJobNotice {
                Text(notice).font(.system(size:11,weight:.semibold)).lineLimit(2)
                    .padding(8).background(FlightStyle.ink.opacity(0.8),in:RoundedRectangle(cornerRadius:10))
                    .accessibilityIdentifier("City job notice")
            }
            if let contract = engine.bounty.contract {
                VStack(spacing:5) {
                    Text("\(contract.name) · targets remaining: \(engine.bounty.remaining)").font(.subheadline.bold())
                    HStack {
                        Image(systemName:"location.north.fill").rotationEffect(.radians(Double(engine.hud.checkpointBearing)))
                        Text(engine.hud.checkpointDistanceLabel).monospacedDigit()
                        Text("Target shield \(Int(engine.bounty.targets.first?.health ?? 0))")
                    }.font(.caption)
                    Text("Climb to 1,000 m · follow the target marker · fire to disable shields").font(.caption)
                }.padding(10).background(FlightStyle.ink.opacity(0.9),in:RoundedRectangle(cornerRadius:14))
                    .accessibilityIdentifier("Active bounty HUD")
            }
            if engine.cityJobs.active != nil || engine.hud.cityDocked {
                VStack(spacing:6) {
                if engine.cityJobs.active != nil {
                    HStack(spacing:8) {
                        Image(systemName:"location.north.fill").rotationEffect(.radians(Double(engine.hud.checkpointBearing)))
                        Text(engine.cityJobs.status).lineLimit(1).truncationMode(.middle)
                        Text(engine.hud.checkpointDistanceLabel).monospacedDigit()
                    }.font(.system(size:11,weight:.semibold)).accessibilityIdentifier("City job objective")
                }
                HStack(spacing:10) {
                    Image(systemName:"briefcase.fill").foregroundStyle(FlightStyle.mint)
                    Text(engine.hud.cityJobDetail).font(.system(size:11,weight:.medium)).lineLimit(2)
                        .accessibilityIdentifier("City job status")
                    if engine.hud.cityCanDock {
                        Button("Dock") { _ = engine.dockAtCityJob() }.flightButtonGlass().buttonStyle(GlowingFlightButton())
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("Dock at city skyport")
                    }
                    if engine.hud.cityDepartReady {
                        Button("Depart") { engine.leaveCityDock() }.flightButtonGlass().buttonStyle(GlowingFlightButton())
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("Depart city skyport")
                    }
                }
                if engine.cityJobs.active != nil {
                    ProgressView(value:Double(engine.cityJobs.progress)).tint(.white)
                        .accessibilityLabel("Job route progress")
                    Text(engine.cityJobs.conditionFeedback).font(.system(size:10,weight:.medium))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("City flight condition")
                }
                }.padding(8).frame(maxWidth:620)
                    .background(FlightStyle.ink.opacity(0.8),in:RoundedRectangle(cornerRadius:10))
            }
        }
    }
}

private struct WeaponFeedback: View {
    @ObservedObject var engine:GameEngine
    var body:some View {
        VStack(spacing: 10) {
        if engine.oreScanVisible, let survey = engine.oreSurvey {
            Text("SCAN · " + survey.summary).font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(FlightPalette.mineral(survey.mineral.rarity))
                .padding(10).background(FlightStyle.ink.opacity(0.94), in: Capsule())
                .accessibilityIdentifier("Ore scan result").allowsHitTesting(false)
        }
        if engine.hud.weaponsActive || !engine.hud.weaponHit.isEmpty {
            VStack(spacing:5) {
                Image(systemName:engine.hud.weaponHit.isEmpty ? "scope" : "xmark")
                    .font(.system(size:28,weight:.light))
                if !engine.minedRewards.isEmpty && engine.hud.weaponHit.hasPrefix("+") {
                    ForEach(engine.minedRewards) { reward in
                        Text("+\(reward.quantity) \(reward.mineral.name) · \(reward.mineral.rarity.name)")
                            .foregroundStyle(FlightPalette.mineral(reward.mineral.rarity))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .padding(7).background(FlightStyle.ink.opacity(0.92), in: Capsule())
                    }
                } else {
                    Text(engine.hud.weaponHit.isEmpty ? "LASERS FIRING" : engine.hud.weaponHit)
                        .font(.system(size:9,weight:.bold,design:.monospaced))
                        .padding(4).background(FlightStyle.ink.opacity(0.75),in:Capsule())
                }
            }.foregroundStyle(.white)
                .accessibilityIdentifier("Weapon feedback").allowsHitTesting(false)
        }
        }
    }
}


private struct ShipLightsHUDButton:View {
    @ObservedObject var engine:GameEngine
    var body:some View {
        Button { engine.shipLightsEnabled.toggle() } label: {
            Label(engine.shipLightsEnabled ? "Lights off":"Lights on",systemImage:engine.shipLightsEnabled ? "flashlight.on.fill":"flashlight.off.fill")
                .font(.system(size:11,weight:.semibold)).foregroundStyle(engine.shipLightsEnabled ? FlightPalette.cyan:.white)
                .frame(minHeight:24).padding(.horizontal,4)
        }.flightButtonGlass().buttonStyle(.plain)
            .accessibilityLabel(engine.shipLightsEnabled ? "Lights off":"Lights on").accessibilityValue(engine.shipLightsEnabled ? "On":"Off")
            .accessibilityHint("Turns the outward-facing ship lights on or off, including in cockpit view.")
            .accessibilityIdentifier("Ship lights")
    }
}
