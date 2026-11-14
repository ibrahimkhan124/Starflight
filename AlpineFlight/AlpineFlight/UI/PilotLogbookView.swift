import SwiftUI
import Charts

struct PilotLogbookView: View {
    @ObservedObject var engine:GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var inspectedBadge: PilotAchievement?
    @State private var period:PilotChartPeriod = .days30
    @State private var anchor = Date()
    private var book:PilotLogbook { engine.pilotBook }
    private var eligible:[PilotFlightRecord] { book.rankedFlights }
    private var points:[PilotPerformancePoint] { book.performance(period:period,ending:anchor) }
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    NavigationLink("Pilot profile & avatar") { PilotProfileView(engine:engine) }.flightButtonGlass().accessibilityIdentifier("Pilot profile")
                    HStack {
                        Label(book.latestReview?.rank.rawValue ?? "Provisional pilot",systemImage:"rosette").font(.title2.bold())
                        Spacer()
                        Text("\(book.awards.count)/\(PilotAchievement.allCases.count) awards").font(.caption)
                    }
                    Text(String(format:"%.1f km flown · %d review flights",book.progress(.km20000,draft:engine.pilotDraft),eligible.count))
                        .font(.subheadline).monospacedDigit().accessibilityIdentifier("Pilot career totals")
                    Text("\(book.flights.count) sessions saved, including practice and interrupted sessions").font(.caption).foregroundStyle(.white)
                        .accessibilityIdentifier("Pilot saved flights")
                    if engine.pilotDraft != nil { Text("Current flight is in progress. Return to base, finish the route or crash to record its outcome.").font(.caption).foregroundStyle(.white) }
                    Picker("Pilot section",selection:$tab) {
                        Text("Achievements").tag(0); Text("Pilot rank").tag(1); Text("Progress graph").tag(2)
                    }.flightButtonGlass().pickerStyle(.segmented).accessibilityIdentifier("Pilot section")
                    if tab == 0 { achievements }
                    else if tab == 1 { rank }
                    else { graph }
                    Text("Saved on this device. Tracking begins with this update; earlier flight distances and manoeuvres cannot be reconstructed. No account or Game Center sign-in is required.")
                        .font(.caption).foregroundStyle(.white)
                }.padding(20)
            }.background(FlightStyle.ink)
                .navigationTitle("Pilot logbook")
#if canImport(UIKit)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() }.flightButtonGlass().accessibilityIdentifier("Pilot logbook done") } }
        }.tint(.white).foregroundStyle(.white).preferredColorScheme(.dark)
            .onAppear { engine.refreshPilotProgress() }
            .sheet(item: $inspectedBadge) { achievement in
                AchievementBadgeInspector(achievement: achievement, unlocked: book.awards[achievement.rawValue] != nil)
            }
    }
    private var achievements:some View {
        VStack(alignment:.leading,spacing:12) {
            ForEach(PilotAchievement.allCases) { achievement in
                let date = book.awards[achievement.rawValue]
                let progress = min(achievement.target,book.progress(achievement,draft:engine.pilotDraft))
                VStack(alignment:.leading,spacing:8) {
                    Button { inspectedBadge = achievement } label: {
                        AchievementBadgeArt(achievement: achievement, unlocked: date != nil)
                    }.buttonStyle(.plain).accessibilityLabel("Inspect " + achievement.title).accessibilityIdentifier("Inspect badge " + achievement.rawValue)
                    Label(achievement.title,systemImage:date == nil ? "lock.fill":"checkmark.seal.fill")
                        .font(.headline).foregroundStyle(.white)
                    Text(achievement.detail).font(.subheadline)
                    if let date {
                        Text("Well done! Unlocked \(date.formatted(date:.abbreviated,time:.omitted))").font(.caption).foregroundStyle(.white)
                    } else {
                        ProgressView(value:progress,total:achievement.target)
                        Text(String(format:"%.1f / %.0f",progress,achievement.target)).font(.caption).monospacedDigit()
                    }
                }.padding().frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:16))
                    .accessibilityElement(children:.contain).accessibilityIdentifier("Achievement \(achievement.rawValue)")
            }
        }
    }
    private var rank:some View {
        VStack(alignment:.leading,spacing:16) {
            if let review = book.latestReview {
                Text(review.rank.rawValue).font(.largeTitle.bold()).accessibilityIdentifier("Official pilot rank")
                Text(String(format:"%.1f / 100 · review after flight %d",review.score,review.flightNumber)).monospacedDigit()
                Text("Reviewed \(review.date.formatted(date:.abbreviated,time:.omitted)) · \(review.crashes) crashes · \(review.closeShaves) recovered close shaves · \(review.turns) controlled turns · \(review.soars) soaring climbs").font(.subheadline)
            } else {
                Text("First review: \(eligible.count)/30 flights").font(.title2.bold()).accessibilityIdentifier("Pilot review progress")
                Text("Your official rank appears after 30 review-eligible flights. Until then, the graph still shows your flight scores.")
            }
            let remainder = eligible.count%30
            Text("Next review: \(remainder)/30 flights · \(30-remainder) to go").font(.headline)
            ProgressView(value:Double(remainder),total:30)
            DisclosureGroup("How ranking works") {
                VStack(alignment:.leading,spacing:10) {
                    Text("A review uses the latest block of 30 eligible flights. Your rank stays in place until the next 30-flight review.")
                    Text("A non-crash flight needs at least 60 active seconds and 1 km travelled. Completing a route in at least 15 seconds also qualifies. Every crash counts, including short ones. Pausing, loading and travel jumps never start another flight.")
                    Text("Each flight scores up to 100: 55 for avoiding a crash, up to 25 for avoiding stalls, and up to 20 for controlled manoeuvres. Stall time reduces control points; one fifth of the flight stalled removes all 25. Turns give 2 points, soaring climbs 3, and close shaves 1 each, capped at 2 close-shave points. A crash can score at most 45, so safety matters most.")
                    Text("Turns: bank smoothly through at least 90° over 3 seconds, at least 60 m above ground, and level your wings before another turn. Soaring: climb 100 m over at least 10 steady seconds, clear of terrain. Close shave: skim 8–25 m above ground for at least 0.25 seconds, then recover above 50 m for a second. Going below 8 m disqualifies that encounter; recoveries have a 20-second cooldown.")
                    Text("An interrupted session keeps its saved distance and achievements, but has no known outcome, so it does not affect rank or the graph.")
                    Text("Ranks: Cadet <40 · Wing pilot 40–59 · Flight officer 60–74 · Squadron leader 75–89 · Ace 90–96 · Flight legend 97–100.")
                }.font(.caption).padding(.top,8)
            }.accessibilityIdentifier("Ranking rules")
            if !book.reviews.isEmpty {
                Text("Review history").font(.headline)
                ForEach(book.reviews.reversed()) { review in
                    HStack { Text(review.date.formatted(date:.abbreviated,time:.omitted)); Spacer(); Text(review.rank.rawValue); Text(String(format:"%.1f",review.score)).monospacedDigit() }.font(.caption)
                }
            }
        }
    }
    private var graph:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Flight performance · 0–100").font(.title2.bold()).accessibilityIdentifier("Pilot chart title")
            Picker("Graph period",selection:$period) { ForEach(PilotChartPeriod.allCases) { Text($0.rawValue).tag($0) } }.flightButtonGlass()
                .pickerStyle(.segmented).accessibilityIdentifier("Pilot graph period")
            HStack {
                Button { shift(-1) } label: { Image(systemName:"chevron.left").frame(width:36,height:36) }.flightButtonGlass().accessibilityLabel("Previous graph period")
                Spacer()
                Text(periodTitle).font(.subheadline).monospacedDigit().accessibilityIdentifier("Pilot graph dates")
                Spacer()
                Button { shift(1) } label: { Image(systemName:"chevron.right").frame(width:36,height:36) }.flightButtonGlass()
                    .disabled(period.interval(ending:anchor,calendar:.current).end >= Date()).accessibilityLabel("Next graph period")
                Button("Today") { anchor = Date() }
                    .padding(10)
                    .flightButtonGlass()
            }
            if points.isEmpty {
                ContentUnavailableView("No flights in this period",systemImage:"chart.xyaxis.line",description:Text("Finish a review-eligible flight to begin your graph. Days without flights are not scored as zero."))
                    .frame(minHeight:220)
            } else {
                Chart {
                    ForEach(points) { point in
                        LineMark(x:.value("Date",point.date),y:.value("Average flight score",point.score))
                            .foregroundStyle(FlightStyle.mint).interpolationMethod(.linear)
                        PointMark(x:.value("Date",point.date),y:.value("Average flight score",point.score))
                            .foregroundStyle(FlightStyle.mint)
                            .accessibilityLabel(point.date.formatted(date:.abbreviated,time:.omitted))
                            .accessibilityValue(String(format:"%.1f points, %d flights",point.score,point.flights))
                    }
                    ForEach(book.chartReviews(period:period,ending:anchor)) { review in
                        PointMark(x:.value("Review date",review.date),y:.value("Official rank score",review.score))
                            .symbol(.diamond).symbolSize(65).foregroundStyle(.orange)
                            .accessibilityLabel("30-flight review · "+review.rank.rawValue)
                            .accessibilityValue(String(format:"%.1f points, after flight %d",review.score,review.flightNumber))
                    }
                }.chartYScale(domain:0...100)
                    .chartXScale(domain:period.interval(ending:anchor,calendar:.current).start...period.interval(ending:anchor,calendar:.current).end)
                    .chartXAxis { AxisMarks(values:.automatic(desiredCount:period == .year ? 6:5)) { _ in AxisGridLine(); AxisValueLabel(format:period == .year ? .dateTime.month(.abbreviated):.dateTime.day().month(.abbreviated)) } }
                    .frame(height:240).accessibilityIdentifier("Pilot performance chart")
                HStack {
                    Label(period == .year ? "Monthly averages":"Daily averages",systemImage:"circle.fill").foregroundStyle(.white)
                    Label("30-flight rank reviews",systemImage:"diamond.fill").foregroundStyle(.white)
                }.font(.caption)
                Text(period == .year ? "Monthly average of recorded flight scores. Only months with eligible flights have points." : "Daily average of recorded flight scores. Only days with eligible flights have points. Lines join the recorded averages.")
                    .font(.caption).foregroundStyle(.white)
                trend
            }
            Text("Recent flights").font(.headline)
            ForEach(book.chartFlights(period:period,ending:anchor).suffix(10).reversed()) { flight in
                VStack(alignment:.leading,spacing:3) {
                    HStack { Text(flight.endedAt.formatted(date:.abbreviated,time:.shortened)); Spacer(); Text(String(format:"%.0f/100",flight.score)).monospacedDigit() }
                    Text("\(flight.aircraft) · \(flight.outcome == .crashed ? "Crashed":"Returned safely") · \(flight.controlledTurns) turns · \(flight.soaringClimbs) climbs · \(flight.closeShaves) close shaves").foregroundStyle(.white)
                }.font(.caption)
            }
        }
    }
    @ViewBuilder private var trend:some View {
        let flights = book.chartFlights(period:period,ending:anchor)
        if flights.count >= 6 {
            let middle = flights.count/2
            let first = flights.prefix(middle), last = flights.suffix(flights.count-middle)
            let difference = last.reduce(0) { $0+$1.score }/Double(last.count)-first.reduce(0) { $0+$1.score }/Double(first.count)
            Text((difference > 2 ? "Improving" : difference < -2 ? "More practice will help":"Steady")+String(format:" · %+.1f points",difference))
                .font(.headline).accessibilityIdentifier("Pilot improvement trend")
            Text("Average score in the later half of this period compared with the earlier half (\(flights.count) flights). This compares game performance, not distance flown.").font(.caption).foregroundStyle(.white)
        } else { Text("Record at least six eligible flights in this period to compare your trend.").font(.caption) }
    }
    private var periodTitle:String {
        if period == .year { return anchor.formatted(.dateTime.year()) }
        if period == .month { return anchor.formatted(.dateTime.month(.wide).year()) }
        return "30 days to "+anchor.formatted(.dateTime.day().month(.abbreviated).year())
    }
    private func shift(_ direction:Int) {
        let component:Calendar.Component = period == .year ? .year : period == .month ? .month:.day
        if let date = Calendar.current.date(byAdding:component,value:direction*(period == .days30 ? 30:1),to:anchor) { anchor = min(date,Date()) }
    }
}
