import SwiftUI

/// Menu shown when clicking the menu-bar icon.
struct MenuBarContent: View {
    var body: some View {
        Button("翻译历史…") {
            HistoryWindowController.shared.present()
        }
        SettingsLink {
            Text("设置…")
        }
        Divider()
        Button("退出 Lumo") {
            NSApplication.shared.terminate(nil)
        }
    }
}
