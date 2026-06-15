import AppKit
import QuartzCore
import SwiftUI

/// Shared geometry for the glass popup. The window's content-layer corner mask
/// and the SwiftUI `.glassEffect` shape MUST use the same radius, or a square
/// backing shows behind the rounded glass (the "two borders" artifact).
enum GlassPanelMetrics {
    static let cornerRadius: CGFloat = 20
}

/// Two-way bridge between `TranslationView` (which knows its laid-out height) and
/// `TranslationWindowController` (which owns the NSWindow frame). The controller
/// pushes the per-screen result cap down; the view pushes its preferred height
/// and streaming state back up. Kept as a tiny ObservableObject so `maxResultHeight`
/// drives a SwiftUI re-layout while the callbacks stay plain (non-`@Published`).
@MainActor
final class TranslationSizing: ObservableObject {
    /// Max height the result region may occupy before it scrolls, set by the
    /// controller from the pointer screen at present time. Drives the window's
    /// grow-to-fit ceiling; beyond it the result scrolls inside a fixed box.
    @Published var maxResultHeight: CGFloat = 420
    /// Preferred total content height the window should adopt (chrome + result).
    var onHeight: ((CGFloat) -> Void)?
    /// Streaming edge: `false` once a request finishes, so the window can settle
    /// to an exact fit after a grow-only stream.
    var onStreaming: ((Bool) -> Void)?
}

/// Borderless window for the floating glass popup. A plain `NSWindow` cannot
/// become key while borderless (controls and text selection would be dead), so
/// we override `canBecomeKey`/`canBecomeMain`. Esc routes through `onCancel` so
/// it shares the controller's single dismissal path, since there is no titlebar
/// close button.
@MainActor
private final class TranslationPanelWindow: NSWindow {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func cancelOperation(_: Any?) {
        onCancel?()
    }
}

/// Owns the floating translation window: a single reusable borderless NSWindow
/// that hosts the SwiftUI `TranslationView` (a Liquid Glass slab) and is
/// positioned near the mouse pointer.
@MainActor
final class TranslationWindowController {
    private weak var model: AppModel?
    private var window: NSWindow?
    private var tabMonitor: Any?
    private let sizing = TranslationSizing()

    /// Visible frame of the pointer's screen, captured on present and reused to
    /// clamp every later resize so a growing window never runs off-screen.
    private var currentVisibleFrame: NSRect?
    /// Most recent preferred height reported by the view; the value the window
    /// settles to when a grow-only stream finishes.
    private var lastReportedHeight: CGFloat = 0
    /// Grow-only ratchet during streaming: the window climbs to fit new tokens
    /// but doesn't shrink on a mid-stream reflow. Reset at each stream's start.
    private var growFloor: CGFloat = 0

    /// Non-result chrome (header, input, buttons, divider, paddings) is fixed, so
    /// the result cap is the screen budget minus a constant allowance. Slightly
    /// over the real ~235pt so `chrome + cap` always stays under the 85% ceiling
    /// (no clipping); a few points of early scroll is invisible.
    private let chromeAllowance: CGFloat = 250
    /// Fraction of the pointer screen's visible frame the window may fill before
    /// the result scrolls instead of growing.
    private let maxScreenFraction: CGFloat = 0.85

    init(model: AppModel) {
        self.model = model
        sizing.onHeight = { [weak self] in self?.applyReportedHeight($0) }
        sizing.onStreaming = { [weak self] in self?.settleAfterStreaming($0) }
    }

    func present() {
        let window = ensureWindow()
        let visible = pointerScreenVisibleFrame()
        currentVisibleFrame = visible
        sizing.maxResultHeight = resultCap(for: visible)
        // Open compact and let the view's height reports grow it to fit; a reused
        // window otherwise flashes the previous result's (possibly tall) size.
        growFloor = 0
        resetToBaselineHeight(window)
        positionNearMouse(window, in: visible)
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

        let root = TranslationView(sizing: sizing).environmentObject(model ?? AppModel.shared)
        let hosting = NSHostingController(rootView: root)
        // Borderless so the Liquid Glass slab IS the whole window: no titlebar
        // means no traffic-light buttons floating detached above the panel, and
        // the glass fills edge-to-edge with its own rounded corners.
        let window = TranslationPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 340),
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
        window.minSize = NSSize(width: 440, height: 300)

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
        installTabMonitor()
        return window
    }

    /// Watch for a bare ⇥ to pull the clipboard into the empty window and
    /// translate. A local monitor (rather than SwiftUI `.onKeyPress`) so the tab
    /// is caught before `TextEditor` inserts it as a literal character. Gated
    /// hard — our window key, no modifiers, input empty, clipboard non-empty — so
    /// it stays inert everywhere else (incl. a real Tab once the user has typed).
    private func installTabMonitor() {
        guard tabMonitor == nil else { return }
        // Pull the Sendable bits off the event before hopping onto the main actor
        // so the non-Sendable NSEvent never crosses the isolation boundary.
        tabMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = event.keyCode
            let modifiers = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .subtracting(.capsLock)
            let swallow = MainActor.assumeIsolated {
                self?.handleTabKey(keyCode: keyCode, modifiers: modifiers) ?? false
            }
            return swallow ? nil : event // nil swallows the tab; else pass it through
        }
    }

    private func handleTabKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        let kVK_Tab: UInt16 = 48
        guard keyCode == kVK_Tab, modifiers.isEmpty,
              window?.isKeyWindow == true,
              let model, model.inputText.isEmpty, model.clipboardText != nil
        else { return false }
        model.pasteClipboardAndTranslate()
        return true
    }

    /// Visible frame of the screen under the pointer, with a conservative
    /// fallback so resize math always has a frame to clamp into.
    private func pointerScreenVisibleFrame() -> NSRect {
        let mouse = NSEvent.mouseLocation // global coords, bottom-left origin
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    /// Result-region ceiling for a screen: the window may fill `maxScreenFraction`
    /// of the visible frame, minus the fixed chrome. Floored so a short screen
    /// still leaves a usable result box.
    private func resultCap(for visible: NSRect) -> CGFloat {
        max(160, floor(visible.height * maxScreenFraction) - chromeAllowance)
    }

    /// Collapse a reused window back to its minimum before showing, so the
    /// grow-to-fit animation always starts compact instead of from a stale size.
    private func resetToBaselineHeight(_ window: NSWindow) {
        var frame = window.frame
        frame.size.height = window.minSize.height
        window.setFrame(frame, display: false)
    }

    /// Places the window near the pointer: below-right when there's room,
    /// otherwise above. Clamped to the visible frame of the pointer's screen.
    private func positionNearMouse(_ window: NSWindow, in visible: NSRect) {
        let mouse = NSEvent.mouseLocation // global coords, bottom-left origin
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

    /// View → controller: the preferred total content height changed. During a
    /// stream we grow only (ratchet up; reset at the first, empty-output frame so
    /// a fresh request can start small); otherwise we adopt the exact height.
    private func applyReportedHeight(_ contentHeight: CGFloat) {
        lastReportedHeight = contentHeight
        let target: CGFloat
        if model?.isLoading == true {
            if model?.output.isEmpty == true { growFloor = contentHeight } // new stream
            growFloor = max(growFloor, contentHeight)
            target = growFloor
        } else {
            target = contentHeight
        }
        resizeWindow(toContentHeight: target, animated: window?.isVisible == true)
    }

    /// View → controller: streaming just ended. Settle to the exact final fit so a
    /// mid-stream reflow that briefly grew the window (e.g. a table forming) doesn't
    /// leave slack the grow-only ratchet would otherwise keep.
    private func settleAfterStreaming(_ loading: Bool) {
        guard !loading else { return }
        resizeWindow(toContentHeight: lastReportedHeight, animated: window?.isVisible == true)
    }

    /// Resize the window to `contentHeight`, clamped to `[minSize, 85% of screen]`,
    /// keeping the top edge (the corner near the pointer) fixed so growth flows
    /// downward, then re-clamping the origin back into the visible frame.
    private func resizeWindow(toContentHeight contentHeight: CGFloat, animated: Bool) {
        guard let window else { return }
        let visible = currentVisibleFrame ?? window.screen?.visibleFrame ?? pointerScreenVisibleFrame()

        let ceiling = max(window.minSize.height, floor(visible.height * maxScreenFraction))
        let height = min(max(contentHeight.rounded(), window.minSize.height), ceiling)

        let old = window.frame
        guard abs(old.height - height) >= 1 else { return } // ignore sub-point churn

        var origin = NSPoint(x: old.minX, y: old.maxY - height) // anchor the top edge
        origin.x = min(max(origin.x, visible.minX), visible.maxX - old.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - height)
        let frame = NSRect(x: origin.x, y: origin.y, width: old.width, height: height)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: false)
        }
        window.invalidateShadow() // shadow follows the rounded glass shape as it resizes
    }
}
