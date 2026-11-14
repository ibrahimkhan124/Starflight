import SwiftUI
import RealityKit
import AVFoundation
import Combine
#if os(iOS) && !targetEnvironment(macCatalyst)
import ARKit

@MainActor
final class RoomFlightSession: NSObject, ObservableObject, @preconcurrency ARSessionDelegate {
    @Published var status = "Scan the floor or a table, then tap Place ship."
    @Published var placed = false
    @Published var tracking = false
    @Published var allowed = false
    @Published var cameraDenied = false
    @Published var cameraReady = false
    private var appActive = true
    @Published var paused = false
    @Published var throttle: Float = 0
    @Published var objectCount = 0
    var stick = SIMD2<Float>.zero
    var climb: Float = 0
    weak var view: ARView?
    let anchor = AnchorEntity(world: .zero)
    let ship = Entity()
    var heading: Float = 0
    var obstacles: [Entity] = []
    var subscription: (any Cancellable)?
    var nextObject = "Gate"
    let aircraft: AircraftType
    let customURL: URL?
    init(aircraft: AircraftType, customURL: URL?) { self.aircraft = aircraft; self.customURL = customURL }
    func requestCamera() async {
        guard ARWorldTrackingConfiguration.isSupported else { status = "AR room tracking is unavailable on this device."; return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: allowed = true
        case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .video)
        default: allowed = false
        }
        cameraDenied = !allowed
        status = allowed ? "Starting rear camera…" : "Camera access is off. Enable Starflight's camera in Settings, then return here."
        if allowed { resumeCamera() }
    }
    func setActive(_ active: Bool) {
        appActive = active
        throttle = 0; stick = .zero; climb = 0
        if active { Task { await requestCamera() } }
        else { view?.session.pause(); tracking = false; cameraReady = false }
    }
    func resumeCamera() {
        guard allowed, appActive, let view else { return }
        // Permission prompts interrupt the app before a configuration necessarily exists.
        // Always create a valid configuration rather than relying on the interrupted session.
        view.environment.background = .cameraFeed()
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        view.session.run(config)
    }
    func start(_ view: ARView) {
        self.view = view
        view.environment.background = .cameraFeed()
        let model = AircraftFactory.make(type: aircraft, color: .cyan, customURL: customURL)
        let bounds = model.visualBounds(relativeTo: model)
        let scale = 0.22 / max(bounds.extents.x, bounds.extents.y, bounds.extents.z, 0.01)
        model.scale *= scale; model.position = -bounds.center * scale
        ship.addChild(model); ship.isEnabled = false; anchor.addChild(ship); view.scene.addAnchor(anchor)
        view.session.delegate = self; view.session.delegateQueue = .main
        resumeCamera()
        subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.advance(Float(event.deltaTime))
        }
    }
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if !cameraReady { cameraReady = true }
        if case .normal = frame.camera.trackingState, !tracking {
            tracking = true
            status = placed ? "Room tracking ready" : "Rear camera ready. Scan a floor or table, then place your ship."
        }
    }
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        if case .normal = camera.trackingState { tracking = true; status = placed ? "Room tracking ready" : "Aim at a floor or table and place your ship." }
        else { tracking = false; throttle = 0; stick = .zero; status = "Tracking paused. Move the camera slowly in good light." }
    }
    func sessionWasInterrupted(_ session: ARSession) { tracking = false; throttle = 0; stick = .zero }
    func sessionInterruptionEnded(_ session: ARSession) {
        resumeCamera()
    }
    func session(_ session: ARSession, didFailWithError error: Error) { tracking = false; throttle = 0; cameraReady = false; status = "Camera session stopped: \(error.localizedDescription). Tap Retry camera." }
    func surfacePoint() -> SIMD3<Float>? {
        guard tracking, let view, let hit = view.raycast(from: CGPoint(x: view.bounds.midX, y: view.bounds.midY), allowing: .existingPlaneGeometry, alignment: .horizontal).first else { status = "No surface found. Slowly scan the floor or table first."; return nil }
        let p = hit.worldTransform.columns.3; return [p.x, p.y, p.z]
    }
    func placeShip() {
        guard let point = surfacePoint() else { return }
        ship.position = point + [0,0.18,0]; ship.isEnabled = true; heading = 0; placed = true; throttle = 0
        status = "Ship placed. Stay still and use the flight controls."
    }
    func addObject() {
        guard objectCount < 20 else { status = "Room limit reached: remove the last object to add another."; return }
        guard let point = surfacePoint() else { return }
        let object = Entity(); object.position = point
        let material = UnlitMaterial(color: nextObject == "Gate" ? .cyan : nextObject == "Tower" ? .systemPurple : .systemOrange)
        func part(_ size: SIMD3<Float>, _ position: SIMD3<Float>) {
            let piece = ModelEntity(mesh: .generateBox(size: size), materials: [material]); piece.position = position; object.addChild(piece)
        }
        if nextObject == "Gate" {
            part([0.025,0.35,0.025],[-0.2,0.175,0]); part([0.025,0.35,0.025],[0.2,0.175,0]); part([0.425,0.025,0.025],[0,0.35,0])
        } else if nextObject == "Tower" { part([0.15,0.45,0.15],[0,0.225,0]) }
        else { let rock = ModelEntity(mesh: .generateSphere(radius: 0.1), materials: [material]); rock.position.y = 0.18; object.addChild(rock) }
        anchor.addChild(object); obstacles.append(object); objectCount = obstacles.count; status = "Added \(nextObject.lowercased()) · \(objectCount)/20 objects"
    }
    func undo() { obstacles.popLast()?.removeFromParent(); objectCount = obstacles.count }
    func advance(_ dt: Float) {
        guard placed, tracking, !paused, UIApplication.shared.applicationState == .active else { return }
        let step = min(max(dt,0),0.05)
        heading += stick.x * step * 1.5
        ship.orientation = simd_quatf(angle: -heading, axis: [0,1,0])
        ship.position += SIMD3<Float>(sin(heading)*throttle*0.4, stick.y*0.2 + climb*0.2, -cos(heading)*throttle*0.4) * step
        if let camera = view?.cameraTransform.translation, simd_distance(ship.position, camera) > 3 {
            throttle = 0; stick = .zero; status = "Ship reached the 3 m flight boundary. Reposition it on a nearby surface."
        }
    }
    func stop() { throttle = 0; stick = .zero; climb = 0; subscription?.cancel(); subscription = nil; view?.session.pause() }
    func reset() {
        placed = false; ship.isEnabled = false; throttle = 0; obstacles.forEach { $0.removeFromParent() }; obstacles = []; objectCount = 0
        guard let view else { return }; let config = ARWorldTrackingConfiguration(); config.planeDetection = [.horizontal]
        view.session.run(config, options: [.resetTracking,.removeExistingAnchors]); anchor.removeFromParent(); view.scene.addAnchor(anchor); status = "Scan the room again, then place your ship."
    }
}

struct RoomFlightView: View {
    @StateObject private var room: RoomFlightSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var object = "Gate"
    init(aircraft: AircraftType, customURL: URL?) { _room = StateObject(wrappedValue: RoomFlightSession(aircraft: aircraft, customURL: customURL)) }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                if room.allowed { RoomCameraView(room: room).ignoresSafeArea() }
                if room.allowed { Image(systemName: "plus").font(.title).foregroundStyle(.white).allowsHitTesting(false) }
                VStack(spacing: 8) {
                    HStack {
                        Text("ROOM FLIGHT").font(.headline); Spacer()
                        if room.allowed {
                            Button(room.paused ? "Resume" : "Pause") { room.paused.toggle(); room.throttle = 0 }.flightButtonGlass()
                        }
                        Button("Done") { room.stop(); dismiss() }.flightButtonGlass().accessibilityIdentifier("Close room flight")
                    }
                    Text(room.status).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8).background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                    if !room.cameraReady && (room.allowed || room.cameraDenied) {
                        HStack {
                            if room.allowed { ProgressView().tint(.cyan) }
                            Button(room.cameraDenied ? "Open camera settings" : "Retry camera") {
                                if room.cameraDenied, let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                                else { Task { await room.requestCamera() } }
                            }.flightButtonGlass().accessibilityIdentifier("Recover room camera")
                        }
                    }
                    if geometry.size.height > 550 || !room.allowed {
                        Text("Camera images stay on this device. Keep a clear space; real furniture is not collision-tested.")
                            .font(.caption2).padding(8).background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
                    }
                    Spacer(minLength: 0)
                    if room.allowed {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button(room.placed ? "Reposition ship" : "Place ship") { room.placeShip() }.flightButtonGlass().disabled(!room.tracking)
                                Menu("Add \(object)") { ForEach(["Gate","Tower","Asteroid"], id: \.self) { item in Button(item) { object = item; room.nextObject = item } } }.flightButtonGlass()
                                Button("Place object") { room.addObject() }.flightButtonGlass().disabled(!room.tracking)
                                Button("Undo") { room.undo() }.flightButtonGlass().disabled(room.objectCount == 0)
                                Button("Reset scan") { room.reset() }.flightButtonGlass()
                            }.font(.caption).fixedSize(horizontal: true, vertical: false)
                        }.frame(height: 48)
                        HStack(alignment: .bottom) {
                            VirtualJoystick(onChange: { room.stick = $0 }, diameter: geometry.size.height < 550 ? 78 : 110)
                            Spacer()
                            VStack(spacing: 2) {
                                Text("THRUST · \(Int(room.throttle*100))%").font(.caption2.monospacedDigit())
                                Slider(value: $room.throttle, in: -1...1).accessibilityLabel("Room flight thrust")
                                Button("Stop / hover") { room.throttle = 0; room.stick = .zero }.font(.caption).frame(minHeight: 36)
                            }.frame(width: min(190,geometry.size.width*0.5)).padding(8).background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
                        }.disabled(!room.placed || !room.tracking || room.paused)
                    }
                }.padding(10).foregroundStyle(.white)
            }
        }.task { await room.requestCamera() }.onDisappear { room.stop() }
            .onChange(of: scenePhase) { _, phase in room.setActive(phase == .active) }
    }
}

private struct RoomCameraView: UIViewRepresentable {
    @ObservedObject var room: RoomFlightSession
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false); room.start(view); return view
    }
    func updateUIView(_ view: ARView, context: Context) {}
    static func dismantleUIView(_ view: ARView, coordinator: ()) { view.session.pause() }
}
#else
struct RoomFlightView: View {
    let aircraft: AircraftType
    let customURL: URL?
    var body: some View { Text("Room flight needs AR world tracking on a supported iPhone or iPad.").padding() }
}
#endif
