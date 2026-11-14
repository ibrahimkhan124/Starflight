import SwiftUI

struct CityHomesView: View {
    @ObservedObject var engine:GameEngine
    var onVisit:() -> Void = {}
    @State private var selected = CityPlot.aurora
    @State private var interior = false
    @State private var shoppingArea:HomeArea = .room
    @State private var confirmingHome = false
    @State private var receipt:String?
    init(engine:GameEngine,onVisit:@escaping () -> Void = {},initialPlot:CityPlot = .aurora) {
        self.engine = engine; self.onVisit = onVisit; _selected = State(initialValue:initialPlot)
    }
    private var housing:CityHousing { engine.economy.housing ?? CityHousing() }
    private var owned:Bool { housing.owned.contains(selected) }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                Text("Skyline Estates").font(.title2.bold())
                Text("Four cleared districts. Buy a plot and build its signature home, then furnish your private room. Ownership and interiors stay saved.")
                    .font(.subheadline).foregroundStyle(.white)
                Text(engine.economy.creditsLabel+" credits").font(.headline).foregroundStyle(.white)
                    .accessibilityIdentifier("Estate credits")
                ForEach(CityPlot.allCases) { plot in
                    Button { selected = plot; interior = false; receipt = nil } label: {
                        HStack(alignment:.top) {
                            VStack(alignment:.leading,spacing:5) {
                                Text(plot.name).font(.headline)
                                Text(plot.description).font(.caption).foregroundStyle(.white)
                                Text(housing.owned.contains(plot) ? "Owned · interior ready" : "Plot + home · \(plot.price) credits").font(.caption.bold())
                            }
                            Spacer()
                            Image(systemName:selected == plot ? "checkmark.circle.fill":"circle").foregroundStyle(FlightStyle.mint)
                        }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
                            .background(.white.opacity(selected == plot ? 0.09:0.035),in:RoundedRectangle(cornerRadius:14))
                    }.flightButtonGlass()
                        .buttonStyle(.plain).accessibilityIdentifier("Select estate " + plot.id)
                }
                Text(selected.name).font(.title3.bold())
                Picker("Home view",selection:$interior) {
                    Text("Exterior").tag(false); Text(shoppingArea == .room ? "Interior":"Terrace").tag(true)
                }.flightButtonGlass()
                    .pickerStyle(.segmented).accessibilityIdentifier("Estate preview mode")
                CityHomePreview(plot:selected,interior:interior,items:housing.items(in:selected),layout:housing.layout(in:selected),states:housing.states(in:selected),area:shoppingArea).frame(height:300)
                Text("Drag to rotate or look around · Pinch to zoom").font(.caption).foregroundStyle(.white)
                if !owned {
                    Text("Includes the cleared 1.5 km district, completed home, garden and landing terrace. Interior furnishings are sold separately.").font(.caption)
                    Button("Buy and build · \(selected.price) credits") { confirmingHome = true }
                        .foregroundStyle(FlightPalette.gold)
                        .flightButtonGlass()
                        .buttonStyle(.borderedProminent).disabled(engine.economy.quarterCredits < selected.price*4)
                        .accessibilityIdentifier("Buy selected estate")
                       
                    if engine.economy.quarterCredits < selected.price*4 { Text("Earn more credits from low flight, city jobs or bounties.").font(.caption).foregroundStyle(.white) }
                } else {
                    Text("Your residence · \(housing.items(in:selected).count) furnishings installed").font(.headline)
                    if engine.currentSurfacePlanet == .coruscant {
                        Button("Fly to this residence") { if engine.visitResidence(selected) { onVisit() } }
                            .flightButtonGlass()
                            .buttonStyle(.bordered).disabled(engine.cityJobs.active != nil || engine.bounty.contract != nil || engine.interiorHome != nil)
                            .accessibilityIdentifier("Visit selected estate")
                        Text("Arrive above the clear front avenue. Finish or cancel active work before transferring.").font(.caption).foregroundStyle(.white)
                    } else { Text("Enter Coruscant to fly to your residence. You can inspect and furnish it here at any time.").font(.caption).foregroundStyle(.white) }
                }
                Divider()
                if owned {
                    NavigationLink("Arrange room · move and rotate furnishings") { HomeArrangementView(engine:engine,plot:selected) }.flightButtonGlass()
                        .buttonStyle(.bordered).accessibilityIdentifier("Arrange selected home")
                    NavigationLink("Arrange terrace · outdoor furnishings") { HomeArrangementView(engine:engine,plot:selected,area:.terrace) }.flightButtonGlass()
                        .buttonStyle(.bordered).accessibilityIdentifier("Arrange selected terrace")
                }
                Text("Interior Emporium").font(.title2.bold()).accessibilityIdentifier("Interior Emporium")
                Picker("Furnishing area",selection:$shoppingArea) {
                    Text("Inside").tag(HomeArea.room); Text("Outside").tag(HomeArea.terrace)
                }.flightButtonGlass()
                    .pickerStyle(.segmented).accessibilityIdentifier("Furnishing area")
                Text("Items belong to this home. Remove or reinstall them for free. Land and enter to walk inside or visit the terrace; approach a furnishing to interact.").font(.caption).foregroundStyle(.white)
                ForEach(InteriorItem.allCases.filter { $0.area == shoppingArea }) { item in
                    furniture(item)
                }
                if let receipt { Text(receipt).font(.subheadline).foregroundStyle(.white).accessibilityIdentifier("Estate receipt") }
            }.padding(20).frame(maxWidth:820).frame(maxWidth:.infinity)
        }.background(FlightStyle.ink).foregroundStyle(.white).tint(.white)
            .navigationTitle("Homes & interiors").navigationBarTitleDisplayMode(.inline)
            .onChange(of:shoppingArea) { _,_ in interior = true }
            .confirmationDialog("Build \(selected.name)?",isPresented:$confirmingHome,titleVisibility:.visible) {
                Button("Buy for \(selected.price) credits") {
                    receipt = engine.buyResidence(selected) ? selected.name+" built · ownership saved" : "Purchase unavailable · check your balance"
                }.flightButtonGlass()
                Button("Cancel",role:.cancel) {}
                    .flightButtonGlass()
            } message: { Text("One-time purchase using earned game credits. No real money is charged.") }
    }
    private func furniture(_ item:InteriorItem) -> some View {
        let purchased = housing.owns(item,in:selected), installed = housing.items(in:selected).contains(item)
        return VStack(alignment:.leading,spacing:8) {
            Text(item.name).font(.headline)
            Text(item.detail).font(.caption).foregroundStyle(.white)
            Button(purchased ? (installed ? (item.area == .room ? "Remove from room":"Remove from terrace"):(item.area == .room ? "Install in room":"Install on terrace")) : "Buy · \(item.price) credits") {
                if purchased { receipt = engine.toggleResidenceItem(item,in:selected) ? (installed ? "Item stored · reinstall free":"Item installed") : "Not enough space · move other furniture first" }
                else { receipt = engine.buyResidenceItem(item,in:selected) ? item.name+" installed and saved":"Purchase unavailable · check ownership, credits and room space" }
                interior = true
            }.flightButtonGlass().buttonStyle(.bordered)
                .disabled(!owned || (!purchased && engine.economy.quarterCredits < item.price*4))
                .accessibilityIdentifier("Estate item " + item.id)
        }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
            .background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:12))
    }
}

struct CityFactionBoard: View {
    @ObservedObject var engine:GameEngine
    var onAccepted:() -> Void = {}
    @State private var selected = CityFaction.republic
    private var progress:CityFactionProgress { engine.economy.factions ?? CityFactionProgress() }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                Text("Contacts & bounties").font(.title2.bold())
                Text("Choose who to work for on each assignment. You can take work from every side; standing is tracked separately. Flight and job timers are paused here.").font(.subheadline).foregroundStyle(.white)
                ForEach(CityFaction.allCases) { faction in
                    Button { selected = faction } label: {
                        HStack { Text(faction.name); Spacer(); Text("\(progress.points(faction)) standing"); if selected == faction { Image(systemName:"checkmark.circle.fill") } }
                    }.flightButtonGlass().buttonStyle(.bordered).accessibilityIdentifier("Faction " + faction.id)
                }
                Text(selected.name).font(.headline)
                Text(selected.brief).font(.subheadline)
                Text(progress.rank(selected)).font(.caption.bold()).foregroundStyle(.white)
                if let contract = engine.bounty.contract {
                    Text("ACTIVE BOUNTY · \(contract.name) · \(engine.bounty.remaining) craft remaining").font(.headline)
                    Button("Cancel bounty",role:.destructive) { engine.cancelBounty() }.flightButtonGlass().buttonStyle(.bordered).accessibilityIdentifier("Cancel bounty")
                }
                if selected == .hunters {
                    ForEach(BountyContract.allCases) { job in bountyCard(job) }
                } else {
                    ForEach(CityContract.allCases.filter { $0.faction == selected }) { job in
                        VStack(alignment:.leading,spacing:10) {
                            Text(job.title).font(.headline); Text(job.brief).font(.subheadline)
                            Text(job.stops.map(\.name).joined(separator:" → ")).font(.caption)
                            Text("\(job.baseCredits) credits + up to \(job.maximumBonus) bonus · +10 standing").font(.caption.bold()).foregroundStyle(.white)
                            Text(job.timeLimit.map { "\(Int($0)/60) minute deadline" } ?? "Untimed · eight seconds per scan").font(.caption)
                            Button("Accept " + job.title) { engine.acceptCityContract(job); if engine.cityJobs.contract == job { onAccepted() } }.flightButtonGlass()
                                .buttonStyle(.borderedProminent).disabled(engine.cityJobs.active != nil || engine.bounty.contract != nil || engine.homeLanding.plot != nil)
                                .accessibilityIdentifier("Accept faction " + job.id)
                        }.padding().background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:14))
                    }
                }
                Text("Bounty navigation points to the nearest marked craft. Climb to about 1,000 m, line up your guns, and fire to disable its shield. Targets stay above the buildings and return slow, low-damage fire. Complete every target to collect a reward; cancelling, crashing or leaving Coruscant ends the assignment.").font(.caption).foregroundStyle(.white)
            }.padding(20).frame(maxWidth:820).frame(maxWidth:.infinity)
        }.background(FlightStyle.ink).foregroundStyle(.white).tint(.white)
            .navigationTitle("Contacts & bounties").navigationBarTitleDisplayMode(.inline)
    }
    private func bountyCard(_ job:BountyContract) -> some View {
        VStack(alignment:.leading,spacing:10) {
            Text(job.name).font(.headline); Text(job.description).font(.subheadline)
            Text("\(job.reward) credits · +10 Guild standing").font(.caption.bold()).foregroundStyle(.white)
            if progress.points(.hunters) < job.requiredStanding { Text("Requires \(job.requiredStanding) Guild standing").font(.caption) }
            Button("Track " + job.name) { if engine.acceptBounty(job) { onAccepted() } }.flightButtonGlass()
                .buttonStyle(.borderedProminent)
                .disabled(engine.cityJobs.active != nil || engine.bounty.contract != nil || engine.homeLanding.plot != nil || progress.points(.hunters)<job.requiredStanding)
                .accessibilityIdentifier("Accept bounty " + job.id)
        }.padding().background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:14))
    }
}
