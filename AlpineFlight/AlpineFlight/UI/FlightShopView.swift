import SwiftUI

struct FlightShopView: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previewShip: AircraftType?
    @State private var revealCards: [BlueprintReward] = []
    @State private var showingReveal = false
    @State private var tab = 0
    @State private var receipt: String?
    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var spinToken: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    HStack {
                        Label(engine.economy.creditsLabel + " credits",systemImage:"sparkles").font(.title2.bold()).accessibilityIdentifier("Shop credits")
                        Spacer()
                    }
                    Text("Earn 0.25 credits per low-flight point. Four FLP = one credit. Fly 8–60 m above terrain at 88 kt (45 m/s) or faster; closer flying earns more, up to 18 FLP per second.")
                        .font(.subheadline).foregroundStyle(.white)
                    NavigationLink("Pilot profile & avatar outfitter") { PilotProfileView(engine:engine) }.flightButtonGlass().accessibilityIdentifier("Shop avatar outfitter")
                    NavigationLink("Mining & trade") { SpaceTradeView(engine:engine) }.flightButtonGlass().buttonStyle(GlowingFlightButton()).accessibilityIdentifier("Shop mining and trade")
                    NavigationLink("Skyline Estates & Interior Emporium") { CityHomesView(engine:engine) }.flightButtonGlass().buttonStyle(GlowingFlightButton()).accessibilityIdentifier("Shop homes")
                    Picker("Shop section",selection:$tab) {
                        Text("Packs").tag(0); Text("Daily spin").tag(1); Text("Blueprints").tag(2)
                    }.flightButtonGlass().pickerStyle(.segmented).accessibilityIdentifier("Shop section")
                    if tab == 0 { packs }
                    else if tab == 1 { wheel }
                    else { collection }
                    if let receipt { Text(receipt).padding().frame(maxWidth:.infinity,alignment:.leading).background(FlightStyle.mint.opacity(0.12),in:RoundedRectangle(cornerRadius:16)).accessibilityIdentifier("Shop receipt") }
                }.padding(20)
            }.background(FlightStyle.ink)
                .navigationTitle("Supply shop")
#if canImport(UIKit)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() }.flightButtonGlass().accessibilityIdentifier("Shop done") } }
        }.tint(.white).foregroundStyle(.white).preferredColorScheme(.dark)
            .task(id:spinToken) {
                guard spinToken != nil else { return }
                do { try await Task.sleep(for:.seconds(reduceMotion ? 0.2:3.2)) } catch { return }
                spinning = false; receipt = engine.economy.lastSpinReceipt
                presentBlueprints()
            }
            .sheet(isPresented:$showingReveal) {
                BlueprintRevealView(cards:revealCards,economy:engine.economy)
            }
            .sheet(item:$previewShip) { ship in
                NavigationStack {
                    ScrollView {
                        VStack(alignment:.leading,spacing:16) {
                            ShipModelPreview(ship:ship).frame(height:320)
                            Text(ship.rarity + " · " + ship.handling).font(.headline)
                            Text(ship.summary)
                            Text("Drag to rotate · Pinch to zoom").font(.caption).foregroundStyle(.white)
                            Text("\(engine.economy.count(for:ship)) / \(ship.blueprintRequirement) blueprints")
                            Text("Previewing a ship does not unlock it.").font(.caption).foregroundStyle(.white)
                        }.padding()
                    }.background(FlightStyle.ink).navigationTitle(ship.name)
                        .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { previewShip = nil }.flightButtonGlass().accessibilityIdentifier("Preview done") } }
                }.preferredColorScheme(.dark)
            }
    }
    private func presentBlueprints() {
        revealCards = engine.economy.lastBlueprintRewards ?? []
        showingReveal = !revealCards.isEmpty
    }
    private var packs: some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Build your next ship").font(.title2.bold())
            Text("Each card is one model blueprint. Collect the required model blueprints to unlock each ship. See Blueprints for all six ships and their requirements. Extra blueprints are saved for you to sell in Blueprints: Rare 50 credits, Epic 150, Legendary 900 each.").font(.subheadline)
            ForEach(BlueprintPack.allCases) { pack in
                VStack(alignment:.leading,spacing:12) {
                    Text(pack.name).font(.headline)
                    Text("\(pack.cards) blueprint cards · \(pack.cost) credits").font(.subheadline)
                    ForEach(AircraftType.blueprintFleet) { ship in
                        Text("\(ship.name) · \(ship.rarity) · \(pack.chance(for:ship),specifier:"%.1f")% per card").font(.caption).foregroundStyle(.white)
                    }
                    Button("Buy " + pack.name) {
                        if let result = engine.buyBlueprintPack(pack) {
                            receipt = result
                            presentBlueprints()
                        }
                    }.flightButtonGlass().buttonStyle(GlowingFlightButton())
                        .disabled(engine.economy.quarterCredits < pack.cost*4)
                        .accessibilityIdentifier("Buy \(pack.id) pack")
                }.padding().frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:18))
            }
            Text("Cards are random, independent draws and may repeat. All four packs show their exact per-card odds. More expensive packs improve advanced-ship odds; no pack guarantees a legendary or a complete ship.").font(.caption).foregroundStyle(.white)
        }
    }
    private var collection: some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Blueprint collection").font(.title2.bold())
            Text("Preview every blueprint ship here. Locked ships stay out of Flight planner until completed. Previously unlocked ships remain yours.").font(.subheadline)
            ForEach(AircraftType.blueprintFleet) { ship in
                let unlocked = engine.economy.unlocked(ship)
                VStack(alignment:.leading,spacing:10) {
                    Label(ship.name,systemImage:unlocked ? "checkmark.seal.fill":"lock.fill").font(.headline)
                    Text(ship.rarity + " · " + ship.handling).font(.caption).foregroundStyle(.white)
                    Text(unlocked && engine.economy.count(for:ship) < ship.blueprintRequirement ? "Owned · completed before the balance update" : "\(engine.economy.count(for:ship)) / \(ship.blueprintRequirement) blueprints").monospacedDigit()
                    ProgressView(value:engine.economy.unlocked(ship) ? 1 : Double(engine.economy.count(for:ship))/Double(ship.blueprintRequirement))
                    Button("Preview " + ship.name) { previewShip = ship }.flightButtonGlass().buttonStyle(GlowingFlightButton())
                    let extras = engine.economy.extras(for:ship)
                    Text("\(extras) spare · \(ship.blueprintSaleCredits) credits each").font(.subheadline).monospacedDigit()
                    Button("Sell extras") {
                        let sold = engine.sellExtraBlueprints(for:ship)
                        receipt = sold > 0 ? "Sold spare \(ship.name) blueprints for \(sold) credits." : "No spare blueprints to sell."
                    }.flightButtonGlass().buttonStyle(GlowingFlightButton()).disabled(extras == 0)
                        .accessibilityIdentifier("Sell extras \(ship.rawValue)")
                    if unlocked {
                        Text(ship.summary).font(.subheadline)
                        Button("Fly " + ship.name) { engine.selectAircraft(ship); dismiss() }.flightButtonGlass().buttonStyle(GlowingFlightButton())
                    }
                }.padding().frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:18))
                    .accessibilityElement(children:.contain).accessibilityIdentifier("blueprint-\(ship.rawValue)")
            }
        }
    }
    private var wheelAngle: Double { 360 / Double(DailyPrize.allCases.count) }
    private var wheel: some View {
        VStack(alignment:.center,spacing:16) {
            Text("Daily supply wheel").font(.title2.bold())
            Text("One free spin each UTC day. Each of the \(DailyPrize.allCases.count) prizes has an equal \(100 / DailyPrize.allCases.count)% chance. Your reward is saved immediately, even if you close the shop during the animation.").font(.subheadline).foregroundStyle(.white)
            ZStack(alignment:.top) {
                GeometryReader { geometry in
                    let side = geometry.size.width
                    ZStack {
                        ForEach(DailyPrize.allCases) { prize in
                            let index = Double(prize.rawValue)
                            WheelSlice(start:index*wheelAngle-90,end:(index+1)*wheelAngle-90)
                                .fill([Color.teal,.indigo,.purple,.blue][prize.rawValue%4])
                                .overlay(WheelSlice(start:index*wheelAngle-90,end:(index+1)*wheelAngle-90).stroke(.white.opacity(0.45),lineWidth:1))
                            Text(prize.wheelLabel).font(.system(size:side<320 ? 9:11,weight:.bold))
                                .rotationEffect(.degrees(index*wheelAngle+wheelAngle/2))
                                .offset(x:CGFloat(cos((index*wheelAngle+wheelAngle/2-90)*Double.pi/180))*side*0.32,y:CGFloat(sin((index*wheelAngle+wheelAngle/2-90)*Double.pi/180))*side*0.32)
                        }
                        Circle().fill(FlightStyle.ink).frame(width:42,height:42)
                    }.rotationEffect(.degrees(rotation))
                }.aspectRatio(1,contentMode:.fit)
                Image(systemName:"arrowtriangle.down.fill").font(.title).foregroundStyle(.yellow).offset(y:-9)
            }.frame(maxWidth:380).padding(.top,8).accessibilityLabel("Daily prize wheel")
            TimelineView(.periodic(from:.now,by:30)) { context in
                let available = engine.economy.canSpin(at:context.date)
                Button(available ? "Spin daily wheel" : "Come back after 00:00 UTC") {
                    guard let prize = engine.spinDailyWheel() else { return }
                    receipt = nil; spinning = true; spinToken = UUID()
                    let target = -(Double(prize.rawValue)+0.5)*wheelAngle
                    let delta = (target-rotation.truncatingRemainder(dividingBy:360)+720).truncatingRemainder(dividingBy:360)
                    withAnimation(reduceMotion ? nil : .easeOut(duration:3)) { rotation += 1800+delta }
                }.flightButtonGlass().buttonStyle(GlowingFlightButton()).disabled(!available || spinning).accessibilityIdentifier("Claim daily spin")
            }
            if !spinning && !engine.economy.lastSpinReceipt.isEmpty {
                Text("Last spin: " + engine.economy.lastSpinReceipt).font(.subheadline).accessibilityIdentifier("Last daily prize")
            }
            ForEach(DailyPrize.allCases) { Text($0.label).font(.caption).frame(maxWidth:.infinity,alignment:.leading) }
        }
    }
}

private struct WheelSlice: Shape {
    let start: Double
    let end: Double
    func path(in rect:CGRect) -> Path {
        var p = Path(); let center = CGPoint(x:rect.midX,y:rect.midY)
        p.move(to:center)
        p.addArc(center:center,radius:min(rect.width,rect.height)/2,startAngle:.degrees(start),endAngle:.degrees(end),clockwise:false)
        p.closeSubpath(); return p
    }
}


private func blueprintColor(_ ship: AircraftType) -> Color {
    ship.rarity == "Legendary" ? .yellow : ship.rarity == "Epic" ? .purple : .cyan
}

/// A reward presentation, never a source of rewards. The saved transaction is already complete.
private struct BlueprintRevealView: View {
    let cards: [BlueprintReward]
    let economy: FlightEconomy
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var revealed = false
    private var card: BlueprintReward { cards[index] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:18) {
                    Text("BLUEPRINT DISCOVERY").font(.caption.bold()).tracking(3)
                    Text("Card \(index+1) of \(cards.count)").font(.headline).monospacedDigit()
                    ZStack {
                        RoundedRectangle(cornerRadius:24).fill(FlightStyle.ink)
                        RoundedRectangle(cornerRadius:24).stroke(revealed ? blueprintColor(card.ship) : .cyan,lineWidth:3)
                        VStack(spacing:14) {
                            Image(systemName:"square.stack.3d.up.fill").font(.system(size:60))
                            Text("CLASSIFIED BLUEPRINT").font(.headline)
                            Text("Reveal your discovery").font(.subheadline)
                        }.opacity(revealed ? 0:1)
                            .rotation3DEffect(.degrees(revealed && !reduceMotion ? 180:0),axis:(x:0,y:1,z:0))
                        VStack(spacing:10) {
                            Text(card.ship.rarity.uppercased()).font(.headline).tracking(4).foregroundStyle(.white)
                            Text(card.ship.name).font(.title.bold()).multilineTextAlignment(.center)
                            Text((card.spareCount ?? 0) > 0 ? "+\(card.spareCount ?? 0) spare blueprint · saved to sell" : card.duplicateCredits > 0 ? "+\(card.duplicateCredits) duplicate credits" : "+\(card.collected) blueprint")
                            if card.unlockedNow { Text("SHIP UNLOCKED!").font(.headline).foregroundStyle(.white) }
                        }.padding().opacity(revealed ? 1:0)
                            .rotation3DEffect(.degrees(revealed || reduceMotion ? 0:-180),axis:(x:0,y:1,z:0))
                    }.frame(maxWidth:480).frame(height:200)
                        .shadow(color:revealed ? blueprintColor(card.ship).opacity(0.3):.clear,radius:18)
                        .accessibilityElement(children:.ignore)
                        .accessibilityLabel(revealed ? card.receipt : "Unrevealed blueprint card")
                    if revealed {
                        ShipModelPreview(ship:card.ship).id(card.id).frame(height:230)
                            .transition(.opacity)
                        Text(card.ship.summary).font(.subheadline).multilineTextAlignment(.center)
                        Text(economy.unlocked(card.ship) ? "Owned · ready in Flight planner" : "Collection: \(economy.count(for:card.ship)) / \(card.ship.blueprintRequirement)")
                            .font(.caption).foregroundStyle(.white)
                    }
                    Text("All rewards are already saved. You can close this reveal safely.")
                        .font(.caption).foregroundStyle(.white).multilineTextAlignment(.center)
                }.padding(24).frame(maxWidth:.infinity)
            }.background(FlightStyle.ink)
                .navigationTitle("Supply reveal")
#if canImport(UIKit)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Keep all") { dismiss() }.flightButtonGlass().accessibilityIdentifier("Keep blueprints") } }
                .safeAreaInset(edge:.bottom) {
                    Button(revealed ? (index == cards.count-1 ? "Finish" : "Next blueprint") : "Reveal blueprint") {
                        if !revealed {
                            withAnimation(reduceMotion ? .easeIn(duration:0.15) : .spring(response:0.65,dampingFraction:0.8)) { revealed = true }
                        } else if index < cards.count-1 { revealed = false; index += 1 }
                        else { dismiss() }
                    }.flightButtonGlass().font(.headline).buttonStyle(GlowingFlightButton()).tint(revealed ? blueprintColor(card.ship):.cyan)
                        .accessibilityIdentifier("Reveal next blueprint").padding().frame(maxWidth:.infinity).background(FlightStyle.ink)
                }
        }.foregroundStyle(.white).preferredColorScheme(.dark)
    }
}
