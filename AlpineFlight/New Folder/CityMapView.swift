import SwiftUI
import simd

/// Equal scale on both axes. World north (-Z) stays at the top of the chart.
struct CityChart {
    let center: SIMD2<Float>
    let span: Float
    init(pilot: SIMD3<Float>?) {
        let points = CityStation.allCases.map(\.position) + CityPlot.allCases.map(\.position) + (pilot.map { [$0] } ?? [])
        let low = SIMD2<Float>(points.map(\.x).min() ?? 0,points.map(\.z).min() ?? 0)
        let high = SIMD2<Float>(points.map(\.x).max() ?? 0,points.map(\.z).max() ?? 0)
        center = (low+high)/2
        span = max(high.x-low.x,high.y-low.y)+2200
    }
    func point(_ position: SIMD3<Float>) -> SIMD2<Float> {
        SIMD2<Float>(repeating:0.5)+(SIMD2<Float>(position.x,position.z)-center)/span
    }
}

struct CityRouteChart: View {
    let route: [CityStation]
    let completedStops: Int
    let pilot: SIMD3<Float>?
    var heading: Float = 0
    @Binding var selection: CityStation

    var body: some View {
        let chart = CityChart(pilot:pilot)
        GeometryReader { geometry in
            let side = min(geometry.size.width,geometry.size.height)
            ZStack {
                RoundedRectangle(cornerRadius:18).fill(.black.opacity(0.35))
                Canvas { context,size in
                    var grid = Path()
                    for index in 1..<8 {
                        let d = CGFloat(index)/8*side
                        grid.move(to:CGPoint(x:d,y:0)); grid.addLine(to:CGPoint(x:d,y:side))
                        grid.move(to:CGPoint(x:0,y:d)); grid.addLine(to:CGPoint(x:side,y:d))
                    }
                    context.stroke(grid,with:.color(.cyan.opacity(0.12)),lineWidth:1)
                    var buildings = Path()
                    for obstacle in PlanetExploration(planet:.coruscant).obstacles {
                        let p = chart.point(obstacle.center)
                        if p.x > 0 && p.x < 1 && p.y > 0 && p.y < 1 {
                            let w = CGFloat(obstacle.size.x/chart.span)*side
                            let h = CGFloat(obstacle.size.z/chart.span)*side
                            buildings.addRect(CGRect(x:CGFloat(p.x)*side-w/2,y:CGFloat(p.y)*side-h/2,width:w,height:h))
                        }
                    }
                    context.fill(buildings,with:.color(.gray.opacity(0.20)))
                    var line = Path()
                    for (index,station) in route.enumerated() {
                        let p = chart.point(station.position)
                        let point = CGPoint(x:CGFloat(p.x)*side,y:CGFloat(p.y)*side)
                        if index == 0 { line.move(to:point) } else { line.addLine(to:point) }
                    }
                    context.stroke(line,with:.color(FlightStyle.orange.opacity(0.8)),style:StrokeStyle(lineWidth:2,dash:[6,5]))
                    if let pilot, route.indices.contains(completedStops) {
                        let start = chart.point(pilot), end = chart.point(route[completedStops].position)
                        var course = Path()
                        course.move(to:CGPoint(x:CGFloat(start.x)*side,y:CGFloat(start.y)*side))
                        course.addLine(to:CGPoint(x:CGFloat(end.x)*side,y:CGFloat(end.y)*side))
                        context.stroke(course,with:.color(FlightStyle.mint.opacity(0.65)),style:StrokeStyle(lineWidth:1,dash:[2,5]))
                    }
                }.allowsHitTesting(false).accessibilityHidden(true)
                ForEach(CityStation.allCases) { station in
                    let p = chart.point(station.position)
                    let activeTarget = route.indices.contains(completedStops) && route[completedStops] == station
                    let stops = route.enumerated().filter { $0.element == station }.map { String($0.offset+1) }.joined(separator:"/")
                    Button { selection = station } label: {
                        VStack(spacing:3) {
                            ZStack {
                                Circle().fill(activeTarget ? FlightStyle.orange : FlightStyle.mint).frame(width:26,height:26)
                                if !stops.isEmpty { Text(stops).font(.system(size:9,weight:.bold)).foregroundStyle(.white) }
                            }.overlay(Circle().stroke(selection == station ? Color.white:Color.clear,lineWidth:2).padding(-4))
                            Text(shortName(station)).font(.system(size:10,weight:.semibold)).foregroundStyle(.white)
                                .padding(3).background(FlightStyle.ink.opacity(0.85),in:RoundedRectangle(cornerRadius:4))
                        }.padding(5)
                    }.flightButtonGlass().buttonStyle(.plain).position(x:CGFloat(p.x)*side,y:CGFloat(p.y)*side)
                        .accessibilityLabel(station.name)
                        .accessibilityValue(activeTarget ? "Next job stop" : selection == station ? "Selected" : "Skyport")
                        .accessibilityIdentifier("City map station " + station.rawValue)
                }
                ForEach(CityPlot.allCases) { plot in
                    let p = chart.point(plot.position)
                    VStack(spacing:2) {
                        Image(systemName:"house.fill").font(.system(size:14)).foregroundStyle(.purple)
                        Text("Estate \(plot.index+1)").font(.system(size:8,weight:.semibold)).foregroundStyle(.white)
                    }.position(x:CGFloat(p.x)*side,y:CGFloat(p.y)*side).allowsHitTesting(false)
                }
                if let pilot {
                    let p = chart.point(pilot)
                    Image(systemName:"location.north.fill").foregroundStyle(.white)
                        .rotationEffect(.radians(Double(heading)))
                        .shadow(color:.black,radius:2)
                        .position(x:CGFloat(p.x)*side,y:CGFloat(p.y)*side)
                        .allowsHitTesting(false).accessibilityLabel("Your ship on city map")
                }
                VStack { HStack { Text("↑ N"); Spacer(); Text(String(format:"%.1f km across",chart.span/1000)) }; Spacer() }
                    .font(.system(size:9,weight:.semibold,design:.monospaced)).foregroundStyle(.white)
                    .padding(10).allowsHitTesting(false)
            }.frame(width:side,height:side).frame(maxWidth:.infinity)
        }
    }

    private func shortName(_ station:CityStation) -> String {
        switch station { case .spaceport: return "Spaceport"; case .market: return "Market"; case .senate: return "Senate"; case .industrial: return "Industrial"; case .medical: return "Medical" }
    }
}

struct CityMapView: View {
    @ObservedObject var engine:GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var selected = CityStation.spaceport
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                Text("Coruscant city chart").font(.title2.bold()).accessibilityIdentifier("Coruscant city chart")
                Text("Flight and job timers are paused. Tap a skyport to inspect it; your job's stop order stays unchanged.")
                    .font(.subheadline).foregroundStyle(.white)
                CityRouteChart(route:engine.cityJobs.route,completedStops:engine.cityJobs.stage,pilot:engine.state.position,
                               heading:engine.state.heading,selection:$selected)
                    .frame(height:360)
                HStack(spacing:12) {
                    Label("Current stop",systemImage:"circle.fill").foregroundStyle(.white)
                    Label("Other skyport",systemImage:"circle.fill").foregroundStyle(.white)
                }.font(.caption)
                Text("Purple houses mark the four cleared residential districts. Buy and furnish a home in Homes & interior shop.").font(.caption).foregroundStyle(.white)
                Text("Dashed lines show stop order, not a clear flight corridor. Follow open avenues and use the gold beacon for the final approach. Gray footprints show structures; tall buildings may extend into your flight path.")
                    .font(.caption).foregroundStyle(.white)
                VStack(alignment:.leading,spacing:8) {
                    Text(selected.name).font(.headline)
                    Text("Skyport height 180 m · \(HUDSnapshot.distanceLabel(simd_distance(engine.state.position,selected.position))) from your ship")
                        .font(.subheadline).monospacedDigit().accessibilityIdentifier("City map station details")
                    if let target = engine.cityJobs.target {
                        Button("Show current job destination") { selected = target }.flightButtonGlass()
                            .buttonStyle(.bordered).accessibilityIdentifier("Show city job destination")
                        Text("Next: " + target.name).font(.caption).foregroundStyle(.white)
                    } else { Text("Accept a contract in Coruscant jobs to display its route.").font(.caption) }
                }.padding().frame(maxWidth:.infinity,alignment:.leading)
                    .background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:14))
                ForEach(CityStation.allCases) { station in
                    Button { selected = station } label: {
                        HStack { Text(station.name); Spacer(); Text(HUDSnapshot.distanceLabel(simd_distance(engine.state.position,station.position))).monospacedDigit() }
                    }.flightButtonGlass().padding(.vertical,6)
                }
            }.padding(20).frame(maxWidth:760).frame(maxWidth:.infinity)
        }.background(FlightStyle.ink).foregroundStyle(.white).tint(.white)
            .navigationTitle("City map").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() }.flightButtonGlass().accessibilityIdentifier("City map done") } }
            .onAppear { selected = engine.cityJobs.target ?? .spaceport }
    }
}
