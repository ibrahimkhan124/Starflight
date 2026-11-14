import SwiftUI
import RealityKit
#if canImport(UIKit)
import UIKit

@MainActor
final class KeyboardFlightView: ARView {
    weak var engine: GameEngine?
    private var pressedKeys: Set<String> = []
    @objc private func inspectSky(_ gesture: UITapGestureRecognizer) {
        engine?.inspectStar(at: gesture.location(in: self))
    }
    func installStarTap() {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(inspectSky(_:)))
        gesture.cancelsTouchesInView = false
        addGestureRecognizer(gesture)
    }
    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { becomeFirstResponder() }
    }

    override func resignFirstResponder() -> Bool {
        pressedKeys.removeAll()
        engine?.clearKeyboard()
        return super.resignFirstResponder()
    }

    private func keyName(_ press: UIPress) -> String? {
        guard let key = press.key else { return nil }
        if key.keyCode.rawValue == 225 || key.keyCode.rawValue == 229 { return "shift" }
        let value = key.charactersIgnoringModifiers
        switch value {
        case UIKeyCommand.inputUpArrow: return "up"
        case UIKeyCommand.inputDownArrow: return "down"
        case UIKeyCommand.inputLeftArrow: return "left"
        case UIKeyCommand.inputRightArrow: return "right"
        case " ": return "space"
        case "\u{F700}": return "up"
        case "\u{1B}": return "escape"
        case "\r", "\n": return "return"
        default: return value.lowercased()
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var remaining = Set<UIPress>()
        for press in presses {
            if let key = keyName(press), KeyboardControls.supported.contains(key) {
                if pressedKeys.insert(key).inserted { _ = engine?.keyDown(key) }
                continue
            }
            remaining.insert(press)
        }
        if !remaining.isEmpty { super.pressesBegan(remaining, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var remaining = Set<UIPress>()
        for press in presses {
            if let key = keyName(press), KeyboardControls.supported.contains(key) {
                pressedKeys.remove(key)
                _ = engine?.keyUp(key)
                continue
            }
            remaining.insert(press)
        }
        if !remaining.isEmpty { super.pressesEnded(remaining, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        pressedKeys.removeAll()
        engine?.clearKeyboard()
        super.pressesCancelled(presses, with: event)
    }
}

struct FlightSceneView: UIViewRepresentable {
    let engine: GameEngine
    let isVisible: Bool
    final class Coordinator {
        let engine: GameEngine
        var setup: Task<Void, Never>?
        init(engine: GameEngine) { self.engine = engine }
    }
    func makeCoordinator() -> Coordinator { Coordinator(engine: engine) }
    func makeUIView(context: Context) -> ARView {
        let view = KeyboardFlightView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.engine = engine
        view.installStarTap()
        view.isHidden = !isVisible
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
        if engine.settings.performanceMode {
            view.renderOptions.formUnion([.disableHDR, .disableGroundingShadows])
        }
        // Published state must not change synchronously inside a SwiftUI view update.
        context.coordinator.setup = Task { @MainActor in
            guard !Task.isCancelled else { return }
            engine.attach(to: view)
            view.becomeFirstResponder()
        }
        return view
    }
    func updateUIView(_ uiView: ARView, context: Context) {
        // Keep preparing the region, but render only the small showroom on the menu.
        uiView.isHidden = !isVisible
    }
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.setup?.cancel()
        coordinator.engine.detach()
    }
}
#else
import AppKit

struct FlightSceneView: NSViewRepresentable {
    let engine: GameEngine
    let isVisible: Bool

    final class Coordinator {
        let engine: GameEngine
        var setup: Task<Void, Never>?

        init(engine: GameEngine) {
            self.engine = engine
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(engine: engine)
    }

    func makeNSView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.isHidden = !isVisible
        context.coordinator.setup = Task { @MainActor in
            guard !Task.isCancelled else { return }
            engine.attach(to: view)
        }
        return view
    }

    func updateNSView(_ nsView: ARView, context: Context) { nsView.isHidden = !isVisible }

    static func dismantleNSView(_ nsView: ARView, coordinator: Coordinator) {
        coordinator.setup?.cancel()
        coordinator.engine.detach()
    }
}
#endif
