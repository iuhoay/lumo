import AppKit
import SwiftUI

/// Owns the floating translation window: a single reusable NSWindow that hosts
/// the SwiftUI `TranslationView` and is positioned near the mouse pointer.
@MainActor
final class TranslationWindowController {
    private weak var model: AppModel?
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func present() {
        let window = ensureWindow()
        positionNearMouse(window)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Keep the window above other apps' windows when pinned.
    func setPinned(_ pinned: Bool) {
        window?.level = pinned ? .floating : .normal
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }

        let root = TranslationView().environmentObject(model ?? AppModel.shared)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 440, height: 360))
        window.minSize = NSSize(width: 360, height: 240)
        self.window = window
        return window
    }

    /// Places the window near the pointer: below-right when there's room,
    /// otherwise above. Clamped to the visible frame of the pointer's screen.
    private func positionNearMouse(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation // global coords, bottom-left origin
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let size = window.frame.size
        let gap: CGFloat = 14

        var origin = NSPoint(x: mouse.x + gap, y: mouse.y - size.height - gap)
        if origin.y < visible.minY {
            origin.y = mouse.y + gap // not enough room below -> place above the pointer
        }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        window.setFrameOrigin(origin)
    }
}
