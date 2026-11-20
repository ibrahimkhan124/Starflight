import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// Unreal owns the frame loop. This bridge hosts SwiftUI in the same app process.
@objc(StarflightSwiftUI)
final class StarflightSwiftUI: NSObject {
    #if os(macOS)
    @MainActor private static var planner: NSPanel?
    #endif

    @objc(present:onSelect:)
    static func present(_ current: Int32, onSelect: @escaping (Int32) -> Void) {
        DispatchQueue.main.async {
            #if os(macOS)
            if let planner, planner.isVisible {
                planner.makeKeyAndOrderFront(nil)
                return
            }
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 470, height: 350),
                                styleMask: [.titled, .closable, .resizable],
                                backing: .buffered, defer: false)
            panel.title = "Starflight"
            panel.isReleasedWhenClosed = false
            panel.contentMinSize = NSSize(width: 320, height: 250)
            panel.contentView = NSHostingView(rootView: GameView(current: current) { [weak panel] index in
                panel?.close()
                onSelect(index)
            })
            planner = panel
            panel.center()
            panel.makeKeyAndOrderFront(nil)
            #elseif os(iOS)
            let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }
                .flatMap(\.windows).first(where: \.isKeyWindow)
            guard let owner = window?.rootViewController, owner.presentedViewController == nil else { return }
            let picker = UIHostingController(rootView: GameView(current: current) { [weak owner] index in
                owner?.dismiss(animated: true) { onSelect(index) }
            })
            picker.modalPresentationStyle = .formSheet
            picker.preferredContentSize = CGSize(width: 500, height: 365)
            owner.present(picker, animated: true)
            #endif
        }
    }
}
