import SwiftUI

struct SpaceTradeView: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var showRarityKey = false
    @State private var purchase: SpaceTradeRoute?
    private var hold: SpaceTrading { engine.economy.trading ?? SpaceTrading() }
    private var cargoBalance: AttributedString {
        var cargo = AttributedString("\(hold.used) / \(SpaceTrading.capacity) cargo units")
        cargo.foregroundColor = FlightPalette.cyan
        var credits = AttributedString(" · \(engine.economy.creditsLabel) credits")
        credits.foregroundColor = FlightPalette.gold
        cargo += credits
        return cargo
    }
    var body: some View {
        List {
            if let port = engine.tradingPort {
                Section((hold.canTrade(at: port) ? "Connected market · " : "Market · ") + port.name) {
                    Text("Cargo offer: \(hold.quote(at:port)) credits").font(.headline).foregroundStyle(FlightPalette.gold)
                    if let route = hold.requiredRoute(at: port) {
                        Label("Market connection required", systemImage: "lock.fill")
                            .font(.subheadline).foregroundStyle(FlightPalette.gold)
                        Button(route.cost == 0 ? "Open required route · Free" : "Open required route · \(route.cost) credits") {
                            if route.cost == 0 { engine.openTradeRoute(route) }
                            else { purchase = route }
                        }.buttonStyle(MenuActionButtonStyle(accent: FlightPalette.gold))
                            .disabled(engine.economy.quarterCredits < route.cost * 4)
                            .accessibilityIdentifier("Open required trade route")
                        Text(route.name + (engine.economy.quarterCredits < route.cost * 4 ? " · Earn more credits to open this market." : " · Connect this market to sell your cargo here."))
                            .font(.caption).foregroundStyle(FlightPalette.secondary)
                    }
                    Button("Sell all cargo at " + port.name) { engine.sellMiningCargo() }
                        .disabled(!hold.canTrade(at:port) || hold.used == 0)
                        .buttonStyle(MenuActionButtonStyle()).accessibilityIdentifier("Sell mining cargo")
                    Text(engine.tradeNotice + " Balance: " + engine.economy.creditsLabel + " credits.")
                        .font(.caption).foregroundStyle(FlightPalette.teal).accessibilityIdentifier("Market trade receipt")
                }
            }
            Section("Mining & cargo") {
                Text(cargoBalance).font(.headline).monospacedDigit()
                    .accessibilityIdentifier("Mining cargo balance")
                FlightSwitchRow("Mining mode",isOn:$engine.miningEnabled).tint(FlightPalette.teal).disabled(!engine.miningAvailable)
                    .accessibilityIdentifier("Mining mode")
                if !engine.miningAvailable {
                    Text(engine.currentSurfacePlanet.map { "Mining pauses on " + $0.name + ". Return to orbit to mine asteroids." } ?? "Enter Space free roam to mine asteroids.")
                        .font(.subheadline).foregroundStyle(FlightPalette.gold)
                        .accessibilityIdentifier("Mining availability guidance")
                }
                Text("In space free roam, enable Mining mode, resume and use MINE (or F). Break asteroids within 900 m to auto-collect 1–3 units. Cargo is saved immediately and survives a crash.")
                    .font(.caption).foregroundStyle(FlightPalette.secondary)
                if !engine.minedRewards.isEmpty {
                    ForEach(engine.minedRewards) { reward in
                        Text("+\(reward.quantity) \(reward.mineral.name) · \(reward.mineral.rarity.name)")
                            .foregroundStyle(FlightPalette.mineral(reward.mineral.rarity))
                    }
                }
                Text(engine.tradeNotice).foregroundStyle(FlightPalette.teal).accessibilityIdentifier("Trade receipt")
                if hold.routes.isEmpty {
                    Button("Open free Coruscant ↔ Tatooine route") { engine.openTradeRoute(SpaceTradeRoute.all[0]) }
                        .buttonStyle(MenuActionButtonStyle()).accessibilityIdentifier("Open starter trade route")
                }
                if let destination = hold.delivery?.destination {
                    Label("Active run: \(destination.name) · +20% on cargo sale",systemImage:"shippingbox.fill").foregroundStyle(FlightPalette.teal)
                }
            }
            Section("Planet markets") {
                Text("Open a route to access its two markets. Approach within 900 m of a planet’s surface in orbit, or enter it, then return here to sell. Set course, go back and Resume to fly there.")
                    .font(.caption).foregroundStyle(FlightPalette.secondary)
                ForEach(SpacePlanet.allCases) { planet in
                    VStack(alignment:.leading,spacing:8) {
                        HStack {
                            Text(planet.name).font(.headline)
                            Spacer()
                            Label(hold.canTrade(at:planet) ? "OPEN" : "LOCKED", systemImage: hold.canTrade(at:planet) ? "checkmark.circle.fill" : "lock.fill").font(.caption.bold()).foregroundStyle(hold.canTrade(at:planet) ? FlightPalette.teal : FlightPalette.secondary)
                        }
                        Text(premium(planet)).font(.caption).foregroundStyle(FlightPalette.secondary)
                        Text("Cargo offer: \(hold.quote(at:planet)) credits").font(.subheadline).foregroundStyle(FlightPalette.gold)
                        if engine.isRelaxedSpace {
                            Button("Set course for " + planet.name) { engine.selectSpaceDestination(planet) }
                                .buttonStyle(MenuActionButtonStyle()).accessibilityIdentifier("Trade course " + planet.rawValue)
                        }

                    }.padding(.vertical,6)
                }
            }
            Section("Open trade routes") {
                ForEach(SpaceTradeRoute.all) { route in
                    HStack {
                        VStack(alignment:.leading,spacing:4) {
                            Text(route.name).font(.headline)
                            Text(hold.routes.contains(route.id) ? "Route open · both markets connected" : route.cost == 0 ? "Starter route · free to open" : "Licence: \(route.cost) credits")
                                .font(.caption).foregroundStyle(FlightPalette.secondary)
                        }
                        Spacer()
                        if hold.routes.contains(route.id) {
                            if let port = engine.tradingPort, route.serves(port), hold.delivery == nil {
                                Button("Start run") { engine.beginTradeRun(route) }.buttonStyle(MenuActionButtonStyle())
                                    .accessibilityIdentifier("Start trade run " + route.id)
                            } else { Image(systemName:"checkmark.circle.fill").foregroundStyle(Color.cyan) }
                        }
                        else {
                            Button("Open route") { purchase = route }.buttonStyle(MenuActionButtonStyle())
                                .disabled(engine.economy.quarterCredits < route.cost*4)
                                .accessibilityIdentifier("Open route " + route.id)
                        }
                    }
                }
            }
            Section("Cargo manifest · \(hold.discovered.count)/\(TradeMineral.all.count) discovered") {
                if hold.used == 0 { Text("Cargo hold empty. Time to mine some asteroids.").foregroundStyle(FlightPalette.secondary) }
                ForEach(TradeMineral.all.filter { (hold.cargo[$0.id] ?? 0) > 0 }) { material in
                    HStack {
                        VStack(alignment:.leading) {
                            Text(material.name).foregroundStyle(FlightPalette.mineral(material.rarity))
                            Text(material.rarity.name).font(.caption).foregroundStyle(FlightPalette.mineral(material.rarity))
                        }
                        Spacer()
                        Text("×\(hold.cargo[material.id] ?? 0)").monospacedDigit().foregroundStyle(FlightPalette.cyan)
                    }
                }
            }
            Section("Material guide · \(TradeMineral.all.count) materials") {
                ForEach(MineralRarity.allCases,id:\.self) { rarity in
                    DisclosureGroup("\(rarity.name) · \(rarity.odds) per asteroid") {
                        Text("Equal chances for each material within this tier.").font(.caption).foregroundStyle(FlightPalette.secondary)
                        ForEach(TradeMineral.all.filter { $0.rarity == rarity }) { material in
                            HStack {
                                Text(material.name).foregroundStyle(FlightPalette.mineral(rarity))
                                Spacer()
                                Text("\(material.value) CR/unit").font(.caption).monospacedDigit().foregroundStyle(FlightPalette.gold)
                            }
                        }
                    }.tint(FlightPalette.mineral(rarity)).foregroundStyle(FlightPalette.mineral(rarity))
                }
                Text("Total sold: \(hold.sold) units · Completed runs: \(hold.deliveries ?? 0) · Trading revenue: \(hold.revenue) credits")
                    .font(.caption).foregroundStyle(FlightPalette.secondary)
            }
        }
        .sheet(isPresented: $showRarityKey) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 22) {
                            ForEach(MineralRarity.allCases, id: \.self) { rarity in
                                Label(rarity.name, systemImage: "diamond.fill")
                                    .font(.headline).foregroundStyle(FlightPalette.mineral(rarity))
                            }
                        }
                        Text("These colours identify minerals in collection messages and your cargo manifest. Each message also names the rarity.")
                            .font(.subheadline).foregroundStyle(FlightPalette.secondary)
                    }.padding(24)
                }.navigationTitle("Rarity colour key")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showRarityKey = false }.accessibilityIdentifier("Close mineral rarity key") } }
            }.preferredColorScheme(.dark).tint(FlightPalette.cyan)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showRarityKey = true } label: { Label("Rarity key", systemImage: "diamond.fill") }
                    .accessibilityIdentifier("Show mineral rarity key")
            }
            ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() }.buttonStyle(MenuActionButtonStyle(expands: false)).accessibilityIdentifier("Trade console done") } }
        .font(.body).textCase(nil)
        .navigationTitle("Mining & trade").tint(FlightPalette.cyan).preferredColorScheme(.dark)
        .confirmationDialog(purchase.map { "Open " + $0.name + "?" } ?? "Open route?",isPresented:Binding(get:{purchase != nil},set:{if !$0 { purchase = nil }}),titleVisibility:.visible) {
            if let route = purchase {
                Button(route.cost == 0 ? "Open free route" : "Pay \(route.cost) credits") { engine.openTradeRoute(route); purchase = nil }
                Button("Cancel",role:.cancel) { purchase = nil }
            }
        }
    }
    private func premium(_ planet: SpacePlanet) -> String {
        switch planet {
        case .coruscant: return "Industrial demand · metals +50%"
        case .tatooine: return "Desert supply · volatile ices +50%"
        case .hoth: return "Research demand · crystals +50%"
        case .endor: return "Forest exchange · organic materials +50%"
        }
    }
}
