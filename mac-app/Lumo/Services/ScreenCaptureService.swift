import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

enum ScreenCaptureServiceError: Equatable, LocalizedError {
    case invalidSelection
    case noImage
    case screenRecordingPermissionDenied

    var errorDescription: String? {
        switch self {
        case .invalidSelection:
            return String(localized: "Select a larger screen area to read.")
        case .noImage:
            return String(localized: "Lumo could not capture the selected screen area.")
        case .screenRecordingPermissionDenied:
            return String(localized: "Screen Recording permission is required for OCR. Grant access in System Settings, then restart Lumo.")
        }
    }
}

enum ScreenCaptureService {
    static var hasScreenCaptureAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @MainActor
    static func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    static func captureImage(in region: OCRSelectionRegion) async throws -> CGImage {
        let captureRect = captureRect(for: region.appKitRect, in: region.screenFrame)
        let normalized = captureRect.standardized.integral
        guard normalized.width >= 4, normalized.height >= 4 else {
            throw ScreenCaptureServiceError.invalidSelection
        }

        let image: CGImage = try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(in: normalized) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ScreenCaptureServiceError.noImage)
                }
            }
        }
        debugDump(image: image, appKitRect: region.appKitRect, captureRect: normalized)
        return image
    }

    static func captureRect(for appKitRect: CGRect, in screenFrame: CGRect) -> CGRect {
        let rect = appKitRect.standardized
        let localMinY = rect.minY - screenFrame.minY
        let flippedMinY = screenFrame.height - localMinY - rect.height
        return CGRect(
            x: rect.minX,
            y: screenFrame.minY + flippedMinY,
            width: rect.width,
            height: rect.height
        )
    }

    private static func debugDump(image: CGImage, appKitRect: CGRect, captureRect: CGRect) {
        #if DEBUG
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
                "LumoOCRDebug",
                isDirectory: true
            )
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let imageURL = directory.appendingPathComponent("last-capture.png")
            let metadataURL = directory.appendingPathComponent("last-capture.txt")
            let bitmap = NSBitmapImageRep(cgImage: image)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                try? data.write(to: imageURL)
            }

            let metadata = """
            appKitRect=\(appKitRect)
            captureRect=\(captureRect)
            imageSize=\(image.width)x\(image.height)
            """
            try? metadata.write(to: metadataURL, atomically: true, encoding: .utf8)
        #endif
    }
}
