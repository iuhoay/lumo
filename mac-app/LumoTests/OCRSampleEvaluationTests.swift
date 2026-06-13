import AppKit
import Testing
@testable import Lumo

@Suite("OCR sample evaluation")
struct OCRSampleEvaluationTests {
    @Test("evaluates real OCR fixtures")
    func evaluatesRealOCRFixtures() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let sampleDirectory = environment["LUMO_OCR_SAMPLE_DIR"], !sampleDirectory.isEmpty else {
            return
        }

        let sampleURL = URL(fileURLWithPath: sampleDirectory, isDirectory: true)
        let outputURL = URL(fileURLWithPath: environment["LUMO_OCR_EVAL_OUTPUT_DIR"] ?? "build/ocr-eval", isDirectory: true)
        let strict = environment["LUMO_OCR_EVAL_STRICT"] == "1"
        let samples = try OCRSample.load(from: sampleURL)

        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        var rows: [OCREvaluationRow] = []

        for sample in samples {
            let recognized = try await OCRService.shared.recognizeText(in: sample.image).text
            let score = textSimilarity(recognized, sample.expectedText)
            let status = score >= sample.threshold ? "pass" : (sample.required ? "fail" : "warn")
            let row = OCREvaluationRow(
                name: sample.name,
                score: score,
                threshold: sample.threshold,
                recognizedCharacterCount: normalizedText(recognized).count,
                expectedCharacterCount: normalizedText(sample.expectedText).count,
                status: status
            )
            rows.append(row)
            try writeSampleReport(sample: sample, recognized: recognized, score: score, status: status, to: outputURL)

            if strict, sample.required {
                #expect(score >= sample.threshold, "OCR score for \(sample.name) was \(score), below \(sample.threshold)")
            }
        }

        try writeSummary(rows, to: outputURL)
        print(summaryTable(rows))
    }
}

private struct OCRSample {
    var name: String
    var image: CGImage
    var expectedText: String
    var threshold: Double
    var required: Bool

    static func load(from directory: URL) throws -> [OCRSample] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let imageURLs = enumerator
            .compactMap { $0 as? URL }
            .filter { ["png", "jpg", "jpeg", "tiff"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.path < $1.path }

        return try imageURLs.compactMap { imageURL in
            let expectedURL = imageURL.deletingPathExtension().appendingPathExtension("expected.txt")
            guard FileManager.default.fileExists(atPath: expectedURL.path) else {
                throw OCREvaluationError.missingExpectedText(expectedURL.path)
            }
            guard let image = NSImage(contentsOf: imageURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw OCREvaluationError.unreadableImage(imageURL.path)
            }

            let meta = sampleMetadata(for: imageURL)
            return try OCRSample(
                name: imageURL.deletingPathExtension().lastPathComponent,
                image: image,
                expectedText: String(contentsOf: expectedURL, encoding: .utf8),
                threshold: meta.threshold,
                required: meta.required
            )
        }
    }

    private static func sampleMetadata(for imageURL: URL) -> (threshold: Double, required: Bool) {
        let metadataURL = imageURL.deletingPathExtension().appendingPathExtension("meta.json")
        guard let data = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode(OCRSampleMetadata.self, from: data)
        else { return (0.85, true) }
        return (metadata.threshold ?? 0.85, metadata.required ?? true)
    }
}

private struct OCRSampleMetadata: Decodable {
    var threshold: Double?
    var required: Bool?
}

private struct OCREvaluationRow {
    var name: String
    var score: Double
    var threshold: Double
    var recognizedCharacterCount: Int
    var expectedCharacterCount: Int
    var status: String
}

private enum OCREvaluationError: Error {
    case missingExpectedText(String)
    case unreadableImage(String)
}

private func writeSampleReport(sample: OCRSample, recognized: String, score: Double, status: String, to outputURL: URL) throws {
    let directory = outputURL.appendingPathComponent(sample.name, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try recognized.write(to: directory.appendingPathComponent("recognized.txt"), atomically: true, encoding: .utf8)
    try sample.expectedText.write(to: directory.appendingPathComponent("expected.txt"), atomically: true, encoding: .utf8)

    let report = """
    status: \(status)
    score: \(String(format: "%.3f", score))
    threshold: \(String(format: "%.3f", sample.threshold))

    \(textDiff(expected: sample.expectedText, recognized: recognized))
    """
    try report.write(to: directory.appendingPathComponent("diff.txt"), atomically: true, encoding: .utf8)
}

private func writeSummary(_ rows: [OCREvaluationRow], to outputURL: URL) throws {
    let header = "sample\tscore\tthreshold\trecognized_chars\texpected_chars\tstatus"
    let body = rows.map {
        [
            $0.name,
            String(format: "%.3f", $0.score),
            String(format: "%.3f", $0.threshold),
            String($0.recognizedCharacterCount),
            String($0.expectedCharacterCount),
            $0.status
        ].joined(separator: "\t")
    }
    try ([header] + body).joined(separator: "\n").write(
        to: outputURL.appendingPathComponent("summary.tsv"),
        atomically: true,
        encoding: .utf8
    )
}

private func summaryTable(_ rows: [OCREvaluationRow]) -> String {
    guard !rows.isEmpty else { return "No OCR samples found." }
    let lines = rows.map {
        "\($0.name)\t\(String(format: "%.3f", $0.score))\t\($0.status)"
    }
    return (["sample\tscore\tstatus"] + lines).joined(separator: "\n")
}

private func textDiff(expected: String, recognized: String) -> String {
    let expectedLines = expected.split(whereSeparator: \.isNewline).map(String.init)
    let recognizedLines = recognized.split(whereSeparator: \.isNewline).map(String.init)
    let maxCount = max(expectedLines.count, recognizedLines.count)

    return (0 ..< maxCount).map { index in
        let expectedLine = index < expectedLines.count ? expectedLines[index] : ""
        let recognizedLine = index < recognizedLines.count ? recognizedLines[index] : ""
        if expectedLine == recognizedLine {
            return "  \(expectedLine)"
        }
        return """
        - \(expectedLine)
        + \(recognizedLine)
        """
    }.joined(separator: "\n")
}

private func textSimilarity(_ lhs: String, _ rhs: String) -> Double {
    let lhs = normalizedText(lhs)
    let rhs = normalizedText(rhs)
    guard !lhs.isEmpty || !rhs.isEmpty else { return 1 }
    guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }

    let distance = levenshteinDistance(Array(lhs), Array(rhs))
    return 1 - (Double(distance) / Double(max(lhs.count, rhs.count)))
}

private func normalizedText(_ text: String) -> String {
    text
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
}

private func levenshteinDistance(_ lhs: [Character], _ rhs: [Character]) -> Int {
    var previous = Array(0 ... rhs.count)
    var current = Array(repeating: 0, count: rhs.count + 1)

    for (lhsIndex, lhsCharacter) in lhs.enumerated() {
        current[0] = lhsIndex + 1
        for (rhsIndex, rhsCharacter) in rhs.enumerated() {
            current[rhsIndex + 1] = min(
                previous[rhsIndex + 1] + 1,
                current[rhsIndex] + 1,
                previous[rhsIndex] + (lhsCharacter == rhsCharacter ? 0 : 1)
            )
        }
        swap(&previous, &current)
    }
    return previous[rhs.count]
}
