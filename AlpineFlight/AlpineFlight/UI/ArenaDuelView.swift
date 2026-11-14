import SwiftUI

struct ArenaSetupView: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var difficulty = ArenaDifficulty.pilot
    @State private var format = ArenaFormat.duel
    var body: some View {
        NavigationStack {
            Form {
                Section("Battle format") {
                    Picker("Battle format",selection:$format) {
                        ForEach(ArenaFormat.allCases) { Text($0.rawValue).tag($0) }
                    }.flightButtonGlass().pickerStyle(.segmented).accessibilityIdentifier("Arena battle format")
                    Text(format == .duel ? "One-on-one against a TIE rival." : "Three ships: you against two TIE rivals. Defeat both to win. The target indicator automatically follows a nearby rival ahead of you.")
                }
                Section("Opponent skill") {
                    Text("Fight TIE opponents inside a holographic space arena. Break its shields before it breaks yours. Each duel lasts up to 2½ minutes. At the time limit, your shields are compared with the strongest surviving rival; higher shields wins, equal shields draws.")
                    Picker("Opponent skill",selection:$difficulty) {
                        ForEach(ArenaDifficulty.allCases) { Text($0.rawValue).tag($0) }
                    }.flightButtonGlass().pickerStyle(.segmented)
                    Text("Aim close to the rival for gentle aim assistance and more forgiving hits. The rival leads its shots, breaks away from incoming fire, and retreats to recover shields. Rookie fires less often; Ace reacts and attacks more strongly.").font(.callout).foregroundStyle(.white)
                }
                Section("Victory rewards") {
                    ForEach(ArenaDifficulty.allCases) { skill in
                        HStack {
                            Text(skill.rawValue)
                            Spacer()
                            Text("\(format.victoryReward(for:skill)) tokens").monospacedDigit()
                        }
                    }
                    Text("Tokens go into your existing shop credits. Wins pay once per match, including wins decided by shields. Losses, draws, and leaving early do not earn tokens.")
                        .font(.caption).foregroundStyle(.white)
                }
                Section("Your ship") {
                    Text(engine.aircraftName)
                    Text("Choose your ship in Flight planner before entering. Your existing weapons and ship handling are used; arena speed is capped for close combat. Fuel is free in the arena. Winning earns tokens for the shop.").font(.callout).foregroundStyle(.white)
                }
                Section("Controls") {
                    Text("Steer with the joystick, tilt or calibrated hand control. Use Fire to toggle your weapons. The target arrow points toward your rival; gain distance if you need your shields to recover.")
                    Text("Mac: W/S pitch · A/D bank · Q/E rudder · hold F to fire · Space to pause.").font(.caption)
                    Text("The boundary gently turns you back into the arena. No terrain or planet collisions.").font(.caption)
                    Button("Prepare duel") { engine.selectArena(difficulty,format:format); dismiss() }.flightButtonGlass()
                        .padding(10)
                        
                        .accessibilityIdentifier("Prepare arena duel")
                        
                }
            }
            .navigationTitle("Arena duels")
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() }.flightButtonGlass() } }
        }.preferredColorScheme(.dark).tint(.white)
    }
}

struct ArenaFlightHUD: View {
    @ObservedObject var engine: GameEngine
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 500
            VStack(spacing:compact ? 6:12) {
                ScrollView(.vertical) {
                VStack(spacing:compact ? 6:12) {
                HStack(spacing:16) {
                    shield("YOU",value:engine.arenaHUD.playerShield,color:FlightStyle.mint)
                    VStack(spacing:3) {
                        Text(engine.arenaFormat == .trio ? "TRIO BATTLE" : "ARENA DUEL").font(.system(size:11,weight:.bold))
                        Text(String(format:"%02d:%02d",Int(ceil(engine.arenaHUD.remaining))/60,Int(ceil(engine.arenaHUD.remaining))%60))
                            .font(.system(size:18,design:.monospaced)).accessibilityIdentifier("Duel timer")
                    }
                    VStack(spacing:5) {
                        ForEach(engine.arenaHUD.rivals) { rival in
                            shield(engine.arenaFormat == .trio ? "RIVAL \(rival.id+1)" : "RIVAL",value:rival.shield,color:FlightStyle.orange)
                        }
                    }
                    InstrumentButton(icon:"pause.fill",label:"Pause flight") { engine.pause() }
                }.padding(10).background(.black.opacity(0.7),in:RoundedRectangle(cornerRadius:14))
                HStack(spacing:10) {
                    Image(systemName:"location.north.fill").rotationEffect(.radians(Double(engine.arenaHUD.bearing)))
                    Text(String(format:"RIVAL \(engine.arenaHUD.targetNumber) · %.0f m · %@ %.0f°",engine.arenaHUD.range,engine.arenaHUD.elevation >= 0 ? "UP":"DOWN",abs(engine.arenaHUD.elevation)*180 / .pi))
                    Text(engine.arenaHUD.tactic.rawValue).foregroundStyle(.white)
                }.font(.system(size:compact ? 10:12,weight:.semibold,design:.monospaced))
                    .padding(7).background(.black.opacity(0.6),in:Capsule())
                if engine.arenaHUD.boundary {
                    Text("ARENA EDGE · TURN INWARD").font(.caption.bold()).foregroundStyle(.white)
                }
                }
                }.scrollIndicators(.hidden).scrollBounceBehavior(.basedOnSize)
                TouchControls(engine:engine, compact:compact, availableWidth:geometry.size.width - (compact ? 20:40))
            }.padding(compact ? 10:20)
            Image(systemName:"scope").font(.system(size:28,weight:.ultraLight)).opacity(0.65)
                .frame(maxWidth:.infinity,maxHeight:.infinity).allowsHitTesting(false)
            if engine.arenaHUD.countdown > 0 {
                VStack(spacing:8) {
                    Text("GET READY").font(.headline)
                    Text("\(Int(ceil(engine.arenaHUD.countdown)))").font(.system(size:64,weight:.bold,design:.rounded))
                }.frame(maxWidth:.infinity,maxHeight:.infinity).allowsHitTesting(false)
            }
        }
    }
    private func shield(_ title: String,value:Float,color:Color) -> some View {
        VStack(alignment:.leading,spacing:3) {
            Text("\(title) · \(Int(ceil(value)))% SHIELDS").font(.system(size:10,weight:.bold,design:.monospaced))
            ProgressView(value:Double(value),total:100).tint(color)
        }.frame(maxWidth:220)
    }
}

struct ArenaResultView: View {
    @ObservedObject var engine: GameEngine
    var body: some View {
        ScrollView {
        VStack(spacing:12) {
            Text(resultTitle).font(.title.bold()).accessibilityIdentifier("Duel result")
            Text("\(engine.arenaDifficulty.rawValue) rival · \(engine.arenaHUD.hits) confirmed hits")
            if engine.arenaHUD.endedOnTime {
                Text(engine.arenaHUD.outcome == .draw ? "Time’s up · shields tied" : "Time’s up · the ship with more shields wins")
                    .font(.callout).accessibilityIdentifier("Duel time decision")
            }
            Text(String(format:"Your shields %.1f%%",engine.arenaHUD.playerShield)).font(.callout)
            ForEach(engine.arenaHUD.rivals) { rival in
                Text(String(format:"Rival %d shields %.1f%%",rival.id+1,rival.shield)).font(.callout).foregroundStyle(.white)
            }
            Text(engine.arenaRewardEarned > 0 ? "+\(engine.arenaRewardEarned) tokens · added to shop credits" : "No tokens earned this match")
                .font(.headline).foregroundStyle(.white).accessibilityIdentifier("Arena reward receipt")
            Button("Rematch",action:engine.start).flightButtonGlass().buttonStyle(PrimaryFlightButton()).accessibilityIdentifier("Arena rematch")
            Button("Back to base",action:engine.returnToTitle).flightButtonGlass()
        }.padding(20)
        }.frame(maxWidth:500,maxHeight:440).modifier(FlightPanel()).padding()
    }
    private var resultTitle: String {
        guard engine.arenaFormat == .trio else { return engine.arenaHUD.outcome?.rawValue ?? "Duel complete" }
        switch engine.arenaHUD.outcome {
        case .victory: return "Trio battle won"
        case .defeat: return "Trio battle lost"
        case .draw: return "Trio battle drawn"
        case nil: return "Trio battle complete"
        }
    }
}
