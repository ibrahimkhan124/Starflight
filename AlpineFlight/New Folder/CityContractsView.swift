import SwiftUI

struct CityContractsView: View {
    @ObservedObject var engine:GameEngine
    let kind:CityJobKind
    var onAccepted:() -> Void = {}
    @State private var selected:CityContract
    @State private var mapSelection = CityStation.spaceport

    init(engine:GameEngine,kind:CityJobKind,onAccepted:@escaping () -> Void = {}) {
        self.engine = engine; self.kind = kind; self.onAccepted = onAccepted
        _selected = State(initialValue:.standard(for:kind))
    }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                Text(kind.title + " contracts").font(.title2.bold())
                Text("Choose a route. Work is paused while you compare contracts. Specialist assignments unlock through completed city jobs.")
                    .font(.subheadline).foregroundStyle(.white)
                ForEach(CityContract.allCases.filter { $0.kind == kind && $0.faction == nil }) { contract in
                    Button { selected = contract } label: {
                        HStack {
                            Image(systemName:selected == contract ? "checkmark.circle.fill" : "circle")
                            VStack(alignment:.leading,spacing:4) {
                                Text(contract.title).font(.headline)
                                Text("\(contract.stops.count) stops · \(contract.baseCredits) credits" + (contract.maximumBonus > 0 ? " · up to \(contract.maximumBonus) bonus" : ""))
                                    .font(.caption).foregroundStyle(.white)
                            }
                            Spacer()
                            if engine.economy.completedCityJobs < contract.requiredJobs {
                                Label("\(contract.requiredJobs) jobs",systemImage:"lock.fill").font(.caption)
                            }
                        }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
                            .background(selected == contract ? FlightStyle.mint.opacity(0.12) : .white.opacity(0.04),in:RoundedRectangle(cornerRadius:14))
                    }.flightButtonGlass()
                        .buttonStyle(.plain).accessibilityIdentifier("Preview city contract " + contract.id)
                        .accessibilityValue(selected == contract ? "Selected" : "")
                }
                VStack(alignment:.leading,spacing:12) {
                    Text(selected.title).font(.title3.bold())
                    Text(selected.brief).font(.subheadline)
                    HStack {
                        Text("\(selected.baseCredits) credits").foregroundStyle(.white)
                        Spacer()
                        Text(selected.timeLimit.map { "\(Int($0)/60) min limit" } ?? "Untimed")
                    }.font(.subheadline.bold())
                    Text("Route: " + selected.stops.map(\.name).joined(separator:" → "))
                        .font(.caption).accessibilityIdentifier("City contract route")
                    CityRouteChart(route:selected.stops,completedStops:0,pilot:nil,selection:$mapSelection)
                        .frame(height:280)
                    Text("Route distance between stops: \(String(format:"%.1f",selected.routeDistance/1000)) km. The trip from your current position to the first stop is additional.")
                        .font(.caption).foregroundStyle(.white)
                    if selected.maximumBonus > 0 {
                        Text(selected.kind == .patrol ? "Survey bonus: finish every scan and fly the route. Pausing or cancelling never generates a bonus." : "Quality bonus: finish with at least 95% condition after at least 20 seconds and 1 km of flight with your payload. Gentle banking and acceleration protect your load. The base reward is guaranteed for a completed contract.")
                            .font(.caption).foregroundStyle(.white)
                    }
                    if selected.requiredJobs > engine.economy.completedCityJobs {
                        Text("Locked · complete \(selected.requiredJobs-engine.economy.completedCityJobs) more city jobs.")
                            .font(.subheadline.bold()).foregroundStyle(.white)
                            .accessibilityIdentifier("City contract locked")
                    }
                    Button("Accept and fly · " + selected.title) {
                        engine.acceptCityContract(selected)
                        if engine.cityJobs.contract == selected { onAccepted() }
                    }.flightButtonGlass()
                        .buttonStyle(.borderedProminent).foregroundStyle(.white)
                        .disabled(engine.cityJobs.active != nil || engine.bounty.contract != nil || engine.homeLanding.plot != nil || engine.economy.completedCityJobs < selected.requiredJobs)
                        .accessibilityIdentifier("Accept selected city contract")
                    if engine.cityJobs.active != nil {
                        Text("Finish or cancel your active job before taking another contract.").font(.caption)
                    }
                }.padding(16).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:16))
            }.padding(20).frame(maxWidth:760).frame(maxWidth:.infinity)
        }.background(FlightStyle.ink).foregroundStyle(.white).tint(.white)
            .navigationTitle("Contracts").navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("City contracts scroll")
    }
}

struct CityCareerView: View {
    @ObservedObject var engine:GameEngine
    private var career:CityCareer { engine.economy.cityCareer ?? CityCareer() }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                CityCareerSummary(engine:engine)
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12) {
                    metric("\(career.passengers)","Passengers")
                    metric("\(career.deliveries)","Deliveries")
                    metric("\(career.patients)","Patients transferred")
                    metric("\(career.scans)","District scans")
                }
                Text("Career earnings: \(career.creditsEarned) credits · Average condition: \(career.averageCondition.map { "\($0)%" } ?? "No rated trips yet")")
                    .font(.caption).foregroundStyle(.white)
                Text("Recent completed work").font(.title3.bold())
                if career.recent.isEmpty {
                    Text("Complete a city job to receive your first debrief. Earlier jobs still count towards your licence; detailed ratings begin with this update.")
                        .font(.subheadline).foregroundStyle(.white)
                }
                ForEach(career.recent) { report in
                    CityJobDebrief(report:report)
                }
                Text("The last 20 debriefs are kept. Your total work and licence progress remain saved. Cancelling, crashing or leaving Coruscant does not complete a contract or charge a fee.")
                    .font(.caption).foregroundStyle(.white)
            }.padding(20).frame(maxWidth:760).frame(maxWidth:.infinity)
        }.background(FlightStyle.ink).foregroundStyle(.white).tint(.white)
            .navigationTitle("City career").navigationBarTitleDisplayMode(.inline)
    }
    private func metric(_ value:String,_ label:String) -> some View {
        VStack(alignment:.leading,spacing:5) { Text(value).font(.title2.monospacedDigit()); Text(label).font(.caption).foregroundStyle(.white) }
            .frame(maxWidth:.infinity,alignment:.leading).padding(14)
            .background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:12))
    }
}

struct CityCareerSummary: View {
    @ObservedObject var engine:GameEngine
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack { Image(systemName:"person.crop.circle.badge.checkmark"); Text(engine.economy.cityRank).font(.headline); Spacer() }
            Text("\(engine.economy.completedCityJobs) city jobs completed").font(.caption).accessibilityIdentifier("City career completed count")
            if let next = CityCareer.nextRank(completed:engine.economy.completedCityJobs) {
                ProgressView(value:Double(engine.economy.completedCityJobs),total:Double(next.jobs)).tint(.white)
                Text("\(next.jobs-engine.economy.completedCityJobs) more jobs to \(next.title)").font(.caption).foregroundStyle(.white)
            } else { Text("Master licence earned · all contracts available").font(.caption).foregroundStyle(.white) }
        }.padding(14).background(FlightStyle.mint.opacity(0.08),in:RoundedRectangle(cornerRadius:14))
            .accessibilityElement(children:.contain)
            .accessibilityIdentifier("City career summary")
    }
}

struct CityJobDebrief: View {
    let report:CityJobReport
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack { Text(report.contract.title).font(.headline); Spacer(); Text("+\(report.credits) cr").foregroundStyle(.white) }
            Text(report.summary).font(.subheadline)
            Text(report.contract.kind == .patrol ? "Survey complete" : String(repeating:"★",count:report.stars) + " · \(report.contract.conditionLabel) \(report.condition)%")
                .font(.caption.bold()).foregroundStyle(.white)
            Text(String(format:"%.1f km · %d:%02d",report.kilometres,Int(report.seconds)/60,Int(report.seconds)%60) + (report.bonusCredits > 0 ? " · \(report.bonusCredits) quality bonus" : ""))
                .font(.caption).monospacedDigit().foregroundStyle(.white)
            Text(report.completedAt.formatted(date:.abbreviated,time:.shortened)).font(.caption2).foregroundStyle(.white)
        }.padding(14).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:14))
            .accessibilityIdentifier("City job debrief")
    }
}
