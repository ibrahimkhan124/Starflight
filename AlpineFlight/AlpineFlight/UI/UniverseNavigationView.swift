import SwiftUI
import RealityKit
import UIKit
import SceneKit

struct UniverseNavigationView:View {
    @ObservedObject var engine:GameEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSize
    @State private var section = 0
    @State private var selectedGalaxy:Galaxy = .andromeda
    @State private var selectedHIP = 32349
    @State private var search = ""
    @FocusState private var searchFocused:Bool
    private var selectedStar:CatalogStar? { StarCatalogue.star(selectedHIP) }
    private var stars:[CatalogStar] {
        let query = search.trimmingCharacters(in:.whitespacesAndNewlines)
        return Array(StarCatalogue.all.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || String($0.hip).contains(query) }.prefix(24))
    }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:verticalSize == .compact ? 12:18) {
                Text("UNIVERSE EXPLORER").font(FlightStyle.displayFont(verticalSize == .compact ? 16:23)).textCase(.lowercase).foregroundStyle(FlightPalette.gold)
                Text(engine.currentGalaxy.name + " · " + engine.currentUniverseLocation).font(.headline).accessibilityIdentifier("Current galaxy")
                Picker("Exploration scale",selection:$section) {
                    Text("Galaxies").tag(0); Text("Astronomy").tag(1); Text("Solar System").tag(2)
                }.pickerStyle(.segmented).accessibilityIdentifier("Universe sections")
                if let restriction = engine.universeTravelRestriction {
                    Text(restriction).font(.subheadline).foregroundStyle(FlightPalette.gold)
                }
                if section == 0 {
                    GalaxyChartView(selection:$selectedGalaxy).frame(height:verticalSize == .compact ? 240:300)
                        .clipShape(RoundedRectangle(cornerRadius:20)).accessibilityIdentifier("3D galaxy map")
                    Text("Drag to orbit · Pinch to zoom · Tap a galaxy. Schematic Local Group chart; distances and sizes are not to scale.")
                        .font(.caption).foregroundStyle(FlightPalette.secondary)
                    ForEach(Galaxy.allCases) { galaxy in
                        Button { selectedGalaxy = galaxy } label: {
                            HStack(spacing:12) {
                                Image(systemName:selectedGalaxy == galaxy ? "checkmark.circle.fill":"sparkles")
                                VStack(alignment:.leading,spacing:4) { Text(galaxy.name).font(.headline); Text(galaxy.distance).font(.caption) }
                                Spacer()
                                if engine.visitedGalaxies.contains(galaxy.rawValue) { Text("VISITED").font(.caption2) }
                            }.frame(maxWidth:.infinity,alignment:.leading)
                        }.buttonStyle(MenuActionButtonStyle(accent:selectedGalaxy == galaxy ? FlightPalette.gold:FlightPalette.cyan))
                            .accessibilityIdentifier("Galaxy " + galaxy.rawValue).accessibilityValue(selectedGalaxy == galaxy ? "Selected":"Not selected")
                    }
                    Text(selectedGalaxy.detail).font(.subheadline)
                    travelButton("Engage hyperspace · " + selectedGalaxy.name,destination:.galaxy(selectedGalaxy),id:"Engage galaxy jump")
                    Text("Five seconds of hyperspace. Pause freezes the countdown; Cancel restores your departure. Arrival starts at zero throttle.").font(.caption).foregroundStyle(FlightPalette.secondary)
                    Divider()
                    Text("Black-hole expedition").font(.headline).foregroundStyle(FlightPalette.gold)
                    Text("Visit a safe approach, then fly closer. Gravity first causes drift, then becomes strong enough to block hyperspace. Crossing the event horizon ends the flight.").font(.subheadline)
                    if let range = engine.blackHoleRange {
                        Text("Horizon clearance: " + HUDSnapshot.distanceLabel(range)).monospacedDigit()
                        Text(String(format:"Gravity drift %.0f m/s",engine.gravityDriftSpeed)).font(.caption)
                        if let course = engine.blackHoleEscapeCourse { Text(course).font(.caption).foregroundStyle(FlightPalette.cyan) }
                    }
                    travelButton("Visit black-hole approach",destination:.blackHole,id:"Visit black hole")
                    Text("Fictional, compressed flight hazard with stylised photon rings and an accretion disc. The gravity is a game approximation; this is not a relativity simulation.").font(.caption).foregroundStyle(FlightPalette.secondary)
                } else if section == 1 {
                    FlightSwitchRow("Astronomy overlay",isOn:Binding(get:{ engine.astronomyEnabled },set:engine.setAstronomyMode)).tint(FlightPalette.cyan)
                    Text("\(StarCatalogue.all.count.formatted()) real catalogue stars · \(engine.astronomyObserver) observer").font(.headline).accessibilityIdentifier("Star catalogue count")
                    Text(StarCatalogue.source).font(.caption).foregroundStyle(FlightPalette.secondary)
                    Text(engine.settings.performanceMode ? "Performance Mode: 1,000 brightest catalogue stars drawn in three batches." : "3,000 stars drawn in three reusable mesh batches.").font(.caption).foregroundStyle(FlightPalette.cyan)
                    Link("NASA catalogue source",destination:URL(string:"https://heasarc.gsfc.nasa.gov/w3browse/all/hipparcos.html")!).font(.caption)
                    Text("In the Milky Way, directions come from catalogue positions and distance estimates from parallax. The viewpoint changes when you travel to another star. Star sizes and B−V colours are stylised; positions use the catalogue epoch, not today's sky.").font(.subheadline)
                    if engine.currentGalaxy != .milkyWay { Text("This galaxy has procedural survey scenery. Jump back to the Milky Way for the real-star sky.").foregroundStyle(FlightPalette.gold) }
                    TextField("Star name or HIP number",text:$search).textFieldStyle(.roundedBorder).focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }.accessibilityIdentifier("Star catalogue search")
                    ForEach(stars) { star in
                        Button { selectedHIP = star.hip; engine.selectUniverseStar(star) } label: {
                            HStack {
                                Text(star.title); Spacer(); Text(String(format:"%.1f ly",star.distanceLY)).monospacedDigit()
                                if selectedHIP == star.hip { Image(systemName:"checkmark.circle.fill") }
                            }
                        }.buttonStyle(MenuActionButtonStyle(accent:selectedHIP == star.hip ? FlightPalette.gold:FlightPalette.cyan))
                            .accessibilityIdentifier("Star \(star.hip)")
                    }
                    Text("Showing the first 24 matches. Search to find another of the 3,000 stars.").font(.caption).foregroundStyle(FlightPalette.secondary)
                    if let star = selectedStar {
                        VStack(alignment:.leading,spacing:6) {
                            Text(star.title + " · HIP \(star.hip)").font(.title3.bold()).foregroundStyle(FlightPalette.gold)
                            Text(String(format:"Earth distance ≈ %.2f ly · catalogue V magnitude %.2f",star.distanceLY,star.magnitude))
                            Text(String(format:"RA %.5f° · Dec %+.5f° · B−V %.3f",star.raDegrees,star.decDegrees,star.bv)).font(.caption.monospaced())
                            Text(String(format:"Parallax %.2f ± %.2f mas. Inverse-parallax distances are approximate.",star.parallaxMas,star.parallaxErrorMas)).font(.caption)
                        }.accessibilityIdentifier("Selected catalogue star")
                        travelButton("Jump near " + star.title,destination:.star(star.hip),id:"Engage star jump")
                    }
                    travelButton("Earth reference sky",destination:.star(nil),id:"Earth reference sky")
                    Text("Stellar movement is exaggerated: 20 km of local flight represents 1 parsec in the sky model. Nearby constellations change perspective; distant stars move much less.").font(.caption).foregroundStyle(FlightPalette.secondary)
                } else {
                    Text("Solar System exploration").font(.title3.bold()).foregroundStyle(FlightPalette.gold)
                    Text("Explore the Sun, eight planets and Earth's Moon. Bodies, sizes and fixed positions are compressed for flight. Explore original surface regions on rocky worlds and cloud layers on gas and ice giants. These landscapes are interpretations, not geographic surveys.").font(.subheadline)
                    travelButton("Travel to the Solar System",destination:.solarSystem,id:"Engage Solar System jump")
                    if let body = engine.currentSolarSurface {
                        Text(body.name + (body.isCloudWorld ? " cloud flight · no solid surface" : " surface expedition")).font(.headline).foregroundStyle(.cyan)
                        Button("Return to Solar System orbit") { engine.engageUniverseJump(.solarSystem); dismiss() }.buttonStyle(MenuActionButtonStyle())
                    }
                    if engine.solarSystemActive {
                        ForEach(SolarBody.all) { body in
                            VStack(alignment: .leading, spacing: 8) {
                                Button("Navigate to " + body.name) { engine.selectSolarBody(body) }.buttonStyle(MenuActionButtonStyle()).accessibilityIdentifier("Solar body " + body.name)
                                if body.name != "Sun" {
                                    Button(body.isCloudWorld ? "Explore \(body.name) clouds" : "Enter \(body.name)") { engine.enterSolarBody(body); dismiss() }
                                        .buttonStyle(MenuActionButtonStyle(accent:FlightPalette.gold)).disabled(engine.universeTravelRestriction != nil).accessibilityIdentifier("Enter solar " + body.name)
                                }
                            }
                        }
                    }
                    Text("For Coruscant, Hoth, Endor and Tatooine, select Milky Way → Engage hyperspace to return to Starflight's fictional home sector. The planetary map opens those enterable worlds.")
                        .font(.caption).foregroundStyle(FlightPalette.cyan)
                }
                Divider()
                Text("Travel uses bounded local scenes rather than enormous world coordinates. Galaxies beyond the Milky Way use original procedural scenery; their stars are not labelled as catalogue observations.")
                    .font(.caption2).foregroundStyle(FlightPalette.secondary)
            }.padding(20).frame(maxWidth:800).frame(maxWidth:.infinity)
        }.background(FlightStyle.ink).foregroundStyle(.white)
            .navigationTitle("Galaxy map & hyperspace")
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() }.flightButtonGlass().accessibilityIdentifier("Close universe map") } }
    }
    private func travelButton(_ title:String,destination:UniverseDestination,id:String) -> some View {
        Button { engine.engageUniverseJump(destination) } label: { Label(title,systemImage:"sparkles") }
            .buttonStyle(MenuActionButtonStyle(accent:FlightPalette.gold,prominent:true))
            .disabled(engine.universeTravelRestriction != nil).accessibilityIdentifier(id)
    }
}

/// Native mouse/touch gestures move the chart directly, without a SwiftUI round-trip per drag.
struct GalaxyChartView:UIViewRepresentable {
    @Binding var selection:Galaxy
    func makeCoordinator() -> Coordinator { Coordinator(selection:$selection) }
    func makeUIView(context:Context) -> SCNView {
        let view = SCNView(frame:.zero), scene = SCNScene(), c = context.coordinator
        view.scene = scene; view.backgroundColor = UIColor(red:0.015,green:0.025,blue:0.055,alpha:1)
        view.preferredFramesPerSecond = 30; view.rendersContinuously = true; view.isPlaying = true
        view.antialiasingMode = .multisampling2X
        c.view = view; c.camera.camera = SCNCamera(); c.camera.camera?.fieldOfView = 52; c.camera.camera?.projectionDirection = .horizontal
        c.camera.camera?.zNear = 0.1; c.camera.camera?.zFar = 100
        scene.rootNode.addChildNode(c.root); scene.rootNode.addChildNode(c.camera); view.pointOfView = c.camera; c.updateCamera()
        for galaxy in Galaxy.allCases {
            let group = SCNNode(); group.name = galaxy.rawValue
            let p = galaxy.mapPosition; group.position = SCNVector3(p.x,p.y,p.z)
            let rgb = galaxy.tint, color = UIColor(red:CGFloat(rgb.x),green:CGFloat(rgb.y),blue:CGFloat(rgb.z),alpha:1)
            let material = SCNMaterial(); material.lightingModel = .constant; material.diffuse.contents = color; material.isDoubleSided = true
            let core = SCNNode(geometry:SCNSphere(radius:0.15)); core.geometry?.materials = [material]; group.addChildNode(core)
            var vertices:[SCNVector3] = []
            for i in 0..<240 {
                let r = sqrt((Float(i)+0.5)/240)*1.15
                let angle = galaxy == .magellanic ? Float(i)*2.3999632:r*7+Float(i%3)*2.0944+sin(Float(i)*7.3)*0.15
                vertices.append(SCNVector3(cos(angle)*r,Float(i%3)*0.01,sin(angle)*r*(galaxy == .magellanic ? 0.65:1)))
            }
            let source = SCNGeometrySource(vertices:vertices), element = SCNGeometryElement(indices:(0..<240).map(Int32.init),primitiveType:.point)
            element.pointSize = 2.5; element.minimumPointScreenSpaceRadius = 1; element.maximumPointScreenSpaceRadius = 3
            let shape = SCNGeometry(sources:[source],elements:[element]); shape.materials = [material]
            group.addChildNode(SCNNode(geometry:shape))
            let hit = SCNNode(geometry:SCNSphere(radius:0.8)); hit.geometry?.firstMaterial?.colorBufferWriteMask = []; hit.geometry?.firstMaterial?.writesToDepthBuffer = false; group.addChildNode(hit)
            let text = SCNText(string:galaxy == .magellanic ? "LMC":galaxy.name,extrusionDepth:0)
            text.font = .systemFont(ofSize:0.35,weight:.semibold); text.flatness = 0.15
            let labelMaterial = SCNMaterial(); labelMaterial.lightingModel = .constant; labelMaterial.diffuse.contents = UIColor.white; text.materials = [labelMaterial]
            let label = SCNNode(geometry:text); label.position = SCNVector3(-0.5,0.6,0)
            let billboard = SCNBillboardConstraint(); billboard.freeAxes = .all; label.constraints = [billboard]; group.addChildNode(label)
            c.root.addChildNode(group)
        }
        view.addGestureRecognizer(UIPanGestureRecognizer(target:c,action:#selector(Coordinator.pan(_:))))
        view.addGestureRecognizer(UIPinchGestureRecognizer(target:c,action:#selector(Coordinator.pinch(_:))))
        view.addGestureRecognizer(UITapGestureRecognizer(target:c,action:#selector(Coordinator.tap(_:))))
        return view
    }
    func updateUIView(_ view:SCNView,context:Context) {
        context.coordinator.selection = $selection
        for group in context.coordinator.root.childNodes {
            let size:Float = group.name == selection.rawValue ? 1.15:1; group.scale = SCNVector3(size,size,size)
        }
    }
    final class Coordinator:NSObject {
        var selection:Binding<Galaxy>
        weak var view:SCNView?
        let root = SCNNode(), camera = SCNNode()
        var yaw:Float = 0, pitch:Float = 0.45, distance:Float = 26
        init(selection:Binding<Galaxy>) { self.selection = selection }
        func updateCamera() {
            camera.position = SCNVector3(sin(yaw)*cos(pitch)*distance,sin(pitch)*distance,cos(yaw)*cos(pitch)*distance)
            camera.look(at:SCNVector3Zero)
        }
        @objc func pan(_ gesture:UIPanGestureRecognizer) {
            let delta = gesture.translation(in:view); yaw -= Float(delta.x)*0.006; pitch = clamp(pitch+Float(delta.y)*0.004,0.12,1.25)
            gesture.setTranslation(.zero,in:view); updateCamera()
        }
        @objc func pinch(_ gesture:UIPinchGestureRecognizer) { distance = clamp(distance/Float(gesture.scale),7,40); gesture.scale = 1; updateCamera() }
        @objc func tap(_ gesture:UITapGestureRecognizer) {
            guard let view,var node = view.hitTest(gesture.location(in:view),options:[.firstFoundOnly:true]).first?.node else { return }
            while true {
                if let galaxy = Galaxy(rawValue:node.name ?? "") { selection.wrappedValue = galaxy; return }
                guard let parent = node.parent else { return }; node = parent
            }
        }
    }
}

struct UniverseFlightStrip:View {
    @ObservedObject var engine:GameEngine
    var body:some View {
        if engine.galaxyJumpActive {
            HStack {
                Text(String(format:"HYPERSPACE · %@ · %.1f s",engine.galaxyJumpTitle,engine.galaxyJumpRemaining)).monospacedDigit()
                Button("Cancel jump") { engine.cancelUniverseJump() }.buttonStyle(.plain).padding(8).background(.white.opacity(0.12),in:Capsule()).fixedSize().accessibilityIdentifier("Cancel galaxy jump")
            }.font(.caption.bold()).padding(8).background(.black.opacity(0.8),in:Capsule()).accessibilityElement(children:.contain).accessibilityIdentifier("Galaxy jump status")
        } else if engine.solarSystemActive, let body = engine.selectedSolarBody {
            HStack {
                Text("SOLAR SYSTEM · " + body.name.uppercased()).font(.caption.bold())
                if body.name != "Sun" {
                    Button(body.isCloudWorld ? "Explore clouds" : "Enter planet") { engine.enterSolarBody(body) }.flightButtonGlass().accessibilityIdentifier("Enter selected solar planet")
                }
            }.padding(8).foregroundStyle(.cyan).background(.black.opacity(0.8), in:Capsule())
        } else if let body = engine.currentSolarSurface {
            HStack {
                Text(body.name + (body.isCloudWorld ? " · CLOUD EXPEDITION" : " · SURFACE EXPEDITION")).font(.caption.bold())
                Button("Return to orbit") { engine.engageUniverseJump(.solarSystem) }.flightButtonGlass().accessibilityIdentifier("Return solar orbit")
            }.padding(8).foregroundStyle(.cyan).background(.black.opacity(0.8), in:Capsule())
        } else if engine.astronomyEnabled && engine.universeActive {
            HStack(spacing: 6) {
                Text(engine.astronomyReadout).font(.caption.monospaced()).foregroundStyle(FlightPalette.cyan).lineLimit(2).accessibilityIdentifier("Astronomy flight readout")
                if engine.selectedUniverseStar != nil {
                    Button { engine.inspectSelectedStar() } label: { Image(systemName:"info.circle").frame(width:44,height:44) }.accessibilityLabel("Star facts").accessibilityIdentifier("Open star facts")
                }
            }.padding(8).background(.black.opacity(0.8),in:RoundedRectangle(cornerRadius:10))
        }
    }
}

struct StarFactCallout: View {
    @ObservedObject var engine: GameEngine
    let inspection: StarInspection
    var body: some View {
        GeometryReader { geometry in
            let point = CGPoint(x: inspection.point.x*geometry.size.width/max(1,inspection.viewport.width), y: inspection.point.y*geometry.size.height/max(1,inspection.viewport.height))
            let width = min(320.0, geometry.size.width-32)
            let x = min(max(point.x, width/2+16), geometry.size.width-width/2-16)
            let y = min(max(point.y+150, 180), max(180, geometry.size.height-175))
            Canvas { context, _ in
                var path = Path(); path.move(to: point); path.addLine(to: CGPoint(x:x,y:y-95))
                context.stroke(path, with: .color(.cyan), lineWidth: 1.5)
                context.stroke(Path(ellipseIn: CGRect(x:point.x-10,y:point.y-10,width:20,height:20)), with:.color(.cyan), lineWidth:2)
            }.allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text(inspection.star.title).font(.title2.bold()).foregroundStyle(.cyan); Spacer(); Image(systemName:"pause.circle.fill").foregroundStyle(.cyan) }
                Text(String(format:"About %.1f light-years from Earth. Catalogue brightness: %.2f magnitude.",inspection.star.distanceLY,inspection.star.magnitude))
                if let fact = inspection.star.featureFact { Text(fact).foregroundStyle(.white) }
                Text(inspection.star.bv < 0.15 ? "Its catalogue colour is blue-white." : inspection.star.bv > 0.85 ? "Its catalogue colour is warm orange-red." : "Its catalogue colour is white to yellow.")
                Text("HIP \(inspection.star.hip) · Position from ESA Hipparcos. Distances are approximate inverse-parallax estimates.").font(.caption).foregroundStyle(.secondary)
                Button("Continue flying") { engine.closeStarInspection() }.flightButtonGlass().accessibilityIdentifier("Close star facts")
            }.font(.subheadline).padding(16).frame(width:width).background(FlightStyle.ink.opacity(0.96),in:RoundedRectangle(cornerRadius:18))
                .overlay(RoundedRectangle(cornerRadius:18).stroke(.cyan.opacity(0.6))).position(x:x,y:y)
                .accessibilityIdentifier("Star fact file")
        }.background(.black.opacity(0.18)).foregroundStyle(.white).ignoresSafeArea()
    }
}
struct AsteroidScanOverlay: View {
    @ObservedObject var engine: GameEngine
    var body: some View {
        if engine.oreScanVisible {
            TimelineView(.animation(minimumInterval: 1.0/30)) { _ in
                GeometryReader { geometry in
                    if let projection = engine.scanProjection(), let survey = engine.oreSurvey {
                        let color = FlightPalette.mineral(survey.mineral.rarity)
                        let point = projection.center, radius = projection.radius
                        let labelPoint = CGPoint(x:min(max(point.x+radius+60,85),geometry.size.width-85),y:min(max(point.y-radius-25,50),geometry.size.height-50))
                        Canvas { context, _ in
                            context.stroke(Path(ellipseIn:CGRect(x:point.x-radius,y:point.y-radius,width:radius*2,height:radius*2)),with:.color(color),lineWidth:2)
                            var line = Path(); line.move(to:CGPoint(x:point.x+radius*0.7,y:point.y-radius*0.7)); line.addLine(to:labelPoint)
                            context.stroke(line,with:.color(color),lineWidth:1)
                        }
                        Text(survey.mineral.name).font(.caption.bold()).foregroundStyle(color).padding(6).background(.black.opacity(0.8),in:Capsule()).position(labelPoint)
                    }
                }
            }.accessibilityLabel("Asteroid scan locked. Scan again to select a new target.").accessibilityIdentifier("Persistent asteroid scan")
        }
    }
}
