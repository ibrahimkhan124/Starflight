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

    @objc(present:ships:activeShip:onSelect:)
    static func present(_ current: Int32, ships: [String], activeShip: Int32, onSelect: @escaping (Int32, Int32) -> Void) {
        DispatchQueue.main.async {
            #if os(macOS)
            if let planner, planner.isVisible {
                planner.makeKeyAndOrderFront(nil)
                return
            }
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 490, height: 430),
                                styleMask: [.titled, .closable, .resizable],
                                backing: .buffered, defer: false)
            panel.title = "Starflight"
            panel.isReleasedWhenClosed = false
            panel.contentMinSize = NSSize(width: 320, height: 250)
            panel.contentView = NSHostingView(rootView: GameView(current: current, ships: ships, activeShip: activeShip) { [weak panel] index, ship in
                panel?.close()
                onSelect(index, ship)
            })
            planner = panel
            panel.center()
            panel.makeKeyAndOrderFront(nil)
            #elseif os(iOS)
            let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }
                .flatMap(\.windows).first(where: \.isKeyWindow)
            guard let owner = window?.rootViewController, owner.presentedViewController == nil else { return }
            let picker = UIHostingController(rootView: GameView(current: current, ships: ships, activeShip: activeShip) { [weak owner] index, ship in
                owner?.dismiss(animated: true) { onSelect(index, ship) }
            })
            picker.modalPresentationStyle = .formSheet
            picker.preferredContentSize = CGSize(width: 500, height: 430)
            owner.present(picker, animated: true)
            #endif
        }
    }
}
