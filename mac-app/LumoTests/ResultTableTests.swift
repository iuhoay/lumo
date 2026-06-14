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
