import SwiftUI

struct DroidVisionView: View {
    @ObservedObject var engine: GameEngine
    @ObservedObject private var voice: DroidVoiceController
    @State private var expanded = false

    init(engine: GameEngine) {
        self.engine = engine
        self.voice = engine.droidVoice
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Circle().fill(voice.listening ? .green : engine.settings.droid.tint).frame(width: 7, height: 7)
                Text("\(engine.settings.droid.name) OPTIC").flightButtonGlow().font(FlightStyle.displayFont(8)).textCase(.lowercase)
                Spacer()
                Button { expanded.toggle() } label: { Image(systemName: expanded ? "chevron.up" : "chevron.down") }.flightButtonGlass()
                    .frame(width:32,height:44).accessibilityLabel(expanded ? "Collapse droid display" : "Expand droid display")
                Button(action: engine.toggleDroidVoice) {
                    Image(systemName: voice.listening ? "waveform.circle.fill" : "mic.circle").flightButtonGlow()
                        .font(.title2)
                }.flightButtonGlass().frame(width: 44, height: 44).contentShape(Rectangle())
                    .buttonStyle(GlowingFlightButton()).accessibilityLabel(voice.listening ? "Stop droid voice control" : "Start droid voice control")
            }.font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            if expanded || voice.listening {
            GeometryReader { proxy in
                ZStack {
                    LinearGradient(colors: [.black, engine.settings.droid.tint.opacity(0.28)], startPoint: .top, endPoint: .bottom)
                    Path { path in
                        let y = proxy.size.height * (0.5 + CGFloat(engine.hud.pitch) * 0.22)
                        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }.stroke(FlightStyle.mint.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    Circle().stroke(FlightStyle.mint.opacity(0.8), lineWidth: 1).frame(width: 38, height: 38)
                    Image(systemName: "chevron.up").flightButtonGlow().foregroundStyle(FlightStyle.orange)
                        .offset(x: CGFloat(sin(engine.hud.checkpointBearing)) * proxy.size.width * 0.35)
                    VStack { Spacer(); HStack {
                        Text("ALT \(engine.hud.altitude)").flightButtonGlow()
                        Spacer()
                        Text("SPD \(engine.hud.airspeed)").flightButtonGlow()
                    }.padding(7) }.font(.system(size: 8, design: .monospaced)).foregroundStyle(.white)
                    VStack(spacing: 7) {
                        ForEach(0..<8, id: \.self) { _ in Rectangle().fill(.white.opacity(0.035)).frame(height: 1) }
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 8))
            }.frame(height: 105)
            }
            if voice.listening {
                ProgressView(value: Double(voice.inputLevel)).flightButtonGlow().tint(.white)
                    .accessibilityLabel("Microphone input level")
            }
            Text(engine.droidMessage ?? (engine.droidAssistMode == .off ? voice.status : engine.droidAssistMode.title.uppercased())).flightButtonGlow()
                .accessibilityIdentifier("Droid voice status")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.white).lineLimit(2).frame(minHeight: 20, alignment: .topLeading)
        }
        .padding(10).frame(width: 240)
        .flightSurfaceBackground(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 13)).flightGlass(in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(FlightStyle.mint.opacity(0.45)))
        .flightButtonGlow(prominent: true)
        .accessibilityElement(children: .contain).accessibilityLabel("Droid vision from \(engine.settings.droid.name)")
    }
}
