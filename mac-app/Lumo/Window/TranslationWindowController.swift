import AppKit
import SwiftUI

/// Shared geometry for the glass popup. The window's content-layer corner mask
/// and the SwiftUI `.glassEffect` shape MUST use the same radius, or a square
/// backing shows behind the rounded glass (the "two borders" artifact).
enum GlassPanelMetrics {
    static let cornerRadius: CGFloat = 20
}

/// Borderless window for the floating glass popup. A plain `NSWindow` cannot
/// become key while borderless (controls and text selection would be dead), so
/// we override `canBecomeKey`/`canBecomeMain`. Esc routes through `onCancel` so
/// it shares the controller's single dismissal path, since there is no titlebar
/// close button.
@MainActor
private final class TranslationPanelWindow: NSWindow {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

/// Owns the floating translation window: a single reusable borderless NSWindow
/// that hosts the SwiftUI `TranslationView` (a Liquid Glass slab) and is
/// positioned near the mouse pointer.
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
        window.invalidateShadow() // shadow follows the rounded glass shape
    }

    /// Keep the window above other apps' windows when pinned.
    func setPinned(_ pinned: Bool) {
        window?.level = pinned ? .floating : .normal
    }

    /// Hide the panel (the in-panel close button and Esc both route here).
    func close() {
        window?.orderOut(nil)
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }

        let root = TranslationView().environmentObject(model ?? AppModel.shared)
        let hosting = NSHostingController(rootView: root)
        // Borderless so the Liquid Glass slab IS the whole window: no titlebar
        // means no traffic-light buttons floating detached above the panel, and
        // the glass fills edge-to-edge with its own rounded corners.
        let window = TranslationPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        // Esc (cancelOperation) shares the same dismissal path as the in-panel
        // close button, so any future teardown added to close() applies to both.
        window.onCancel = { [weak self] in self?.close() }
        // Clear, non-opaque so the glass refracts the desktop and the window
        // shadow hugs the rounded slab rather than a square frame.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        // Keep in sync with TranslationView's frame minWidth: a narrower window
        // clips the header toolbar's trailing buttons under the rounded mask.
        window.minSize = NSSize(width: 440, height: 240)

        // Clip the content view's layer to the same rounded rect as the glass.
        // Without this, the hosting view fills the square window bounds and a
        // square backing shows around the rounded .glassEffect — the "two
        // borders" (one rounded, one right-angled) artifact.
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = GlassPanelMetrics.cornerRadius
            contentView.layer?.cornerCurve = .continuous
            contentView.layer?.masksToBounds = true
            contentView.layer?.backgroundColor = .clear
        }

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
