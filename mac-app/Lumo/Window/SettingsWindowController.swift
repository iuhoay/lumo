import AppKit
import SwiftUI

/// Owns the Settings window: a single reusable NSWindow hosting the SwiftUI
/// `SettingsView`. Managed in AppKit rather than via the SwiftUI `Settings`
/// scene because this is an LSUIElement app — the `Settings` scene and its
/// `\.openSettings` action do NOT reliably open from the detached
/// `NSHostingController` that hosts the floating translation panel (the panel's
/// "打开设置" button was a silent no-op). An AppKit-managed window opens on
/// demand from both the menu bar and the translation panel. Mirrors
/// `HistoryWindowController`.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func present() {
        let window = ensureWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }

        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "设置"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        return window
    }
}
