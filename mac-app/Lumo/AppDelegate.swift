import AppKit

/// Handles the custom URL scheme. `application(_:open:)` is the most reliable
/// hook for scheme activation in a menu-bar (LSUIElement) app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        let clipboard = NSPasteboard.general.string(forType: .string)
        for url in urls {
            if let request = URLRouter.parse(url, clipboard: clipboard) {
                AppModel.shared.handle(request)
                break
            }
        }
    }
}
