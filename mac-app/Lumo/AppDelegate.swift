import AppKit
import KeyboardShortcuts

/// Handles the custom URL scheme. `application(_:open:)` is the most reliable
/// hook for scheme activation in a menu-bar (LSUIElement) app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }

        // Touch the singleton so Sparkle starts its scheduled background update
        // checks now, not only when the user opens the "Check for Updates…" menu item.
        _ = UpdaterController.shared

        // Global hotkey for "New Translation…". The handler runs on the main
        // thread; assumeIsolated lets us call into the @MainActor AppModel without
        // hopping a runloop (so the window appears on the same keypress).
        KeyboardShortcuts.onKeyUp(for: .newTranslation) {
            MainActor.assumeIsolated {
                AppModel.shared.newTranslation()
            }
        }
    }

    func application(_: NSApplication, open urls: [URL]) {
        let clipboard = NSPasteboard.general.string(forType: .string)
        for url in urls {
            if let request = URLRouter.parse(url, clipboard: clipboard) {
                AppModel.shared.handle(request)
                break
            }
        }
    }
}
