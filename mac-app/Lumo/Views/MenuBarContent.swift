import AppKit
import SwiftUI

/// Menu shown when clicking the menu-bar icon.
struct MenuBarContent: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var updater = UpdaterController.shared

    var body: some View {
        Button("New Translation…") {
            model.newTranslation()
        }
        Button("OCR Screen Text…") {
            model.captureScreenText()
        }
        .disabled(model.isCapturingScreenText)
        Divider()
        Button("About Lumo") {
            // LSUIElement apps have no standard app menu, so the system "About"
            // item never appears — surface it here. The panel auto-reads the
            // version, copyright (NSHumanReadableCopyright), and icon from the bundle.
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.orderFrontStandardAboutPanel(nil)
        }
        Button("View on GitHub") {
            if let url = URL(string: "https://github.com/iuhoay/lumo") {
                NSWorkspace.shared.open(url)
            }
        }
        Button("Check for Updates…") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
        Divider()
        Button("Translation History…") {
            HistoryWindowController.shared.present()
        }
        Button("Settings…") {
            SettingsWindowController.shared.present()
        }
        Divider()
        Button("Quit Lumo") {
            NSApplication.shared.terminate(nil)
        }
    }
}
