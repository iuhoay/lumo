import SwiftUI

@main
struct LumoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(model)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .accessibilityLabel("Lumo")
        }
        // Settings is an AppKit-managed window (SettingsWindowController), not a
        // SwiftUI `Settings` scene: in this LSUIElement app the scene's
        // \.openSettings action does not open from the detached panel.
    }
}
