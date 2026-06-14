import Foundation
import SwiftUI

/// Renders a result as raw, selectable text — exactly what the model produced,
/// markdown markers and all — with one exception: GFM tables are lifted out and
/// drawn as a bordered grid, because a table is the one construct that's
/// unreadable in its raw `| --- |` form.
///
/// The plain-text path is byte-identical to a single `Text(output)`: when the
/// output contains no table, `ResultSegment.parse` returns the original string
/// untouched and we render exactly one `Text`.
struct MarkdownResultText: View {
    let text: String

    var body: some View {
        let segments = ResultSegment.parse(text)

        if segments.count == 1, case let .text(raw) = segments[0] {
            rawText(raw)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case let .text(raw):
                        rawText(raw)
                    case let .table(table):
                        TableGrid(table: table)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rawText(_ raw: String) -> some View {
        Text(raw)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Parsing

enum ColumnAlignment: Equatable {
    case leading, center, trailing

    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var text: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

struct MarkdownTable: Equatable {
    let header: [String]
    let alignments: [ColumnAlignment]
    let rows: [[String]]
}

enum ResultSegment: Equatable {
    case text(String)
    case table(MarkdownTable)

    /// Splits raw output into runs of plain text and GFM table blocks. A table
    /// is recognised only when a row is immediately followed by a delimiter row
    /// (`| --- | :--: |`), so partial markup arriving mid-stream stays plain
    /// text until the delimiter line is complete.
    static func parse(_ text: String) -> [ResultSegment] {
        let lines = text.components(separatedBy: "\n")
        var segments: [ResultSegment] = []
        var textBuffer: [String] = []

        func flushText() {
            guard !textBuffer.isEmpty else { return }
            segments.append(.text(textBuffer.joined(separator: "\n")))
            textBuffer.removeAll()
        }

        var i = 0
        while i < lines.count {
            if i + 1 < lines.count,
               looksLikeRow(lines[i]),
               isDelimiterRow(lines[i + 1])
            {
                let header = cells(lines[i])
                let alignments = parseAlignments(lines[i + 1], columnCount: header.count)
                var rows: [[String]] = []
                var j = i + 2
                while j < lines.count,
                      !lines[j].trimmingCharacters(in: .whitespaces).isEmpty,
                      looksLikeRow(lines[j])
                {
                    rows.append(cells(lines[j], padTo: header.count))
                    j += 1
                }
                flushText()
                segments.append(.table(MarkdownTable(header: header, alignments: alignments, rows: rows)))
                i = j
            } else {
                textBuffer.append(lines[i])
                i += 1
            }
        }
        flushText()

        // No table found → hand back the original string verbatim.
        if segments.count == 1, case .text = segments[0] {
            return [.text(text)]
        }
        return segments.isEmpty ? [.text(text)] : segments
    }

    static func looksLikeRow(_ line: String) -> Bool {
        line.contains("|")
    }

    static func isDelimiterRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("-") else { return false }
        let parsed = splitCells(trimmed)
        guard !parsed.isEmpty else { return false }
        return parsed.allSatisfy { cell in
            var c = Substring(cell)
            if c.first == ":" { c = c.dropFirst() }
            if c.last == ":" { c = c.dropLast() }
            return !c.isEmpty && c.allSatisfy { $0 == "-" }
        }
    }

    static func splitCells(_ line: String) -> [String] {
        var s = Substring(line.trimmingCharacters(in: .whitespaces))
        if s.hasPrefix("|") { s = s.dropFirst() }
        if s.hasSuffix("|") { s = s.dropLast() }
        return String(s).components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    static func cells(_ line: String, padTo count: Int? = nil) -> [String] {
        var result = splitCells(line)
        guard let count else { return result }
        if result.count < count {
            result += Array(repeating: "", count: count - result.count)
        } else if result.count > count {
            result = Array(result.prefix(count))
        }
        return result
    }

    static func parseAlignments(_ delimiterLine: String, columnCount: Int) -> [ColumnAlignment] {
        var aligns = splitCells(delimiterLine).map { cell -> ColumnAlignment in
            let left = cell.hasPrefix(":")
            let right = cell.hasSuffix(":")
            if left, right { return .center }
            if right { return .trailing }
            return .leading
        }
        if aligns.count < columnCount {
            aligns += Array(repeating: .leading, count: columnCount - aligns.count)
        } else if aligns.count > columnCount {
            aligns = Array(aligns.prefix(columnCount))
        }
        return aligns
    }
}

// MARK: - Speech

extension ResultSegment {
    /// A speech-friendly plain-text rendering of raw model output. Tables become
    /// comma-separated cells (the `| --- |` delimiter row is already dropped by
    /// `parse`), and inline/block markdown markers (`**`, `*`, `` ` ``, `~~`,
    /// leading `#`, `>`, list bullets, link URLs, fences, thematic breaks) are
    /// stripped so the synthesizer reads prose instead of "asterisk" or
    /// "vertical bar". Plain text without markup is returned unchanged.
    static func spokenText(_ raw: String) -> String {
        parse(raw)
            .map { segment in
                switch segment {
                case let .text(text): return spokenParagraphs(text)
                case let .table(table): return spokenTable(table)
                }
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func spokenTable(_ table: MarkdownTable) -> String {
        ([table.header] + table.rows)
            .map { row in
                row.map { stripInlineMarkers($0).trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
            }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }

    private static func spokenParagraphs(_ text: String) -> String {
        var lines: [String] = []
        var inFence = false
        for rawLine in text.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                continue
            }
            if inFence {
                lines.append(rawLine) // speak code body verbatim, without the fence
                continue
            }
            if isThematicBreak(trimmed) { continue }
            lines.append(stripInlineMarkers(stripBlockPrefix(rawLine)))
        }
        return lines.joined(separator: "\n")
    }

    private static func isThematicBreak(_ trimmed: String) -> Bool {
        guard trimmed.count >= 3 else { return false }
        let chars = Set(trimmed.filter { $0 != " " })
        return chars.count == 1 && (chars == ["-"] || chars == ["*"] || chars == ["_"])
    }

    /// Drops a single leading block marker: heading `#`s, blockquote `>`s, or an
    /// unordered/ordered list bullet. Content is preserved.
    private static func stripBlockPrefix(_ line: String) -> String {
        var s = Substring(line)
        while s.first == " " || s.first == "\t" { s = s.dropFirst() }

        while s.first == ">" {
            s = s.dropFirst()
            while s.first == " " { s = s.dropFirst() }
        }

        let hashes = s.prefix(while: { $0 == "#" })
        if (1 ... 6).contains(hashes.count), s.dropFirst(hashes.count).first == " " {
            s = s.dropFirst(hashes.count)
            while s.first == " " { s = s.dropFirst() }
            return String(s)
        }

        if let marker = s.first, marker == "-" || marker == "*" || marker == "+",
           s.dropFirst().first == " " {
            s = s.dropFirst(2)
            while s.first == " " { s = s.dropFirst() }
            return String(s)
        }

        let digits = s.prefix(while: { $0.isNumber })
        if !digits.isEmpty {
            let afterDigits = s.dropFirst(digits.count)
            if let sep = afterDigits.first, sep == "." || sep == ")",
               afterDigits.dropFirst().first == " " {
                s = afterDigits.dropFirst(2)
                while s.first == " " { s = s.dropFirst() }
                return String(s)
            }
        }
        return String(s)
    }

    /// Unwraps `[text](url)` / `![alt](url)` to their label and removes emphasis,
    /// code, and strikethrough markers. A single `_` is left alone so identifiers
    /// like `snake_case` aren't merged.
    private static func stripInlineMarkers(_ text: String) -> String {
        var result = unwrapLinks(text)
        for marker in ["**", "__", "~~", "*", "`"] {
            result = result.replacingOccurrences(of: marker, with: "")
        }
        return result
    }

    private static let linkPattern = try? NSRegularExpression(pattern: #"!?\[([^\]]*)\]\([^)]*\)"#)

    private static func unwrapLinks(_ text: String) -> String {
        guard let linkPattern else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return linkPattern.stringByReplacingMatches(in: text, range: range, withTemplate: "$1")
    }
}

// MARK: - Rendering

private struct TableGrid: View {
    let table: MarkdownTable

    private let borderColor = Color.secondary.opacity(0.35)

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(Array(table.header.enumerated()), id: \.offset) { index, cell in
                    self.cell(cell, column: index, isHeader: true)
                }
            }
            ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { index, cell in
                        self.cell(cell, column: index, isHeader: false)
                    }
                }
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cell(_ value: String, column: Int, isHeader: Bool) -> some View {
        let alignment = column < table.alignments.count ? table.alignments[column] : .leading
        return Text(value)
            .font(isHeader ? .body.weight(.semibold) : .body)
            .multilineTextAlignment(alignment.text)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment.horizontal, vertical: .center))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isHeader ? Color.secondary.opacity(0.08) : Color.clear)
            .border(borderColor, width: 0.5)
    }
}
