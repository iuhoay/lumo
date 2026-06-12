import AppKit
import CoreGraphics
import Testing
@testable import Lumo

@Suite("OCRService")
struct OCRServiceTests {
    @Test("recognizes clear English screen text")
    func recognizesClearEnglishScreenText() async throws {
        let image = try #require(makeTextImage("Lumo screen text"))
        let result = try await OCRService.shared.recognizeText(in: image)

        #expect(result.text.localizedCaseInsensitiveContains("Lumo"))
        #expect(result.text.localizedCaseInsensitiveContains("screen"))
        #expect(result.lines.isEmpty == false)
    }

    @Test("recognizes clear Simplified Chinese screen text")
    func recognizesClearSimplifiedChineseScreenText() async throws {
        let image = try #require(makeTextImage("屏幕文字测试"))
        let result = try await OCRService.shared.recognizeText(in: image)

        #expect(result.text.contains("屏幕") || result.text.contains("文字"))
        #expect(result.lines.isEmpty == false)
    }
}

private func makeTextImage(_ text: String) -> CGImage? {
    let size = NSSize(width: 720, height: 180)
    guard let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    defer { NSGraphicsContext.restoreGraphicsState() }

    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 54, weight: .semibold),
        .foregroundColor: NSColor.black
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)
    attributed.draw(at: NSPoint(x: 48, y: 58))

    return context.makeImage()
}
