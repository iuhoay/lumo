import AppKit
import SwiftUI

/// Owns the translation-history window: a single reusable NSWindow hosting the
/// SwiftUI `HistoryView`. Managed in AppKit rather than as a SwiftUI `Window`
/// scene so it is never auto-presented when the app activates to show the
/// translation window — it opens only on demand from the menu bar.
@MainActor
final class HistoryWindowController {
    static let shared = HistoryWindowController()

    private var window: NSWindow?

    private init() {}

    var isVisible: Bool { window?.isVisible ?? false }

    func present() {
        let window = ensureWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Show the window if hidden, hide it if visible.
    func toggle() {
        if let window, window.isVisible {
            window.orderOut(nil)
        } else {
            present()
        }
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }

        let root = HistoryView()
            .modelContainer(HistoryStore.shared.container)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "翻译历史"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 820, height: 560))
        window.minSize = NSSize(width: 720, height: 460)
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        return window
    }
}
