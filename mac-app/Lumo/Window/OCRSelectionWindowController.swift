import AppKit

enum OCRSelectionResult {
    case selected(OCRSelectionRegion)
    case cancelled
}

struct OCRSelectionRegion: Equatable {
    var appKitRect: CGRect
    var screenFrame: CGRect
}

@MainActor
final class OCRSelectionWindowController {
    static let shared = OCRSelectionWindowController()

    private var windows: [NSWindow] = []
    private var completion: ((OCRSelectionResult) -> Void)?

    private init() {}

    func beginSelection(completion: @escaping (OCRSelectionResult) -> Void) {
        cancelActiveSelection()
        self.completion = completion

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            finish(.cancelled)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        windows = screens.map { makeWindow(for: $0) }
        windows.forEach { $0.orderFrontRegardless() }
        windows.first?.makeKey()
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let view = OCRSelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.onComplete = { [weak self, weak view] localRect in
            guard let self, let view, let window = view.window else { return }
            let windowRect = view.convert(localRect, to: nil)
            let screenRect = window.convertToScreen(windowRect)
            self.finish(.selected(OCRSelectionRegion(appKitRect: screenRect, screenFrame: screen.frame)))
        }
        view.onCancel = { [weak self] in
            self?.finish(.cancelled)
        }

        let window = OCRSelectionWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.contentView = view
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        return window
    }

    private func cancelActiveSelection() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        completion = nil
    }

    private func finish(_ result: OCRSelectionResult) {
        let completion = completion
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        self.completion = nil
        completion?(result)
    }
}

private final class OCRSelectionWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func cancelOperation(_: Any?) {
        (contentView as? OCRSelectionView)?.cancel()
    }
}

private final class OCRSelectionView: NSView {
    var onComplete: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        currentPoint = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        let rect = selectionRect
        guard rect.width >= 6, rect.height >= 6 else {
            cancel()
            return
        }
        onComplete?(rect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            cancel()
        } else {
            super.keyDown(with: event)
        }
    }

    func cancel() {
        onCancel?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(NSColor.black.withAlphaComponent(0.28).cgColor)
        context.fill(bounds)

        let rect = selectionRect
        if rect.width > 0, rect.height > 0 {
            context.saveGState()
            context.setBlendMode(.clear)
            context.fill(rect)
            context.restoreGState()

            NSColor.controlAccentColor.setStroke()
            let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
            path.lineWidth = 2
            path.stroke()
        }

        drawInstruction()
    }

    private var selectionRect: NSRect {
        guard let startPoint, let currentPoint else { return .zero }
        return NSRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(startPoint.x - currentPoint.x),
            height: abs(startPoint.y - currentPoint.y)
        )
    }

    private func drawInstruction() {
        let message = String(localized: "Drag to select text. Press Esc to cancel.")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.45)
        ]
        let attributed = NSAttributedString(string: message, attributes: attributes)
        let size = attributed.size()
        let rect = NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.maxY - size.height - 36,
            width: size.width,
            height: size.height
        )
        attributed.draw(in: rect)
    }
}
