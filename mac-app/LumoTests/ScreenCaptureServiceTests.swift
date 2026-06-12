import CoreGraphics
import Testing
@testable import Lumo

@Suite("ScreenCaptureService")
struct ScreenCaptureServiceTests {
    @Test("converts AppKit bottom-left rects to top-left capture rects")
    func convertsMainScreenRect() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let appKitRect = CGRect(x: 100, y: 100, width: 300, height: 200)

        let captureRect = ScreenCaptureService.captureRect(for: appKitRect, in: screen)

        #expect(captureRect == CGRect(x: 100, y: 600, width: 300, height: 200))
    }

    @Test("keeps the conversion relative to the selected screen frame")
    func convertsOffsetScreenRect() {
        let screen = CGRect(x: 1440, y: -900, width: 1440, height: 900)
        let appKitRect = CGRect(x: 1500, y: -800, width: 320, height: 120)

        let captureRect = ScreenCaptureService.captureRect(for: appKitRect, in: screen)

        #expect(captureRect == CGRect(x: 1500, y: -220, width: 320, height: 120))
    }
}
