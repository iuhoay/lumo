import CoreGraphics
import Foundation
import Vision

struct OCRLine: Equatable {
    var text: String
    var confidence: Float
    var boundingBox: CGRect
}

struct OCRResult: Equatable {
    var text: String
    var lines: [OCRLine]
}

enum OCRServiceError: LocalizedError {
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return String(localized: "No readable text was found in the selected area.")
        }
    }
}

final class OCRService {
    static let shared = OCRService()

    private init() {}

    func recognizeText(in image: CGImage) async throws -> OCRResult {
        try await Task.detached(priority: .userInitiated) {
            let prepared = Self.preparedImage(from: image)
            let candidates = try [
                Self.recognize(prepared, configuration: .zhHansEnglish),
                Self.recognize(prepared, configuration: .automaticLanguage),
                Self.recognize(image, configuration: .automaticLanguage)
            ]

            guard let best = candidates.max(by: { Self.score($0) < Self.score($1) }),
                  !best.text.isEmpty
            else { throw OCRServiceError.noTextFound }
            return best
        }.value
    }

    private static func recognize(_ image: CGImage, configuration: OCRConfiguration) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = configuration.usesLanguageCorrection
        request.automaticallyDetectsLanguage = configuration.automaticallyDetectsLanguage
        request.recognitionLanguages = configuration.recognitionLanguages
        request.minimumTextHeight = 0.0

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let lines = (request.results ?? [])
            .compactMap(Self.line(from:))
            .sorted(by: Self.readingOrder)
        let text = lines
            .map(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return OCRResult(text: text, lines: lines)
    }

    private static func line(from observation: VNRecognizedTextObservation) -> OCRLine? {
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return OCRLine(text: text, confidence: candidate.confidence, boundingBox: observation.boundingBox)
    }

    private static func readingOrder(_ lhs: OCRLine, _ rhs: OCRLine) -> Bool {
        let yDelta = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
        if yDelta > 0.025 {
            return lhs.boundingBox.midY > rhs.boundingBox.midY
        }
        return lhs.boundingBox.minX < rhs.boundingBox.minX
    }

    private static func score(_ result: OCRResult) -> Double {
        guard !result.text.isEmpty, !result.lines.isEmpty else { return 0 }
        let averageConfidence = result.lines.reduce(0) { $0 + Double($1.confidence) } / Double(result.lines.count)
        let usefulLength = min(Double(result.text.count), 400)
        return averageConfidence * 1000 + usefulLength
    }

    private static func preparedImage(from image: CGImage) -> CGImage {
        let maxSide = max(image.width, image.height)
        let scale = maxSide < 2000 ? 2.0 : min(1.5, 4000.0 / Double(maxSide))
        guard scale > 1.05 else { return image }

        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        context.interpolationQuality = .high
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}

private struct OCRConfiguration {
    var recognitionLanguages: [String]
    var automaticallyDetectsLanguage: Bool
    var usesLanguageCorrection: Bool

    static let zhHansEnglish = OCRConfiguration(
        recognitionLanguages: ["zh-Hans", "en-US"],
        automaticallyDetectsLanguage: false,
        usesLanguageCorrection: true
    )

    static let automaticLanguage = OCRConfiguration(
        recognitionLanguages: [],
        automaticallyDetectsLanguage: true,
        usesLanguageCorrection: true
    )
}
