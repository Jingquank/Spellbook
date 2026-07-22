import Foundation
import XCTest
@testable import SpellbookMarkdown

final class MarkdownParserTests: XCTestCase {
    func testOmitsYAMLFrontmatterFromReaderContent() {
        let source = """
        ---
        name: Quiet Review
        description: Reviews changes
        ---
        # Quiet Review

        Reader content.
        """

        let document = MarkdownParser().parse(source)

        XCTAssertEqual(document.headings.map(\.title), ["Quiet Review"])
        XCTAssertFalse(document.plainText.contains("description:"))
        XCTAssertTrue(document.plainText.contains("Reader content."))
    }

    private let parser = MarkdownParser()

    func testParsesHeadingsAndRichInlineContent() {
        let document = parser.parse(
            """
            # Spellbook

            Read *quietly*, **carefully**, and ~~quickly~~. Use `swift test`, visit [Swift](https://swift.org "Home"), or view ![cover](images/cover.png "Cover").
            """
        )

        XCTAssertEqual(document.headings, [MarkdownHeading(id: "spellbook", level: 1, title: "Spellbook")])
        XCTAssertEqual(document.blocks.count, 2)
        XCTAssertEqual(document.plainText, "Spellbook\n\nRead quietly, carefully, and quickly. Use swift test, visit Swift, or view cover.")

        guard case .paragraph(let paragraph) = document.blocks[1] else {
            return XCTFail("Expected a paragraph")
        }

        XCTAssertTrue(paragraph.inlines.contains { inline in
            if case .emphasis = inline { return true }
            return false
        })
        XCTAssertTrue(paragraph.inlines.contains { inline in
            if case .strong = inline { return true }
            return false
        })
        XCTAssertTrue(paragraph.inlines.contains { inline in
            if case .strikethrough = inline { return true }
            return false
        })
        XCTAssertTrue(paragraph.inlines.contains { inline in
            inline == .link(label: [.text("Swift")], destination: "https://swift.org", title: "Home")
        })
        XCTAssertTrue(paragraph.inlines.contains { inline in
            inline == .image(alt: [.text("cover")], source: "images/cover.png", title: "Cover")
        })
    }

    func testParsesNestedQuotesListsAndTaskStates() {
        let document = parser.parse(
            """
            > A quoted introduction.

            - [x] Installed
            - [ ] Review
              1. First
              2. Second
            """
        )

        guard case .quote(let quoteBlocks) = document.blocks.first else {
            return XCTFail("Expected a block quote")
        }
        XCTAssertEqual(quoteBlocks.count, 1)
        guard case .unorderedList(let items) = document.blocks[1] else {
            return XCTFail("Expected an unordered list")
        }
        XCTAssertEqual(items.map(\.taskState), [.checked, .unchecked])
        XCTAssertEqual(items[0].plainText, "Installed")

        guard case .orderedList(let start, let orderedItems) = items[1].blocks.last else {
            return XCTFail("Expected a nested ordered list")
        }
        XCTAssertEqual(start, 1)
        XCTAssertEqual(orderedItems.map(\.plainText), ["First", "Second"])
    }

    func testPreservesOrderedListStart() {
        let document = parser.parse("7. Seven\n8. Eight")

        guard case .orderedList(let start, let items) = document.blocks.first else {
            return XCTFail("Expected an ordered list")
        }
        XCTAssertEqual(start, 7)
        XCTAssertEqual(items.map(\.plainText), ["Seven", "Eight"])
    }

    func testExtractsCodeBlocksAndThematicBreak() {
        let source = """
        Before

        ---

        ```swift
        let spell = "quiet"
        ```

            indented()
        """
        let document = parser.parse(source)

        XCTAssertTrue(document.blocks.contains(.thematicBreak))
        XCTAssertEqual(
            document.codeBlocks,
            [
                MarkdownCodeBlock(language: "swift", code: "let spell = \"quiet\"\n"),
                MarkdownCodeBlock(code: "indented()\n")
            ]
        )
        XCTAssertTrue(document.plainText.contains("let spell = \"quiet\""))
        XCTAssertTrue(document.normalizedContent.contains("```swift"))
    }

    func testParsesGFMTableAndAlignments() {
        let document = parser.parse(
            """
            | Skill | Agent | State |
            | :--- | :---: | ---: |
            | Audit | Codex | Ready |
            | Polish | Claude | Modified |
            """
        )

        guard case .table(let table) = document.blocks.first else {
            return XCTFail("Expected a table")
        }
        XCTAssertEqual(table.columnAlignments, [.left, .center, .right])
        XCTAssertEqual(table.header.map(\.content.plainText), ["Skill", "Agent", "State"])
        XCTAssertEqual(table.rows.count, 2)
        XCTAssertEqual(table.rows[1].map(\.content.plainText), ["Polish", "Claude", "Modified"])
        XCTAssertEqual(
            table.plainText,
            "Skill\tAgent\tState\nAudit\tCodex\tReady\nPolish\tClaude\tModified"
        )
    }

    func testCreatesUniqueStableHeadingIdentifiers() {
        let document = parser.parse(
            """
            # Héllo, World!
            ## Hello World
            ### !!!
            ### ???
            """
        )

        XCTAssertEqual(document.headings.map(\.id), ["hello-world", "hello-world-2", "section", "section-2"])
        XCTAssertEqual(document.headings.map(\.level), [1, 2, 3, 3])
    }

    func testNormalizationUsesCanonicalASTFormatting() {
        let first = parser.parse("Title\r\n=====\r\n\r\n_word_\r\n\r\n")
        let second = parser.parse("# Title\n\n*word*")

        XCTAssertEqual(first.normalizedContent, second.normalizedContent)
        XCTAssertEqual(first.normalizedContent, "# Title\n\n*word*\n")
    }

    func testNormalizationPreservesHardBreakSemantics() {
        let hardBreak = parser.parse("one  \ntwo")
        let softBreak = parser.parse("one\ntwo")

        XCTAssertNotEqual(hardBreak.normalizedContent, softBreak.normalizedContent)
        XCTAssertEqual(hardBreak.plainText, "one\ntwo")
        XCTAssertEqual(softBreak.plainText, "one two")
    }

    func testBestEffortDiagnosticsForUnclosedFenceHTMLAndMissingImageSource() {
        let unclosed = parser.parse("Intro\n\n```swift\nlet value = 1")
        XCTAssertEqual(unclosed.diagnostics.first?.severity, .warning)
        XCTAssertEqual(unclosed.diagnostics.first?.line, 3)
        XCTAssertTrue(unclosed.diagnostics.first?.message.contains("not closed") == true)

        let html = parser.parse("<aside>Note</aside>")
        XCTAssertTrue(html.diagnostics.contains { $0.severity == .information && $0.message.contains("HTML") })

        let missingImage = parser.parse("![missing]()")
        XCTAssertTrue(missingImage.diagnostics.contains { $0.severity == .warning && $0.message.contains("image") })
    }

    func testClosedFenceDoesNotProduceDiagnostic() {
        let document = parser.parse("```text\ncontent\n````\n")
        XCTAssertFalse(document.diagnostics.contains { $0.message.contains("not closed") })
    }

    func testEmptyDocumentProducesEmptyArtifact() {
        let document = parser.parse(" \n\n")

        XCTAssertTrue(document.isEmpty)
        XCTAssertEqual(document.plainText, "")
        XCTAssertEqual(document.normalizedContent, "")
        XCTAssertEqual(document.headings, [])
        XCTAssertEqual(document.codeBlocks, [])
        XCTAssertEqual(document.diagnostics, [])
    }

    func testPublicArtifactsAreSendable() async {
        let document = parser.parse("# Sendable\n\nSafe")
        assertSendable(document)
        assertSendable(document.blocks[0])
        assertSendable(document.headings[0])

        let results = await withTaskGroup(of: MarkdownDocument.self, returning: [MarkdownDocument].self) { group in
            for index in 0..<8 {
                group.addTask {
                    MarkdownParser().parse("# Skill \(index)")
                }
            }

            var documents: [MarkdownDocument] = []
            for await result in group {
                documents.append(result)
            }
            return documents
        }

        XCTAssertEqual(Set(results.map { $0.headings[0].title }).count, 8)
    }
}

private func assertSendable<T: Sendable>(_ value: T) {
    _ = value
}
