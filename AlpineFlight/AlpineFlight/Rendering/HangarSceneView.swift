import SwiftUI
import RealityKit
import SceneKit
import Combine
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// A small, independent showroom. Orbit input never changes the flight controls.
struct HangarSceneView: View {
    @ObservedObject var engine: GameEngine
    var isActive = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var orbit = HangarOrbitController()

    var body: some View {
        GeometryReader { geometry in
#if targetEnvironment(macCatalyst)
            MacHangarSurface(type: engine.aircraft, color: engine.settings.aircraftColor,
                             customURL: engine.customShipURL, orbit: orbit, reduceMotion: reduceMotion, isActive: isActive)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .accessibilityLabel("Ship hangar preview. Drag to orbit the ship.")
                .accessibilityIdentifier("Hangar preview")
                .accessibilityAction(named: "Rotate left") { orbit.rotate(by: -0.4) }
                .accessibilityAction(named: "Rotate right") { orbit.rotate(by: 0.4) }
                .accessibilityAction(named: "Zoom in") { orbit.zoom(by: 0.9) }
                .accessibilityAction(named: "Zoom out") { orbit.zoom(by: 1.35) }
#else
            HangarSurface(type: engine.aircraft, color: engine.settings.aircraftColor,
                          customURL: engine.customShipURL, orbit: orbit, reduceMotion: reduceMotion, isActive: isActive)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .accessibilityLabel("Ship hangar preview. Drag to orbit the ship.")
                .accessibilityIdentifier("Hangar preview")
                .accessibilityAction(named: "Rotate left") { orbit.rotate(by: -0.4) }
                .accessibilityAction(named: "Rotate right") { orbit.rotate(by: 0.4) }
                .accessibilityAction(named: "Zoom in") { orbit.zoom(by: 0.9) }
                .accessibilityAction(named: "Zoom out") { orbit.zoom(by: 1.35) }
#endif
        }.frame(maxWidth: .infinity, maxHeight: .infinity)

    }
}

/// An independent shop viewer. Copies actual flight-model triangles and materials once,
/// so the sheet does not contend with the game's RealityKit renderer.
struct ShipModelPreview: View {
    let ship: AircraftType
    @State private var preview: BlueprintPreviewScene?
    var body: some View {
        ZStack {
            if let preview {
                SceneView(scene:preview.scene,pointOfView:preview.camera,
                          options:[.allowsCameraControl],preferredFramesPerSecond:30,
                          antialiasingMode:.multisampling2X)
            } else { ProgressView("Preparing ship preview…") }
        }.frame(maxWidth:.infinity,maxHeight:.infinity)
            .background(Color(red:0.025,green:0.045,blue:0.07))
            .accessibilityLabel(ship.name + " 3D preview. Drag to rotate; pinch to zoom.")
            .accessibilityIdentifier("Blueprint ship preview")
            .task(id:ship) { preview = BlueprintPreviewScene(ship:ship) }
    }
}

@MainActor
private final class BlueprintPreviewScene {
    let scene = SCNScene()
    let camera = SCNNode()
    init(ship:AircraftType) {
        scene.background.contents = UIColor(red:0.025,green:0.045,blue:0.07,alpha:1)
        let source = AircraftFactory.make(type:ship,color:UIColor(AircraftColor.glacier.color))
        let bounds = source.visualBounds(relativeTo:source)
        let scale = 1.8 / max(max(bounds.extents.x,bounds.extents.y),bounds.extents.z,0.01)
        let model = Self.copy(source)
        let fit = SCNNode(); fit.addChildNode(model)
        fit.simdScale = SIMD3<Float>(repeating:scale)
        fit.simdPosition = -bounds.center*scale
        scene.rootNode.addChildNode(fit)
        camera.camera = SCNCamera(); camera.camera?.fieldOfView = 42
        camera.camera?.zNear = 0.01; camera.camera?.zFar = 100
        camera.position = SCNVector3(1.8,1.1,3)
        camera.look(at:SCNVector3Zero)
        scene.rootNode.addChildNode(camera)
        let key = SCNNode(); key.light = SCNLight(); key.light?.type = .omni
        key.light?.intensity = 700; key.position = SCNVector3(2,3,4)
        scene.rootNode.addChildNode(key)
        let fill = SCNNode(); fill.light = SCNLight(); fill.light?.type = .ambient
        fill.light?.intensity = 180; fill.light?.color = UIColor(white:0.8,alpha:1)
        scene.rootNode.addChildNode(fill)
    }
    fileprivate static func copy(_ entity:Entity) -> SCNNode {
        let node = SCNNode(); node.name = entity.name
        node.simdTransform = entity.transform.matrix
        if let model = (entity as? ModelEntity)?.model {
            for mesh in model.mesh.contents.models {
                for part in mesh.parts {
                    guard let indices = part.triangleIndices else { continue }
                    let vertices = part.positions.elements.map { SCNVector3($0.x,$0.y,$0.z) }
                    var sources = [SCNGeometrySource(vertices:vertices)]
                    if let normals = part.normals {
                        sources.append(SCNGeometrySource(normals:normals.elements.map { SCNVector3($0.x,$0.y,$0.z) }))
                    }
                    let geometry = SCNGeometry(sources:sources,elements:[SCNGeometryElement(indices:indices.elements,primitiveType:.triangles)])
                    let paint = SCNMaterial(); paint.lightingModel = .physicallyBased
                    paint.roughness.contents = 0.5; paint.metalness.contents = 0.25
                    if !model.materials.isEmpty {
                        // Primitive faces can have multiple slots with one shared material.
                        let original = model.materials[min(max(part.materialIndex,0),model.materials.count-1)]
                        if let original = original as? SimpleMaterial { paint.diffuse.contents = original.color.tint }
                        else if let original = original as? UnlitMaterial { paint.diffuse.contents = original.color.tint; paint.lightingModel = .constant }
                        else if let original = original as? PhysicallyBasedMaterial {
                            paint.diffuse.contents = original.baseColor.tint
                            paint.roughness.contents = original.roughness.scale
                            paint.metalness.contents = original.metallic.scale
                            paint.emission.contents = original.emissiveColor.color
                            paint.emission.intensity = CGFloat(min(original.emissiveIntensity,1.5))
                        }
                    }
                    geometry.materials = [paint]
                    node.addChildNode(SCNNode(geometry:geometry))
                }
            }
        }
        for child in entity.children { node.addChildNode(copy(child)) }
        return node
    }
}

private struct HangarSurface {
    let type: AircraftType
    let color: AircraftColor
    let customURL: URL?
    let orbit: HangarOrbitController
    let reduceMotion: Bool
    let isActive: Bool

    @MainActor
    final class Coordinator {
        let anchor = AnchorEntity(world: .zero)
        let camera = PerspectiveCamera()
        let turntable = Entity()
        var type: AircraftType?
        var color: AircraftColor?
        var customURL: URL?
        var orbit: HangarOrbitController?
        var subscription: (any Cancellable)?
        var active = true
        private var accessibilityClock: Float = 0

        func install(in view: ARView) {
            (view as? HangarInputView)?.installZoomGesture()
#if canImport(UIKit)
            view.isAccessibilityElement = true
            view.accessibilityIdentifier = "Hangar preview"
            view.accessibilityLabel = "Ship hangar preview. Drag to orbit; pinch or scroll to zoom."
#endif
            view.environment.background = .color(UIColor(red: 0.025, green: 0.045, blue: 0.07, alpha: 1))
            view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain, .disableHDR, .disableGroundingShadows]
            view.scene.addAnchor(anchor)
            anchor.addChild(camera)
            anchor.addChild(turntable)
            camera.camera.fieldOfViewInDegrees = 48
            let floor = SimpleMaterial(color: UIColor(red: 0.09, green: 0.12, blue: 0.16, alpha: 1), roughness: 0.85, isMetallic: false)
            let steel = SimpleMaterial(color: UIColor(red: 0.16, green: 0.2, blue: 0.25, alpha: 1), roughness: 0.6, isMetallic: true)
            func box(_ size: SIMD3<Float>, _ position: SIMD3<Float>, _ material: any RealityKit.Material) {
                let entity = ModelEntity(mesh: .generateBox(size: size), materials: [material])
                entity.position = position
                anchor.addChild(entity)
            }
            // The entire camera orbit stays inside the room, even at side/rear angles.
            box([110, 0.3, 110], [0, -0.3, 0], floor)
            box([100, 28, 0.6], [0, 13, -48], floor)
            box([0.6, 28, 96], [-48, 13, 0], floor)
            box([0.6, 28, 96], [48, 13, 0], floor)
            let pad = ModelEntity(mesh: .generateCylinder(height: 0.3, radius: 12), materials: [steel])
            anchor.addChild(pad)
            let lightStrip = UnlitMaterial(color: UIColor(red: 0.35, green: 0.75, blue: 0.95, alpha: 1))
            for x: Float in [-24, -12, 0, 12, 24] {
                box([0.25, 16, 0.1], [x, 9, -47.6], lightStrip)
                box([0.1, 0.02, 32], [x, -0.13, 0], lightStrip)
            }
            let key = DirectionalLight()
            key.light.intensity = 2600
            key.light.color = .white
            key.look(at: .zero, from: [14, 20, 14], relativeTo: nil)
            anchor.addChild(key)
            let fill = DirectionalLight()
            fill.light.intensity = 1500
            fill.light.color = UIColor(red: 0.5, green: 0.7, blue: 1, alpha: 1)
            fill.look(at: .zero, from: [-10, 10, -10], relativeTo: nil)
            anchor.addChild(fill)
            subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self, weak view] event in
                guard let self, self.active, let orbit = self.orbit else { return }
                orbit.advance(dt: Float(event.deltaTime))
                self.camera.look(at: [0, 4, 0], from: orbit.cameraPosition, relativeTo: nil)
                self.accessibilityClock += Float(event.deltaTime)
                if self.accessibilityClock >= 0.1 {
                    self.accessibilityClock = 0
#if canImport(UIKit)
                    view?.accessibilityValue = orbit.accessibilityDescription
#else
                    view?.setAccessibilityValue(orbit.accessibilityDescription)
#endif
                }
            }
        }

        func update(_ surface: HangarSurface) {
            active = surface.isActive
            orbit = surface.orbit
            surface.orbit.reduceMotion = surface.reduceMotion
            if type != surface.type || color != surface.color || customURL != surface.customURL {
                type = surface.type; color = surface.color; customURL = surface.customURL
                for child in Array(turntable.children) { child.removeFromParent() }
                let model = AircraftFactory.make(type: surface.type, color: UIColor(surface.color.color), customURL: surface.customURL)
                let bounds = model.visualBounds(relativeTo: model)
                let scale = 18 / max(max(bounds.extents.x, bounds.extents.y), bounds.extents.z, 0.01)
                model.scale *= SIMD3<Float>(repeating: scale)
                model.position = -bounds.center * scale + [0, bounds.extents.y * scale * 0.5 + 1, 0]
                turntable.orientation = simd_quatf()
                turntable.addChild(model)
            }
            camera.look(at: [0, 4, 0], from: surface.orbit.cameraPosition, relativeTo: nil)
        }

        func stop() { subscription?.cancel(); subscription = nil; anchor.removeFromParent() }
    }
}

#if canImport(UIKit)
extension HangarSurface: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> ARView {
        let view = HangarInputView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.orbit = orbit
        context.coordinator.install(in: view)
        context.coordinator.update(self)
        return view
    }
    func updateUIView(_ view: ARView, context: Context) { view.isHidden = !isActive; context.coordinator.update(self) }
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) { coordinator.stop() }
}
#else
extension HangarSurface: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> ARView {
        let view = HangarInputView(frame: .zero)
        view.orbit = orbit
        context.coordinator.install(in: view)
        context.coordinator.update(self)
        return view
    }
    func updateNSView(_ view: ARView, context: Context) { view.isHidden = !isActive; context.coordinator.update(self) }
    static func dismantleNSView(_ view: ARView, coordinator: Coordinator) { coordinator.stop() }
}
#endif

/// Input and camera smoothing stay in RealityKit's frame loop, without publishing
/// SwiftUI changes for every mouse move. No touch pressure or long press is used.
@MainActor
final class HangarOrbitController: ObservableObject {
    private(set) var yaw: Float = 2.55
    private(set) var pitch: Float = 0.23
    private(set) var distance: Float = 34
    private var targetDistance: Float = 34
    private var targetYaw: Float = 2.55
    private var targetPitch: Float = 0.23
    private var velocity = SIMD2<Float>.zero
    private var previousPoint = CGPoint.zero
    private var previousTime: TimeInterval = 0
    private var dragging = false
    private var touched = false
    var reduceMotion = false

    var cameraPosition: SIMD3<Float> {
        SIMD3<Float>(0, 4, 0) + SIMD3<Float>(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
    }

    var accessibilityDescription: String {
        String(format: "distance=%.1f;yaw=%.3f;pitch=%.3f;input=%@", distance, yaw, pitch, touched ? "manual" : "auto")
    }

    func zoom(by factor: Float) {
        guard factor.isFinite, factor > 0 else { return }
        touched = true
        targetDistance = clamp(targetDistance * factor, 18, 44)
        if reduceMotion { distance = targetDistance }
    }
    func resetZoom() { targetDistance = 34; if reduceMotion { distance = 34 } }

    func begin(at point: CGPoint, time: TimeInterval) {
        touched = true; dragging = true; velocity = .zero
        targetYaw = yaw; targetPitch = pitch
        previousPoint = point; previousTime = time
    }

    func drag(to point: CGPoint, time: TimeInterval) {
        guard dragging else { return }
        let change = SIMD2<Float>(-Float(point.x - previousPoint.x) * 0.011, Float(point.y - previousPoint.y) * 0.006)
        targetYaw += change.x
        targetPitch = clamp(targetPitch + change.y, -0.08, 0.65)
        // Input changes the destination; render ticks interpolate the camera so
        // uneven mouse/touch events cannot snap the displayed angle.
        if reduceMotion { yaw = targetYaw; pitch = targetPitch }
        let sample = simd_clamp(change / max(Float(time - previousTime), 0.008), SIMD2<Float>(repeating: -3), SIMD2<Float>(repeating: 3))
        velocity += (sample - velocity) * 0.35
        previousPoint = point; previousTime = time
    }

    func end(time: TimeInterval, cancelled: Bool = false) {
        dragging = false
        if cancelled || time - previousTime > 0.1 || reduceMotion { velocity = .zero }
    }

    func rotate(by angle: Float) { touched = true; targetYaw += angle; velocity = .zero }

    func advance(dt raw: Float) {
        let dt = clamp(raw, 0, 0.05)
        if !touched && !reduceMotion { targetYaw += dt * 0.16 }
        if !dragging && !reduceMotion {
            targetYaw += velocity.x * dt
            targetPitch = clamp(targetPitch + velocity.y * dt, -0.08, 0.65)
            velocity *= exp(-8 * dt)
        }
        // About 45 ms of filtering: enough to soften steps without a long lag.
        let response: Float = reduceMotion ? 1 : 1 - exp(-22 * dt)
        distance += (targetDistance - distance) * response
        yaw += (targetYaw - yaw) * response
        pitch += (targetPitch - pitch) * response
    }
}

#if canImport(UIKit)
@MainActor
private final class HangarGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIPinchGestureRecognizer
    }
}

@MainActor
private final class HangarInputView: ARView {
    var orbit: HangarOrbitController?
    private let inputGestureDelegate = HangarGestureDelegate()
    private var installedGestures = false
    private var lastScroll = CGPoint.zero
    private weak var pinchGesture: UIPinchGestureRecognizer?

    func installZoomGesture() {
        guard !installedGestures else { return }
        installedGestures = true
        isMultipleTouchEnabled = true
        // Native recognizers support both fingers and Catalyst pointer dragging; no pressure is needed.
        let pan = UIPanGestureRecognizer(target: self, action: #selector(orbitPan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.allowedTouchTypes = [UITouch.TouchType.direct, .indirect, .indirectPointer, .stylus].map { NSNumber(value: $0.rawValue) }
        pan.allowedScrollTypesMask = []
        pan.delegate = inputGestureDelegate
        addGestureRecognizer(pan)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchZoom(_:)))
        pinch.delegate = inputGestureDelegate
        pinchGesture = pinch
        addGestureRecognizer(pinch)
        let wheel = UIPanGestureRecognizer(target: self, action: #selector(scrollZoom(_:)))
        wheel.allowedTouchTypes = []
        wheel.allowedScrollTypesMask = .all
        wheel.delegate = inputGestureDelegate
        addGestureRecognizer(wheel)
    }
    @objc private func orbitPan(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: self)
        let time = CACurrentMediaTime()
        switch gesture.state {
        case .began: orbit?.begin(at: point, time: time)
        case .changed:
            guard pinchGesture?.state != .began, pinchGesture?.state != .changed else { return }
            orbit?.drag(to: point, time: time)
        case .ended: orbit?.end(time: time)
        case .cancelled, .failed: orbit?.end(time: time, cancelled: true)
        default: break
        }
    }
    @objc private func pinchZoom(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began { orbit?.end(time: CACurrentMediaTime(), cancelled: true) }
        if gesture.state == .changed {
            orbit?.zoom(by: Float(1 / gesture.scale))
            gesture.scale = 1
        }
    }
    @objc private func scrollZoom(_ gesture: UIPanGestureRecognizer) {
        guard gesture.numberOfTouches == 0 else { return }
        let point = gesture.translation(in: self)
        if gesture.state == .began { lastScroll = point }
        if gesture.state == .changed {
            let amount = Float(point.y - lastScroll.y)
            orbit?.zoom(by: exp(clamp(amount, -80, 80) * 0.008))
            lastScroll = point
        }
    }

}
#else
@MainActor
private final class HangarInputView: ARView {
    var orbit: HangarOrbitController?
    func installZoomGesture() {}
    override func magnify(with event: NSEvent) { orbit?.zoom(by: Float(1 / max(0.1, 1 + event.magnification))) }
    override func scrollWheel(with event: NSEvent) {
        orbit?.zoom(by: exp(-Float(clamp(event.scrollingDeltaY, -80, 80)) * (event.hasPreciseScrollingDeltas ? 0.008 : 0.04)))
    }
    override func mouseDown(with event: NSEvent) { orbit?.begin(at: convert(event.locationInWindow, from: nil), time: event.timestamp) }
    override func mouseDragged(with event: NSEvent) { orbit?.drag(to: convert(event.locationInWindow, from: nil), time: event.timestamp) }
    override func mouseUp(with event: NSEvent) { orbit?.end(time: event.timestamp) }
}
#endif

#if targetEnvironment(macCatalyst)
/// Catalyst uses an independent scene for inspection; an ARView in a presented
/// window can lose its drawable while the flight renderer remains alive.
private struct MacHangarSurface: UIViewRepresentable {
    let type: AircraftType
    let color: AircraftColor
    let customURL: URL?
    let orbit: HangarOrbitController
    let reduceMotion: Bool
    let isActive: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> SCNView {
        let view = MacHangarInputView(frame: .zero)
        view.orbit = orbit
        view.installZoomGesture()
        context.coordinator.install(in: view)
        context.coordinator.update(self)
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {
        view.isHidden = !isActive
        view.isPlaying = isActive
        context.coordinator.update(self)
    }
    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) { coordinator.stop() }

    @MainActor final class Coordinator: NSObject {
        let scene = SCNScene()
        let camera = SCNNode()
        let turntable = SCNNode()
        weak var view: SCNView?
        var orbit: HangarOrbitController?
        var type: AircraftType?
        var color: AircraftColor?
        var customURL: URL?
        var active = true
        var displayLink: CADisplayLink?
        var previousTime: CFTimeInterval = 0
        var accessibilityClock: Float = 0

        func install(in view: SCNView) {
            self.view = view
            view.scene = scene
            view.pointOfView = camera
            view.preferredFramesPerSecond = 60
            view.antialiasingMode = .multisampling2X
            view.isPlaying = true
            view.isAccessibilityElement = true
            view.accessibilityIdentifier = "Hangar preview"
            view.accessibilityLabel = "Ship hangar preview. Drag to orbit; pinch or scroll to zoom."
            scene.background.contents = UIColor(red: 0.025, green: 0.045, blue: 0.07, alpha: 1)
            camera.camera = SCNCamera()
            camera.camera?.fieldOfView = 48
            camera.camera?.zNear = 0.1
            camera.camera?.zFar = 200
            scene.rootNode.addChildNode(camera)
            scene.rootNode.addChildNode(turntable)
            func material(_ color: UIColor, glow: Bool = false) -> SCNMaterial {
                let result = SCNMaterial()
                result.diffuse.contents = color
                result.roughness.contents = 0.65
                if glow { result.lightingModel = .constant }
                return result
            }
            let floor = material(UIColor(red: 0.09, green: 0.12, blue: 0.16, alpha: 1))
            func box(_ size: SIMD3<Float>, _ position: SIMD3<Float>, _ paint: SCNMaterial) {
                let mesh = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: 0)
                mesh.materials = [paint]
                let node = SCNNode(geometry: mesh); node.simdPosition = position
                scene.rootNode.addChildNode(node)
            }
            box([110, 0.3, 110], [0, -0.3, 0], floor)
            box([100, 28, 0.6], [0, 13, -48], floor)
            box([0.6, 28, 96], [-48, 13, 0], floor)
            box([0.6, 28, 96], [48, 13, 0], floor)
            let pad = SCNCylinder(radius: 12, height: 0.3)
            pad.radialSegmentCount = 64
            pad.materials = [material(UIColor(red: 0.16, green: 0.2, blue: 0.25, alpha: 1))]
            scene.rootNode.addChildNode(SCNNode(geometry: pad))
            let strip = material(UIColor(red: 0.35, green: 0.75, blue: 0.95, alpha: 1), glow: true)
            for x: Float in [-24, -12, 0, 12, 24] {
                box([0.25, 16, 0.1], [x, 9, -47.6], strip)
                box([0.1, 0.02, 32], [x, -0.13, 0], strip)
            }
            for (position, intensity) in [(SIMD3<Float>(14, 20, 14), CGFloat(1400)), (SIMD3<Float>(-10, 10, -10), CGFloat(800))] {
                let light = SCNNode(); light.light = SCNLight(); light.light?.type = .omni
                light.light?.intensity = intensity; light.simdPosition = position
                scene.rootNode.addChildNode(light)
            }
            let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient
            ambient.light?.intensity = 200
            scene.rootNode.addChildNode(ambient)
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
        func update(_ surface: MacHangarSurface) {
            active = surface.isActive
            displayLink?.isPaused = !active
            orbit = surface.orbit
            surface.orbit.reduceMotion = surface.reduceMotion
            if type != surface.type || color != surface.color || customURL != surface.customURL {
                type = surface.type; color = surface.color; customURL = surface.customURL
                turntable.childNodes.forEach { $0.removeFromParentNode() }
                let model: SCNNode
                if let url = surface.customURL ?? AircraftFactory.blenderAssetURL(for: surface.type),
                   let asset = try? SCNScene(url: url) {
                    model = asset.rootNode.clone()
                } else {
                    model = BlueprintPreviewScene.copy(AircraftFactory.make(type: surface.type, color: UIColor(surface.color.color), customURL: surface.customURL))
                }
                let bounds = model.boundingBox
                let lo = SIMD3<Float>(bounds.min.x, bounds.min.y, bounds.min.z)
                let hi = SIMD3<Float>(bounds.max.x, bounds.max.y, bounds.max.z)
                let extent = hi - lo
                let scale = 18 / max(extent.x, extent.y, extent.z, 0.01)
                let fit = SCNNode(); fit.addChildNode(model)
                fit.simdScale = SIMD3<Float>(repeating: scale)
                fit.simdPosition = -(lo + hi) * 0.5 * scale + [0, extent.y * scale * 0.5 + 1, 0]
                turntable.addChildNode(fit)
            }
            updateCamera()
        }
        private func updateCamera() {
            guard let orbit else { return }
            camera.simdPosition = orbit.cameraPosition
            camera.look(at: SCNVector3(0, 4, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        }
        @objc func tick(_ link: CADisplayLink) {
            let dt = previousTime == 0 ? Float(1.0 / 60) : Float(link.timestamp - previousTime)
            previousTime = link.timestamp
            guard active, let orbit else { return }
            orbit.advance(dt: dt)
            updateCamera()
            accessibilityClock += dt
            if accessibilityClock >= 0.1 {
                accessibilityClock = 0
                view?.accessibilityValue = orbit.accessibilityDescription
            }
        }
        func stop() { displayLink?.invalidate(); displayLink = nil; view?.scene = nil }
    }
}
@MainActor
private final class MacHangarInputView: SCNView {
    var orbit: HangarOrbitController?
    private let inputGestureDelegate = HangarGestureDelegate()
    private var installedGestures = false
    private var lastScroll = CGPoint.zero
    private weak var pinchGesture: UIPinchGestureRecognizer?

    func installZoomGesture() {
        guard !installedGestures else { return }
        installedGestures = true
        isMultipleTouchEnabled = true
        // Native recognizers support both fingers and Catalyst pointer dragging; no pressure is needed.
        let pan = UIPanGestureRecognizer(target: self, action: #selector(orbitPan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.allowedTouchTypes = [UITouch.TouchType.direct, .indirect, .indirectPointer, .stylus].map { NSNumber(value: $0.rawValue) }
        pan.allowedScrollTypesMask = []
        pan.delegate = inputGestureDelegate
        addGestureRecognizer(pan)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchZoom(_:)))
        pinch.delegate = inputGestureDelegate
        pinchGesture = pinch
        addGestureRecognizer(pinch)
        let wheel = UIPanGestureRecognizer(target: self, action: #selector(scrollZoom(_:)))
        wheel.allowedTouchTypes = []
        wheel.allowedScrollTypesMask = .all
        wheel.delegate = inputGestureDelegate
        addGestureRecognizer(wheel)
    }
    @objc private func orbitPan(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: self)
        let time = CACurrentMediaTime()
        switch gesture.state {
        case .began: orbit?.begin(at: point, time: time)
        case .changed:
            guard pinchGesture?.state != .began, pinchGesture?.state != .changed else { return }
            orbit?.drag(to: point, time: time)
        case .ended: orbit?.end(time: time)
        case .cancelled, .failed: orbit?.end(time: time, cancelled: true)
        default: break
        }
    }
    @objc private func pinchZoom(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began { orbit?.end(time: CACurrentMediaTime(), cancelled: true) }
        if gesture.state == .changed {
            orbit?.zoom(by: Float(1 / gesture.scale))
            gesture.scale = 1
        }
    }
    @objc private func scrollZoom(_ gesture: UIPanGestureRecognizer) {
        guard gesture.numberOfTouches == 0 else { return }
        let point = gesture.translation(in: self)
        if gesture.state == .began { lastScroll = point }
        if gesture.state == .changed {
            let amount = Float(point.y - lastScroll.y)
            orbit?.zoom(by: exp(clamp(amount, -80, 80) * 0.008))
            lastScroll = point
        }
    }

}
#endif
