import Foundation
import Testing
@testable import Lumo

struct ResultSegmentParsingTests {
    @Test func plainTextWithoutTableIsReturnedVerbatim() {
        let input = "Line one\n\n- a raw **bullet**\nLine with `code` and a | pipe\n"
        let segments = ResultSegment.parse(input)

        #expect(segments.count == 1)
        #expect(segments[0] == .text(input))
    }

    @Test func recognizesDelimiterRows() {
        #expect(ResultSegment.isDelimiterRow("| --- | :---: | ---: |"))
        #expect(ResultSegment.isDelimiterRow("---|---"))
        #expect(ResultSegment.isDelimiterRow(":-:"))
        #expect(!ResultSegment.isDelimiterRow("| -- x | --- |"))
        #expect(!ResultSegment.isDelimiterRow("just a sentence"))
        #expect(!ResultSegment.isDelimiterRow("| header | row |"))
    }

    @Test func parsesAStandaloneTable() {
        let input = """
        | Feature | A | B |
        | --- | :--: | ---: |
        | Correctness | low | high |
        | Deps | none | three |
        """
        let segments = ResultSegment.parse(input)

        #expect(segments.count == 1)
        guard case let .table(table) = segments[0] else {
            Issue.record("expected a table segment")
            return
        }
        #expect(table.header == ["Feature", "A", "B"])
        #expect(table.alignments == [.leading, .center, .trailing])
        #expect(table.rows == [["Correctness", "low", "high"], ["Deps", "none", "three"]])
    }

    @Test func surroundingTextStaysSeparateAndRaw() {
        let input = """
        Here is the comparison:

        | X | Y |
        | - | - |
        | 1 | 2 |

        That's the summary.
        """
        let segments = ResultSegment.parse(input)

        #expect(segments.count == 3)
        guard case let .text(before) = segments[0],
              case .table = segments[1],
              case let .text(after) = segments[2]
        else {
            Issue.record("expected text / table / text")
            return
        }
        #expect(before.contains("Here is the comparison:"))
        #expect(after.contains("That's the summary."))
    }

    @Test func raggedRowsArePaddedToHeaderWidth() {
        let input = """
        | A | B | C |
        | - | - | - |
        | only-one |
        """
        let segments = ResultSegment.parse(input)

        guard case let .table(table) = segments[0] else {
            Issue.record("expected a table segment")
            return
        }
        #expect(table.rows == [["only-one", "", ""]])
    }

    @Test func headerWithoutDelimiterStaysPlainText() {
        // Mid-stream: the delimiter row hasn't arrived yet, so nothing renders
        // as a table.
        let input = "| Feature | A | B |\n| "
        let segments = ResultSegment.parse(input)

        #expect(segments.count == 1)
        #expect(segments[0] == .text(input))
    }
}

struct SpokenTextTests {
    @Test func plainTextIsUnchanged() {
        #expect(ResultSegment.spokenText("Just a sentence.") == "Just a sentence.")
    }

    @Test func stripsInlineEmphasisCodeAndStrikethrough() {
        #expect(ResultSegment.spokenText("**bold** and *italic* and `code` and ~~gone~~")
            == "bold and italic and code and gone")
    }

    @Test func unwrapsLinksAndImagesToTheirLabel() {
        #expect(ResultSegment.spokenText("See [the docs](https://example.com/x) now")
            == "See the docs now")
        #expect(ResultSegment.spokenText("![a diagram](img.png)") == "a diagram")
    }

    @Test func stripsLeadingBlockMarkers() {
        #expect(ResultSegment.spokenText("# Heading") == "Heading")
        #expect(ResultSegment.spokenText("- bullet item") == "bullet item")
        #expect(ResultSegment.spokenText("1. ordered item") == "ordered item")
        #expect(ResultSegment.spokenText("> quoted line") == "quoted line")
    }

    @Test func dropsThematicBreaks() {
        #expect(ResultSegment.spokenText("Above\n\n---\n\nBelow") == "Above\n\n\nBelow")
    }

    @Test func tableBecomesCommaSeparatedCellsWithoutPipesOrDelimiter() {
        let input = """
        | Plan | Price |
        | --- | ---: |
        | Free | $0 |
        | Pro | $10 |
        """
        let spoken = ResultSegment.spokenText(input)

        #expect(!spoken.contains("|"))
        #expect(!spoken.contains("---"))
        #expect(spoken == "Plan, Price. Free, $0. Pro, $10")
    }

    @Test func tableCellMarkersAreAlsoStripped() {
        let input = "| **Plan** | Price |\n| - | - |\n| Free | `$0` |"
        let spoken = ResultSegment.spokenText(input)

        #expect(!spoken.contains("*"))
        #expect(!spoken.contains("`"))
        #expect(spoken == "Plan, Price. Free, $0")
    }
}
