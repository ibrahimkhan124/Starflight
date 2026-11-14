import SwiftUI

struct VirtualJoystick: View {
    let onChange: (SIMD2<Float>) -> Void
    var diameter: CGFloat = 124
    var externalInput: SIMD2<Float> = .zero
    @State private var displacement = CGSize.zero
    private var travel: CGFloat { diameter * 0.322 }

    var body: some View {
        ZStack {
            Circle().fill(.clear).flightSurfaceBackground(FlightStyle.ink.opacity(0.48), in: Circle())
            Circle().stroke(.white.opacity(0.25), lineWidth: 1)
            Circle().stroke(.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [3, 5])).padding(17)
            Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 90)
            Rectangle().fill(.white.opacity(0.12)).frame(width: 90, height: 1)
            Circle().fill(FlightStyle.cream.opacity(0.9)).frame(width: diameter * 0.35, height: diameter * 0.35)
                .shadow(color: .black.opacity(0.2), radius: 7, y: 3)
                .offset(displacement == .zero ? CGSize(width:CGFloat(externalInput.x)*travel,height:CGFloat(externalInput.y)*travel) : displacement)
        }
        .frame(width: diameter, height: diameter).contentShape(Circle())
        .flightGlass(in: Circle())
        .flightButtonGlow(prominent: true)
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { value in
                let x = value.translation.width, y = value.translation.height
                let length = max(travel, sqrt(x * x + y * y))
                displacement = CGSize(width: x / length * travel, height: y / length * travel)
                onChange([Float(x / length), Float(y / length)])
            }
            .onEnded { _ in displacement = .zero; onChange(.zero) })
        .onDisappear { displacement = .zero; onChange(.zero) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Flight joystick")
        .accessibilityHint("Drag down to climb, up to descend, left or right to bank.")
        .accessibilityIdentifier("Flight joystick")
    }
}

struct TouchControls: View {
    @ObservedObject var engine: GameEngine
    var compact = false
    var availableWidth: CGFloat = 1000
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var body: some View {
        let regular = horizontalSizeClass == .regular
#if os(iOS) && !targetEnvironment(macCatalyst)
        let joystickSize: CGFloat = compact ? min(120, max(92, availableWidth * 0.15)) : regular ? 138 : 110
        let throttleWidth: CGFloat = compact ? min(210, max(155, availableWidth * 0.25)) : regular ? 230 : 180
#else
        let joystickSize: CGFloat = regular ? 148 : 124
        let throttleWidth: CGFloat = regular ? 250 : 205
#endif
        let steeringLayout = availableWidth < 440 ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(alignment: .bottom, spacing: compact ? 8 : 14))
        HStack(alignment: .bottom, spacing: 12) {
            steeringLayout {
                VStack(spacing: 8) {
                    VirtualJoystick(onChange: { engine.stick = $0 }, diameter: joystickSize,externalInput:engine.hud.controlAxes)
                    Text(engine.level.isPodRace ? "STEER LEFT / RIGHT" : String(format:"PITCH %+.0f° · BANK %+.0f°",engine.hud.pitch*180 / .pi,engine.hud.roll*180 / .pi))
                        .font(.system(size:9,weight:.semibold,design:.monospaced)).monospacedDigit()
                        .accessibilityIdentifier("Flight attitude feedback")
                }
                HStack(spacing: 5) {
                    if engine.level.isPodRace { PodBoostButton(engine: engine); PodSkidButton(engine: engine) }
                    if !engine.level.isPodRace {
                        
                    } else {
                        Text("STEER + SKID").flightButtonGlow().font(FlightStyle.displayFont(8)).textCase(.lowercase).foregroundStyle(.white)
                    }
                }.padding(.bottom, availableWidth < 440 ? 0 : 22)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: compact ? 8 : 12) {
                HStack(spacing: 9) {
                    Button { engine.firing.toggle() } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "scope").font(.system(size: 19))
                            Text(engine.miningEnabled && engine.miningAvailable ? (engine.firing ? "MINE ON" : "MINE") : (engine.firing ? "FIRE ON" : "FIRE")).font(.system(size: 8, weight: .bold))
                        }.frame(width: compact ? 48 : 58, height: compact ? 44 : 54)
                            .foregroundStyle(engine.miningEnabled && engine.miningAvailable ? FlightPalette.cyan : engine.firing ? FlightStyle.orange : Color.white)
                            .flightSurfaceBackground(engine.firing ? FlightStyle.orange : FlightStyle.ink.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
                    }.flightButtonGlass().buttonStyle(GlowingFlightButton()).accessibilityLabel("Fire weapons")
                        .accessibilityValue(engine.firing ? "Firing" : "Off").accessibilityIdentifier("Fire weapons")
                    Button { engine.toggleCamera() } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "viewfinder").font(.system(size: 19))
                            Text("CAMERA").font(.system(size: 8, weight: .bold))
                        }.frame(width: compact ? 48 : 58, height: compact ? 44 : 54)
                            .flightSurfaceBackground(FlightStyle.ink.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
                    }.flightButtonGlass().buttonStyle(GlowingFlightButton()).accessibilityLabel("Switch camera").accessibilityIdentifier("Switch camera")
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("THROTTLE").flightButtonGlow().font(FlightStyle.displayFont(9)).textCase(.lowercase).tracking(1)
                        Spacer()
                        Text("\(Int(engine.throttle * 100))%").flightButtonGlow().monospacedDigit()
                    }.font(.system(size: 10, weight: .semibold, design: .monospaced))
                    if engine.canReverseThrust && !compact {
                        Button("STOP / HOVER · 0%") { engine.throttle = 0 }.font(.system(size:9,weight:.bold)).accessibilityIdentifier("Neutral throttle")
                    }
                    HStack(spacing: 4) {
                        Slider(value: $engine.throttle, in: (engine.canReverseThrust ? -1:0)...1)
                            .frame(minHeight: 44).tint(FlightStyle.mint)
                            .accessibilityLabel("Throttle").accessibilityIdentifier("Throttle")
                        if compact && engine.canReverseThrust {
                            Button { engine.throttle = 0 } label: {
                                Text("0%").font(.system(size: 11, weight: .bold)).frame(width: 24, height: 24)
                                    .flightButtonGlass().contentShape(Capsule())
                            }.buttonStyle(.plain)
                                .accessibilityLabel("Stop or hover at zero throttle").accessibilityIdentifier("Neutral throttle")
                        }
                    }
                    HStack { Text(engine.canReverseThrust ? "REVERSE":"IDLE").flightButtonGlow(); Spacer(); Text("FULL").flightButtonGlow() }
                        .font(FlightStyle.displayFont(8)).textCase(.lowercase).foregroundStyle(.white)
                }.padding(compact ? 8 : 10).frame(width: throttleWidth)
                    .flightSurfaceBackground(FlightStyle.ink.opacity(0.65), in: RoundedRectangle(cornerRadius: 15))
                    .flightGlass(in: RoundedRectangle(cornerRadius: 15))
                    .flightButtonGlow(prominent: true)
            }
        }
    }

    private func rudderButton(_ symbol: String, value: Float, label: String) -> some View {
        Image(systemName: symbol).flightButtonGlow().font(.system(size: 15))
            .frame(width: 44, height: 44).flightSurfaceBackground(FlightStyle.ink.opacity(0.5), in: Circle())
            .contentShape(Circle())
            .flightButtonGlow(prominent: true)
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in engine.rudder = value }.onEnded { _ in engine.rudder = 0 })
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
        .flightButtonGlass()
            .onDisappear { engine.rudder = 0 }
    }
}

private struct PodBoostButton: View {
    @ObservedObject var engine: GameEngine
    @State private var pressed = false

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: "bolt.fill").flightButtonGlow().font(.system(size: 16, weight: .bold))
            Text("BOOST").flightButtonGlow().font(FlightStyle.displayFont(7)).textCase(.lowercase).tracking(1)
        }
        .flightSurfaceForeground(pressed ? FlightStyle.cream : FlightStyle.mint, solid: pressed ? FlightStyle.ink : FlightStyle.mint)
        .frame(width: 48, height: 48)
        .flightSurfaceBackground(pressed ? FlightStyle.mint : FlightStyle.ink.opacity(0.72), in: Circle())
        .overlay(Circle().stroke(FlightStyle.mint.opacity(0.8), lineWidth: 1))
        .flightButtonGlow(prominent: true)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true; engine.boosting = true }
            .onEnded { _ in pressed = false; engine.boosting = false })
        .onDisappear { pressed = false; engine.boosting = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hold to boost")
        .accessibilityIdentifier("Hold to boost")
        .accessibilityAddTraits(.isButton)
        .flightButtonGlass()
        .accessibilityValue("\(pressed ? "Boosting" : "Ready"), \(engine.hud.boostCharge) percent charge")
        .accessibilityHint("Touch and hold for extra speed. With VoiceOver, double-tap to turn boost on or off.")
        .accessibilityAction { pressed.toggle(); engine.boosting = pressed }
    }
}

private struct PodSkidButton: View {
    @ObservedObject var engine: GameEngine
    @State private var pressed = false

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: "steeringwheel").flightButtonGlow().font(.system(size: 16, weight: .bold))
            Text("SKID").flightButtonGlow().font(FlightStyle.displayFont(7)).textCase(.lowercase).tracking(0.8)
        }
        .flightSurfaceForeground(pressed ? FlightStyle.cream : FlightStyle.orange, solid: pressed ? FlightStyle.ink : FlightStyle.orange)
        .frame(width: 48, height: 48)
        .flightSurfaceBackground(pressed ? FlightStyle.orange : FlightStyle.ink.opacity(0.72), in: Circle())
        .overlay(Circle().stroke(FlightStyle.orange.opacity(0.8), lineWidth: 1))
        .flightButtonGlow(prominent: true)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true; engine.skidding = true }
            .onEnded { _ in pressed = false; engine.skidding = false })
        .onDisappear { pressed = false; engine.skidding = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hold to skid")
        .accessibilityIdentifier("Hold to skid")
        .accessibilityAddTraits(.isButton)
        .flightButtonGlass()
        .accessibilityValue(pressed ? "Skidding" : "Ready")
        .accessibilityHint("Hold while steering to slide around tight turns. With VoiceOver, double-tap to turn skid on or off.")
        .accessibilityAction { pressed.toggle(); engine.skidding = pressed }
    }
}
