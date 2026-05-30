import SwiftUI
import AppKit

/// Menu shown when clicking the menu-bar icon.
struct MenuBarContent: View {
    @ObservedObject private var updater = UpdaterController.shared

    var body: some View {
        Button("关于 Lumo") {
            // LSUIElement apps have no standard app menu, so the system "About"
            // item never appears — surface it here. The panel auto-reads the
            // version, copyright (NSHumanReadableCopyright), and icon from the bundle.
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.orderFrontStandardAboutPanel(nil)
        }
        Button("在 GitHub 上查看") {
            if let url = URL(string: "https://github.com/iuhoay/lumo") {
                NSWorkspace.shared.open(url)
            }
        }
        Button("检查更新…") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
        Divider()
        Button("翻译历史…") {
            HistoryWindowController.shared.present()
        }
        Button("设置…") {
            SettingsWindowController.shared.present()
        }
        Divider()
        Button("退出 Lumo") {
            NSApplication.shared.terminate(nil)
        }
    }
}
