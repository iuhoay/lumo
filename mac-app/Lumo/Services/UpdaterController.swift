import Combine
import Sparkle

/// Owns the Sparkle updater for the whole app lifetime. A singleton (like the
/// app's other shared services) so the menu-bar "检查更新…" button can reach it
/// without threading a reference through the SwiftUI `MenuBarExtra` content.
///
/// Created once from `AppDelegate` at launch so scheduled background checks start
/// even if the user never opens the menu. Updates are verified by Sparkle's EdDSA
/// signature (SUPublicEDKey in Info.plist); no Apple notarization is involved.
@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    /// Mirrors `SPUUpdater.canCheckForUpdates` so the menu item can disable
    /// itself while a check is already in flight.
    @Published private(set) var canCheckForUpdates = false

    private let controller: SPUStandardUpdaterController

    private init() {
        // startingUpdater: true → begin the scheduled background checks now,
        // honoring SUEnableAutomaticChecks / SUScheduledCheckInterval.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    /// Manual check — shows Sparkle's standard "up to date" / "update available"
    /// UI. Safe to call repeatedly; Sparkle coalesces concurrent checks.
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
