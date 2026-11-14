import SwiftUI
import SceneKit
import simd

struct HomeInteriorView:View {
    @ObservedObject var engine:GameEngine
    let plot:CityPlot
    @StateObject private var room = HomeRoomController()
    @State private var walkingVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body:some View {
        NavigationStack {
            ZStack(alignment:.bottomLeading) {
                WalkingRoomView(controller:room,plot:plot,items:engine.economy.housing?.items(in:plot) ?? [],
                                layout:engine.economy.housing?.layout(in:plot) ?? [:],states:engine.economy.housing?.states(in:plot) ?? [:],
                                reduceMotion:reduceMotion,active:scenePhase == .active && room.inspectedItem == nil && walkingVisible,
                                sound:engine.settings.soundEnabled,volume:engine.settings.soundVolume)
                    .ignoresSafeArea(edges:.bottom)
                    .onAppear { walkingVisible = true; room.start() }.onDisappear { walkingVisible = false; room.stop() }
                    .accessibilityElement(children:.ignore)
                    .accessibilityLabel("Walkable home room. Use the movement joystick or WASD; drag to look.")
                    .accessibilityValue(room.poseLabel).accessibilityIdentifier("Walkable home room")
                HStack(alignment:.bottom) {
                VStack(alignment:.leading,spacing:10) {
                    if room.nearbyItem == nil && room.seatedItem == nil {
                        Text("Walk with the stick or WASD · drag to look").font(.caption)
                            .padding(8).background(.black.opacity(0.7),in:Capsule())
                    }
                    HomeWalkingStick { room.touchAxis = $0 }.frame(width:120,height:120)
                }
                Spacer()
                VStack(spacing:12) {
                    Button { room.briskWalking.toggle() } label: {
                        Label(room.briskWalking ? "Brisk walk":"Walk",systemImage:room.briskWalking ? "figure.walk.motion":"figure.walk")
                    }.flightButtonGlass().accessibilityIdentifier("Home brisk walking").accessibilityValue(room.briskWalking ? "On":"Off")
                    NavigationLink("Arrange " + room.area.name.lowercased()) { HomeArrangementView(engine:engine,plot:plot,area:room.area) }.flightButtonGlass()
                        .accessibilityIdentifier("Arrange entered home")
                    NavigationLink("Furnish") { CityHomesView(engine:engine,initialPlot:plot) }.flightButtonGlass()
                        .accessibilityIdentifier("Furnish entered home")
                }.buttonStyle(GlowingFlightButton())
                }.padding(20)
            }
            .overlay(alignment:.topLeading) { interactionCard.padding(12) }
            .background(.black).foregroundStyle(.white)
            .navigationTitle(plot.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.topBarLeading) {
                    Menu("Explore") {
                        Button("Inside") { room.visit(.room) }.flightButtonGlass().accessibilityIdentifier("Explore room")
                        Button("Terrace") { room.visit(.terrace) }.flightButtonGlass().accessibilityIdentifier("Explore terrace")
                    }.accessibilityIdentifier("Explore home areas")
                }
                ToolbarItem(placement:.confirmationAction) {
                    Button("Return to ship") { engine.exitResidence() }.flightButtonGlass().accessibilityIdentifier("Leave entered home")
                }
            }
        }.tint(.white).preferredColorScheme(.dark)
            .interactiveDismissDisabled()
            .sheet(item:$room.inspectedItem) { item in HomeFurnitureInspection(item:item) }
    }
    @ViewBuilder private var interactionCard:some View {
        if let seated = room.seatedItem {
            Button("Stand up · " + seated.name) { room.stand() }.flightButtonGlass().buttonStyle(GlowingFlightButton())
                .keyboardShortcut("e",modifiers:[]).accessibilityIdentifier("Stand from furniture")
        } else if let item = room.nearbyItem {
            let state = engine.economy.housing?.state(item,in:plot) ?? item.initialState
            VStack(alignment:.leading,spacing:4) {
                Text(item.name).font(.caption.bold())
                Button(item.actionLabel(state)) {
                    switch item.interaction {
                    case .seat:room.sit(item)
                    case .inspect:room.inspectedItem = item
                    default:
                        if engine.interactResidenceItem(item,in:plot,from:room.walk.position,area:room.area) { room.interactionNote = item.name+" · saved" }
                    }
                }.flightButtonGlass().buttonStyle(GlowingFlightButton()).keyboardShortcut("e",modifiers:[]).accessibilityIdentifier("Interact with furniture")
                if !room.interactionNote.isEmpty { Text(room.interactionNote).font(.caption2).accessibilityIdentifier("Home interaction feedback") }
            }.padding(10).frame(maxWidth:330,alignment:.leading).background(.black.opacity(0.75),in:RoundedRectangle(cornerRadius:12))
        }
    }
}

private struct HomeWalkingStick:View {
    var onMove:(SIMD2<Float>)->Void
    @State private var offset = CGSize.zero
    var body:some View {
        ZStack {
            Circle().fill(FlightStyle.ink.opacity(0.7)).overlay(Circle().stroke(.white.opacity(0.3),lineWidth:2))
            Image(systemName:"arrow.up.and.down.and.arrow.left.and.right").foregroundStyle(.white.opacity(0.3))
            Circle().fill(FlightStyle.mint).frame(width:42,height:42).offset(offset)
        }.contentShape(Circle())
            .gesture(DragGesture(minimumDistance:0).onChanged { value in
                var axis = SIMD2<Float>(Float(value.translation.width/42),-Float(value.translation.height/42))
                if simd_length(axis)>1 { axis = simd_normalize(axis) }
                offset = CGSize(width:CGFloat(axis.x)*42,height:-CGFloat(axis.y)*42); onMove(axis)
            }.onEnded { _ in offset = .zero; onMove(.zero) })
            .accessibilityElement(children:.ignore)
            .accessibilityLabel("Home walking joystick").accessibilityIdentifier("Home walking joystick")
            .accessibilityAdjustableAction { direction in
                let axis:SIMD2<Float> = direction == .increment ? [0,1]:[0,-1]
                onMove(axis)
                Task { @MainActor in try? await Task.sleep(for:.milliseconds(200)); onMove(.zero) }
            }
            .onDisappear { onMove(.zero) }
    }
}

@MainActor
final class HomeRoomController:NSObject,ObservableObject {
    @Published private(set) var poseLabel = "At the entrance"
    @Published var briskWalking = false
    @Published private(set) var area:HomeArea = .room
    @Published private(set) var nearbyItem:InteriorItem?
    @Published private(set) var seatedItem:InteriorItem?
    @Published var inspectedItem:InteriorItem?
    @Published var interactionNote = ""
    var touchAxis:SIMD2<Float> = .zero
    var keyboardAxis:SIMD2<Float> = .zero
    private(set) var walk = HomeRoomWalk()
    private var preview:ResidencePreviewScene?
    private var link:CADisplayLink?
    private var previous:CFTimeInterval = 0
    private var labelClock:Float = 0
    private var roomKey = ""
    private var states:[InteriorItem:HomeItemState] = [:]
    private let loungeAudio = HomeLoungeAudio()
    private var sound = true
    private var volume:Float = 0.8
    weak var view:SCNView?
    func configure(plot:CityPlot,items:Set<InteriorItem>,layout:[InteriorItem:RoomPlacement],states:[InteriorItem:HomeItemState] = [:],reduceMotion:Bool,sound:Bool = true,volume:Float = 0.8) {
        self.sound = sound; self.volume = volume; self.states = states; updateAudio()
        let key = plot.id+area.id+items.map(\.id).sorted().joined()+String(reduceMotion)+String(describing:layout.sorted { $0.key.id<$1.key.id })+String(describing:states.sorted { $0.key.id<$1.key.id })
        guard key != roomKey else { return }
        roomKey = key; walk.items = items; walk.layout = layout; walk.area = area
        if let seatedItem,!items.contains(seatedItem) { self.seatedItem = nil }
        if walk.blocked(walk.position) { walk.position = HomeRoomGeometry.walkingStart; walk.stop() }
        preview = ResidencePreviewScene(plot:plot,interior:true,items:items,reduceMotion:reduceMotion,layout:layout,walkthrough:true,states:states,area:area)
        view?.scene = preview?.scene; view?.pointOfView = preview?.camera
        updateCamera(); refreshNearby(); updateAudio()
    }
    func start() {
        guard link == nil else { return }
        previous = 0
        let display = CADisplayLink(target:self,selector:#selector(tick(_:)))
        display.preferredFramesPerSecond = 30; display.add(to:.main,forMode:.common); link = display
        updateAudio()
    }
    func stop() {
        link?.invalidate(); link = nil; previous = 0; touchAxis = .zero; keyboardAxis = .zero; walk.stop(); loungeAudio.stop()
    }
    @objc private func tick(_ display:CADisplayLink) {
        let dt = previous == 0 ? Float(1.0/30):Float(min(0.1,max(0,display.timestamp-previous)))
        previous = display.timestamp
        let input = touchAxis+keyboardAxis
        if seatedItem != nil,simd_length(input)>0.1 { stand() }
        if seatedItem == nil { walk.move(input,dt:dt,brisk:briskWalking) }
        updateCamera()
        labelClock += dt
        if labelClock>0.4 {
            labelClock = 0
            let label = String(format:"Room position %.1f, %.1f",walk.position.x,walk.position.y)
            if label != poseLabel { poseLabel = label }; refreshNearby()
        }
    }
    func look(dx:Float,dy:Float) { walk.look(dx:dx,dy:dy); updateCamera() }
    private func updateCamera() {
        if let item = seatedItem {
            let point = item.transformed(item.seatOffset,at:HomeRoomLayout.placement(item,in:walk.layout))
            preview?.camera.simdPosition = [point.x,item.seatHeight,point.y]
        } else { preview?.camera.simdPosition = [walk.position.x,1.7,walk.position.y] }
        preview?.camera.simdEulerAngles = [walk.pitch,walk.yaw,0]
    }
    func visit(_ area:HomeArea) {
        guard self.area != area else { return }
        stop(); self.area = area; walk = HomeRoomWalk(); walk.area = area
        seatedItem = nil; nearbyItem = nil; inspectedItem = nil; interactionNote = ""; roomKey = ""
    }
    func sit(_ item:InteriorItem) {
        guard item.interaction == .seat,walk.items.contains(item),item.area == area,
              HomeInteraction.distance(to:item,from:walk.position,layout:walk.layout)<=2.6 else { return }
        walk.stop(); seatedItem = item; walk.yaw = item.seatYaw+Float(HomeRoomLayout.placement(item,in:walk.layout).turns)*Float.pi/2; walk.pitch = 0
        updateCamera()
    }
    func stand() { seatedItem = nil; walk.stop(); updateCamera(); refreshNearby() }
    private func refreshNearby() {
        let item = HomeInteraction.nearest(from:walk.position,area:area,items:walk.items,layout:walk.layout)
        if item != nearbyItem { nearbyItem = item; interactionNote = "" }
    }
    private func updateAudio() {
        loungeAudio.update(playing:link != nil && area == .room && walk.items.contains(.jukebox) && (states[.jukebox] ?? InteriorItem.jukebox.initialState).enabled && sound,volume:volume)
    }
}

@MainActor
private final class HomeWalkingSceneView:SCNView {
    weak var room:HomeRoomController?
    private var keys:Set<String> = []
    override var canBecomeFirstResponder:Bool { true }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { becomeFirstResponder(); room?.start() } else { room?.stop() }
    }
    override func resignFirstResponder() -> Bool {
        keys = []; room?.keyboardAxis = .zero
        return super.resignFirstResponder()
    }
    @objc func pan(_ gesture:UIPanGestureRecognizer) {
        let delta = gesture.translation(in:self)
        room?.look(dx:Float(delta.x),dy:Float(delta.y)); gesture.setTranslation(.zero,in:self)
        if gesture.state == .began { becomeFirstResponder() }
    }
    private func key(_ press:UIPress) -> String? {
        guard let key = press.key else { return nil }
        switch key.charactersIgnoringModifiers {
        case UIKeyCommand.inputUpArrow:return "w"
        case UIKeyCommand.inputDownArrow:return "s"
        case UIKeyCommand.inputLeftArrow:return "a"
        case UIKeyCommand.inputRightArrow:return "d"
        default:return key.charactersIgnoringModifiers.lowercased()
        }
    }
    private func refresh() {
        room?.keyboardAxis = [Float(keys.contains("d") ? 1:0)-Float(keys.contains("a") ? 1:0),
                              Float(keys.contains("w") ? 1:0)-Float(keys.contains("s") ? 1:0)]
    }
    override func pressesBegan(_ presses:Set<UIPress>,with event:UIPressesEvent?) {
        var others:Set<UIPress> = []
        for press in presses {
            if let key = key(press),["w","a","s","d"].contains(key) { keys.insert(key) }
            else { others.insert(press) }
        }
        refresh(); if !others.isEmpty { super.pressesBegan(others,with:event) }
    }
    override func pressesEnded(_ presses:Set<UIPress>,with event:UIPressesEvent?) {
        for press in presses { if let key = key(press) { keys.remove(key) } }
        refresh(); super.pressesEnded(presses,with:event)
    }
    override func pressesCancelled(_ presses:Set<UIPress>,with event:UIPressesEvent?) {
        keys = []; refresh(); super.pressesCancelled(presses,with:event)
    }
}

private struct WalkingRoomView:UIViewRepresentable {
    @ObservedObject var controller:HomeRoomController
    let plot:CityPlot
    let items:Set<InteriorItem>
    let layout:[InteriorItem:RoomPlacement]
    let states:[InteriorItem:HomeItemState]
    let reduceMotion:Bool
    let active:Bool
    let sound:Bool
    let volume:Float
    func makeUIView(context:Context) -> HomeWalkingSceneView {
        let view = HomeWalkingSceneView(frame:.zero)
        view.backgroundColor = .black; view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling2X; view.rendersContinuously = true
        view.allowsCameraControl = false; view.room = controller; controller.view = view
        view.addGestureRecognizer(UIPanGestureRecognizer(target:view,action:#selector(HomeWalkingSceneView.pan(_:))))
        controller.configure(plot:plot,items:items,layout:layout,states:states,reduceMotion:reduceMotion,sound:sound,volume:volume)
        return view
    }
    func updateUIView(_ view:HomeWalkingSceneView,context:Context) {
        controller.configure(plot:plot,items:items,layout:layout,states:states,reduceMotion:reduceMotion,sound:sound,volume:volume)
        if active && view.window != nil { controller.start() } else { controller.stop() }
    }
    static func dismantleUIView(_ view:HomeWalkingSceneView,coordinator:()) {
        view.room?.stop(); view.room = nil; view.scene = nil
    }
}

private struct HomeFurnitureInspection:View {
    let item:InteriorItem
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    if item.layer == .wall { Image(uiImage:HomePaintingArt.image(item)).resizable().scaledToFit().accessibilityLabel(item.name) }
                    Text(item.name).font(.title2.bold()); Text(item.detail).font(.body)
                    Text("Part of your private \(item.area.name.lowercased()) collection.").font(.caption).foregroundStyle(.white)
                }.padding(24).frame(maxWidth:760).frame(maxWidth:.infinity)
            }.background(FlightStyle.ink).foregroundStyle(.white)
                .navigationTitle("Inspect furnishing").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() }.flightButtonGlass() } }
        }.preferredColorScheme(.dark)
    }
}
