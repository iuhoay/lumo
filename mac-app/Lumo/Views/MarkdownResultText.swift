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
