import SwiftUI
import CoreText

enum FlightStyle {
    static let fontName = "StarJedi"

    // Register once at launch, never during a flight update or view redraw.
    static func registerFonts() {
        guard let url = Bundle.main.url(forResource: "Starjedi", withExtension: "ttf") else {
            assertionFailure("Missing bundled Star Jedi font")
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func displayFont(_ size: CGFloat) -> Font {
        // Pair with textCase(.lowercase): Star Jedi's capitals are alternate
        // joining glyphs; its lowercase characters draw the regular capitals.
        .custom(fontName, size: size, relativeTo: .headline)
    }

    static let cream = Color.white
    static let mint = Color(red: 0.156, green: 0.146, blue: 0.248)
    static let orange = Color(red: 1, green: 0.68, blue: 0.34)
    static let ink = Color(red: 0.055, green: 0.12, blue: 0.13)
    static let blue = Color(red:0.10, green:0.20, blue: 0.36)
}

struct FlightPanel: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(20)
            .flightSurfaceBackground(FlightStyle.ink.opacity(0.87), in: RoundedRectangle(cornerRadius: 22))
            .flightGlass(in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.13), lineWidth: 1))
            .flightButtonGlow(prominent: true)
    }
}

struct FlightButtonGlow: ViewModifier {
    @Environment(\.fullFlightGlow) private var fullGlow
    @Environment(\.flightGlowCovered) private var covered
    var prominent = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if covered {
            content
        } else if fullGlow {
            content.environment(\.flightGlowCovered, true)
                .shadow(color: .blue.opacity(0.6), radius: 5)
                .shadow(color: .pink.opacity(0.1), radius: 5)
                .shadow(color: .purple.opacity(0.4), radius: 5)
        } else if prominent {
            content.environment(\.flightGlowCovered, true)
                .shadow(color: Color(red: 0.42, green: 0.3, blue: 1).opacity(0.6), radius: 3)
        } else {
            content
        }
    }
}

private struct FullFlightGlowKey: EnvironmentKey { static let defaultValue = false }
private struct FlightGlowCoveredKey: EnvironmentKey { static let defaultValue = false }
private struct FlightGlassCoveredKey: EnvironmentKey { static let defaultValue = false }
private struct FlightButtonSurfaceCoveredKey: EnvironmentKey { static let defaultValue = false }

/// Apply padding once, even when a custom button style and its caller both opt in.
private struct FlightButtonSurface<S: Shape>: ViewModifier {
    let shape: S
    @Environment(\.flightButtonSurfaceCovered) private var covered
    @ViewBuilder func body(content: Content) -> some View {
        if covered {
            content
        } else if #available(iOS 26.0, macOS 26.0, *) {
            content.environment(\.flightButtonSurfaceCovered, true)
                .padding(10)
                .glassEffect(.clear.interactive(), in: shape)
        } else {
            content.environment(\.flightButtonSurfaceCovered, true)
                .padding(10)
                .background(FlightStyle.ink.opacity(0.85), in: shape)
        }
    }
}


private struct FlightGlass<S: Shape>: ViewModifier {
    @Environment(\.flightGlassCovered) private var covered
    let shape: S
    var interactive = false
    var tint: Color? = nil

    @ViewBuilder
    func body(content: Content) -> some View {
        if covered {
            content
        } else if #available(iOS 26.0, macOS 26.0, *) {
            content.environment(\.flightGlassCovered, true)
                .glassEffect(.clear.tint(tint).interactive(interactive), in: shape)
        } else {
            content
        }
    }
}

private struct FlightSurfaceBackground<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let color: Color
    let shape: S
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *), !reduceTransparency {
            // Keep a stable dark backing so white text stays legible over bright terrain.
            content.background(color.opacity(0.35), in: shape)
                .background(.black.opacity(0.55), in: shape)
        } else {
            content.background(color, in: shape)
        }
    }
}

private struct FlightSurfaceForeground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let glass: Color
    let solid: Color
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *), !reduceTransparency {
            content.foregroundStyle(.white)
        } else {
            content.foregroundStyle(.white)
        }
    }
}

extension EnvironmentValues {
    fileprivate var flightButtonSurfaceCovered: Bool {
        get { self[FlightButtonSurfaceCoveredKey.self] }
        set { self[FlightButtonSurfaceCoveredKey.self] = newValue }
    }
    fileprivate var flightGlassCovered: Bool {
        get { self[FlightGlassCoveredKey.self] }
        set { self[FlightGlassCoveredKey.self] = newValue }
    }
    var fullFlightGlow: Bool {
        get { self[FullFlightGlowKey.self] }
        set { self[FullFlightGlowKey.self] = newValue }
    }
    var flightGlowCovered: Bool {
        get { self[FlightGlowCoveredKey.self] }
        set { self[FlightGlowCoveredKey.self] = newValue }
    }
}

extension View {
    func flightButtonGlow(prominent: Bool = false) -> some View { modifier(FlightButtonGlow(prominent: prominent)) }
    func flightGlass<S: Shape>(in shape: S, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(FlightGlass(shape: shape, interactive: interactive, tint: tint))
    }
    func flightButtonGlass() -> some View { modifier(FlightButtonSurface(shape: Capsule())) }
    func flightButtonGlass<S: Shape>(in shape: S) -> some View { modifier(FlightButtonSurface(shape: shape)) }
    func flightSurfaceBackground<S: Shape>(_ color: Color, in shape: S) -> some View { modifier(FlightSurfaceBackground(color: color, shape: shape)) }
    func flightSurfaceForeground(_ glass: Color, solid: Color) -> some View { modifier(FlightSurfaceForeground(glass: glass, solid: solid)) }
}

struct GlowingFlightButton: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .flightButtonGlass()
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
            .flightButtonGlow(prominent: true)
    }
}

struct PrimaryFlightButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(FlightStyle.displayFont(13)).textCase(.lowercase)
            .lineLimit(1).minimumScaleFactor(0.7)
            .flightSurfaceForeground(.white, solid: .white)
            .frame(minHeight: 44)
            .flightSurfaceBackground(FlightStyle.mint.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
            .flightButtonGlass()
            .flightButtonGlow(prominent: true)
    }
}

struct InstrumentButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 17, weight: .medium))
                .frame(width: 46, height: 46)
                .flightSurfaceBackground(FlightStyle.ink.opacity(0.65), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.2)))
        }.flightButtonGlass()
        .buttonStyle(GlowingFlightButton()).accessibilityLabel(label).accessibilityIdentifier(label)
    }
}

/// Small, crisp depth offsets keep the original text layout and accessibility intact.
private struct RaisedTitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .white.opacity(0.55), radius: 0, x: -0.5, y: -0.5)
            .shadow(color: Color(red: 0.16, green: 0.23, blue: 0.34), radius: 0, x: 1, y: 1)
            .shadow(color: Color(red: 0.09, green: 0.14, blue: 0.24), radius: 0, x: 2, y: 2)
            .shadow(color: .black.opacity(0.8), radius: 0, x: 3, y: 3)
            .shadow(color: .black.opacity(0.4), radius: 3, x: 4, y: 5)
    }
}
extension View {
    func raisedTitle() -> some View { modifier(RaisedTitle()) }
}

/// Readable accents on the dark cockpit and menu surfaces.
enum FlightPalette {
    static let cyan = Color(red: 0.40, green: 0.85, blue: 1)
    static let teal = Color(red: 0.35, green: 0.91, blue: 0.72)
    static let violet = Color(red: 0.77, green: 0.67, blue: 1)
    static let gold = Color(red: 1, green: 0.81, blue: 0.37)
    static let secondary = Color(red: 0.73, green: 0.80, blue: 0.88)

    static func mineral(_ rarity: MineralRarity) -> Color {
        switch rarity {
        case .common: return secondary
        case .uncommon: return teal
        case .rare: return cyan
        case .epic: return violet
        case .legendary: return gold
        case .exotic: return Color(red: 1, green: 0.61, blue: 0.84)
        case .mythic: return Color(red: 1, green: 0.48, blue: 0.42)
        case .impossible: return Color(red: 0.88, green: 0.93, blue: 1)
        }
    }
}

/// One surface per action, with a consistent touch target and 10-point padding.
struct MenuActionButtonStyle: ButtonStyle {
    var accent: Color = FlightPalette.cyan
    var prominent = false
    var expands = true
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: prominent ? 16 : 13, weight: .semibold))
            .foregroundStyle(accent)
            .multilineTextAlignment(.center)
            .frame(maxWidth: expands ? .infinity : nil, minHeight: prominent ? 32 : 24)
            .padding(10)
            .background(FlightStyle.ink.opacity(prominent ? 0.92 : 0.72), in: RoundedRectangle(cornerRadius: 16))
            .flightGlass(in: RoundedRectangle(cornerRadius: 16), interactive: true)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(prominent ? 0.65 : 0.25), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A generous row-wide switch with native Toggle semantics for VoiceOver and Switch Control.
struct FlightSwitchRow: View {
    let title: String
    @Binding var isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }
    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 16) {
                Text(title).foregroundStyle(.primary)
                Spacer(minLength: 12)
                Text(isOn ? "On" : "Off").font(.caption).foregroundStyle(.secondary)
                ZStack(alignment: .leading) {
                    Capsule().fill(isOn ? FlightPalette.cyan : Color(white: 0.24))
                    Circle().fill(Color(red: 0.88, green: 0.93, blue: 0.98))
                        .frame(width: 26, height: 26)
                        .offset(x: isOn ? 30 : 4)
                }.frame(width: 60, height: 34)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isOn)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).opacity(enabled ? 1 : 0.45)
            .accessibilityRepresentation {
                Toggle(title, isOn: $isOn).accessibilityIdentifier(title)
            }
    }
}
