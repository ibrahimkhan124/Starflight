import SwiftUI
import simd

/// A north-up projection of real orbital X/Z positions, with equal scale on both axes.
struct SpaceChart {
    let center: SIMD2<Float>
    let span: Float
    init(pilot: SIMD3<Float>, portal: SIMD3<Float>) {
        let points = SpacePlanet.allCases.map(\.position)+[pilot,portal]
        let xs = points.map(\.x), zs = points.map(\.z)
        let low = SIMD2<Float>(xs.min() ?? 0,zs.min() ?? 0)
        let high = SIMD2<Float>(xs.max() ?? 0,zs.max() ?? 0)
        center = (low+high)/2
        span = max(high.x-low.x,high.y-low.y)+1400
    }
    func point(_ position: SIMD3<Float>) -> SIMD2<Float> {
        SIMD2<Float>(0.5,0.5)+(SIMD2<Float>(position.x,position.z)-center)/span
    }
}

/// Bearings use the same north = -Z and clockwise heading convention as flight.
struct SpaceCourse {
    let distance:Float
    let height:Float
    let headingDegrees:Float?
    let turnDegrees:Float?
    init(from pilot:SIMD3<Float>,to destination:SIMD3<Float>,heading:Float) {
        let delta = destination-pilot
        distance = simd_length(delta); height = delta.y
        if simd_length(SIMD2<Float>(delta.x,delta.z))<1 {
            headingDegrees = nil; turnDegrees = nil
        } else {
            let bearing = atan2(delta.x,-delta.z)
            headingDegrees = (bearing*180/Float.pi+360).truncatingRemainder(dividingBy:360)
            turnDegrees = atan2(sin(bearing-heading),cos(bearing-heading))*180/Float.pi
        }
    }
    var steering:String {
        guard let turnDegrees else { return "Horizontal position aligned" }
        if abs(turnDegrees)<5 { return "On course · keep this heading" }
        return String(format:"Turn %@ %.0f°",turnDegrees>0 ? "right":"left",abs(turnDegrees))
    }
    var altitude:String {
        if abs(height)<30 { return "Altitude aligned" }
        return String(format:"%@ %.0f m",height>0 ? "Climb":"Descend",abs(height))
    }
}

struct SpaceMapView: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var showGrid = true
    @State private var showTradeRoutes = true
    @State private var showPlannedRoute = true
    private var pilot: SIMD3<Float> { engine.currentSurfacePlanet?.position ?? engine.state.position }
    var body: some View {
        NavigationStack {
            if !engine.homePlanetsAvailable && engine.universeAvailable {
                UniverseNavigationView(engine:engine)
            } else {
            ScrollView {
                VStack(alignment:.leading,spacing:16) {
                    HStack {
                        Text("Space map").font(.title2.bold())
                        Spacer()
                        Text("↑ North").font(.caption.bold()).foregroundStyle(.white)
                    }
                    Menu {
                        Toggle("Grid",isOn:$showGrid)
                        Toggle("Open trade routes",isOn:$showTradeRoutes)
                        Toggle("Saved route stops",isOn:$showPlannedRoute)
                    } label: { Label("Map layers",systemImage:"square.3.layers.3d") }
                        .flightButtonGlass().accessibilityIdentifier("Space map layers")
                    NavigationLink("Galaxy map & hyperspace") { UniverseNavigationView(engine:engine) }
                        .buttonStyle(MenuActionButtonStyle(accent:FlightPalette.gold)).accessibilityIdentifier("Universe navigation")
                    Text("Starflight home-sector planets are fictional and schematically positioned.").font(.caption).foregroundStyle(FlightPalette.secondary)
                    Text("North is up · Tap a planet to set your navigation bearing. Flight is paused while the map is open.")
                        .font(.caption).foregroundStyle(.white)
                    let chart = SpaceChart(pilot:pilot,portal:engine.spaceReturnPortal)
                    let destination = engine.selectedSpacePlanet?.position ?? engine.spaceReturnPortal
                    let course = SpaceCourse(from:pilot,to:destination,heading:engine.state.heading)
                    GeometryReader { geometry in
                        let side = min(geometry.size.width,geometry.size.height)
                        ZStack {
                            RoundedRectangle(cornerRadius:20).fill(.black.opacity(0.35))
                            if showGrid {
                            Path { path in
                                for i in 1..<8 {
                                    let p = CGFloat(i)/8
                                    path.move(to:CGPoint(x:side*p,y:0)); path.addLine(to:CGPoint(x:side*p,y:side))
                                    path.move(to:CGPoint(x:0,y:side*p)); path.addLine(to:CGPoint(x:side,y:side*p))
                                }
                            }.stroke(.cyan.opacity(0.12),lineWidth:1)
                            }
                            if showTradeRoutes {
                                ForEach(SpaceTradeRoute.all.filter { engine.economy.trading?.routes.contains($0.id) == true }) { route in
                                    let a = chart.point(route.origin.position), b = chart.point(route.destination.position)
                                    Path { p in p.move(to:CGPoint(x:CGFloat(a.x)*side,y:CGFloat(a.y)*side)); p.addLine(to:CGPoint(x:CGFloat(b.x)*side,y:CGFloat(b.y)*side)) }
                                        .stroke(FlightPalette.gold.opacity(0.65),lineWidth:2).allowsHitTesting(false)
                                }
                            }
                            if showPlannedRoute && !engine.plannedRoutePlanets.isEmpty {
                                Path { path in
                                    let start = chart.point(pilot)
                                    path.move(to:CGPoint(x:CGFloat(start.x)*side,y:CGFloat(start.y)*side))
                                    for planet in engine.plannedRoutePlanets {
                                        let point = chart.point(planet.position)
                                        path.addLine(to:CGPoint(x:CGFloat(point.x)*side,y:CGFloat(point.y)*side))
                                    }
                                }.stroke(FlightPalette.cyan,style:StrokeStyle(lineWidth:3,dash:[3,4])).allowsHitTesting(false)
                            }
                            let start = chart.point(pilot), finish = chart.point(destination)
                            Path { path in
                                path.move(to:CGPoint(x:CGFloat(start.x)*side,y:CGFloat(start.y)*side))
                                path.addLine(to:CGPoint(x:CGFloat(finish.x)*side,y:CGFloat(finish.y)*side))
                            }.stroke(FlightStyle.mint.opacity(0.8),style:StrokeStyle(lineWidth:2,dash:[6,5]))
                                .allowsHitTesting(false).accessibilityHidden(true)
                            ForEach(SpacePlanet.allCases) { planet in
                                let p = chart.point(planet.position)
                                Button { engine.selectSpaceDestination(planet) } label: {
                                    VStack(spacing:3) {
                                        Circle().fill(tint(planet)).frame(width:planet == .coruscant ? 24:20,height:planet == .coruscant ? 24:20)
                                            .overlay(Circle().stroke(engine.selectedSpacePlanet == planet ? .white:.clear,lineWidth:3).padding(-5))
                                        Text(planet.name).font(.system(size:11,weight:.semibold)).foregroundStyle(.white)
                                    }.padding(8).contentShape(Rectangle())
                                }.flightButtonGlass().buttonStyle(GlowingFlightButton()).position(x:CGFloat(p.x)*side,y:CGFloat(p.y)*side)
                                    .accessibilityLabel("Map " + planet.name)
                                    .accessibilityValue(engine.selectedSpacePlanet == planet ? "Selected" : "")
                            }
                            let portal = chart.point(engine.spaceReturnPortal)
                            Button { engine.selectSpaceDestination(nil) } label: {
                                VStack(spacing:2) { Image(systemName:"sparkles").foregroundStyle(.white); Text("Return portal").font(.system(size:10)).foregroundStyle(.white) }
                                    .padding(8)
                            }.flightButtonGlass().position(x:CGFloat(portal.x)*side,y:CGFloat(portal.y)*side).accessibilityLabel("Map return portal")
                            let p = chart.point(pilot)
                            Image(systemName:"location.north.fill").foregroundStyle(.cyan)
                                .rotationEffect(.radians(Double(engine.state.heading)))
                                .position(x:CGFloat(p.x)*side,y:CGFloat(p.y)*side)
                                .accessibilityLabel("Your ship on map").allowsHitTesting(false)
                        }.frame(width:side,height:side).frame(maxWidth:.infinity)
                    }.frame(height:340).accessibilityIdentifier("Orbital chart")
                    Text("Gold: open trade routes · Cyan: remaining saved stops").font(.caption2).foregroundStyle(FlightPalette.secondary)
                    Text("Grid square: \(HUDSnapshot.distanceLabel(chart.span/8)) · dashed line: selected route")
                        .font(.caption2).foregroundStyle(.white).accessibilityIdentifier("Orbital map scale")
                    if let surface = engine.currentSurfacePlanet {
                        Text("You are on \(surface.name). Your marker shows that planet's orbital location.").font(.caption)
                    }
                    if let planet = engine.selectedSpacePlanet {
                        Text(planet.name + " · " + planet.description).font(.headline)
                        Text(engine.currentSurfacePlanet == nil ? "Distance: \(HUDSnapshot.distanceLabel(engine.distanceToPlanet(planet))) · Height difference: \(Int(planet.position.y-engine.state.position.y)) m" : "Return to orbit to fly to another planet.")
                            .font(.subheadline).monospacedDigit().accessibilityIdentifier("Map destination details")
                        Text("The chart shows horizontal positions. Use the height difference to climb or descend as you approach.").font(.caption).foregroundStyle(.white)
                    } else {
                        Text("Return portal selected").font(.headline)
                        Text(engine.currentSurfacePlanet == nil ? "Distance: \(HUDSnapshot.distanceLabel(course.distance))":"Return to orbit to reach the portal.")
                            .font(.subheadline.monospacedDigit()).accessibilityIdentifier("Map destination details")
                    }
                    if engine.currentSurfacePlanet == nil {
                        VStack(alignment:.leading,spacing:6) {
                            if let heading = course.headingDegrees {
                                Text(String(format:"Course %03.0f°",heading)).font(.headline.monospacedDigit())
                            }
                            Text(course.steering)
                            Text(course.altitude).foregroundStyle(.white)
                        }.padding(12).frame(maxWidth:.infinity,alignment:.leading)
                            .background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
                            .accessibilityElement(children:.combine).accessibilityIdentifier("Map course guidance")
                    }
                    Button("Follow selected course") { dismiss() }.flightButtonGlass().buttonStyle(GlowingFlightButton())
                        .accessibilityIdentifier("Follow map course")
                }.padding()
            }.background(FlightStyle.ink)
                .navigationTitle("Navigation chart")
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() }.flightButtonGlass().accessibilityIdentifier("Space map done") } }
            }
        }.tint(.white).foregroundStyle(.white).preferredColorScheme(.dark)
    }
    private func tint(_ planet:SpacePlanet) -> Color {
        switch planet { case .tatooine: return .orange; case .hoth: return .white; case .endor: return .green; case .coruscant: return .purple }
    }
}
