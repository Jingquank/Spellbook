import Foundation
import Markdown

/// Stateless parser for Spellbook's canonical Markdown artifacts.
public struct MarkdownParser: Sendable {
    public init() {}

    /// Parses a complete Markdown source string with swift-markdown and projects
    /// its syntax tree into immutable reader values.
    ///
    /// Parsing is deliberately non-throwing: CommonMark recovers malformed input.
    /// Recoveries and reader limitations are reported in `diagnostics` when they
    /// can be identified reliably.
    public func parse(_ source: String, sourceURL: URL? = nil) -> MarkdownDocument {
        let readableSource = Self.strippingFrontmatter(from: source)
        let syntaxTree = Markdown.Document(
            parsing: readableSource,
            source: sourceURL,
            options: [.disableSmartOpts]
        )

        var projection = Projection()
        let blocks = projection.convertBlocks(syntaxTree.children)

        var formatter = MarkupFormatter()
        formatter.visit(syntaxTree)

        let diagnostics = sourceDiagnostics(readableSource) + projection.diagnostics
        return MarkdownDocument(
            blocks: blocks,
            plainText: documentPlainText(blocks),
            normalizedContent: Self.canonicalize(formatter.result),
            headings: projection.headings,
            codeBlocks: projection.codeBlocks,
            diagnostics: diagnostics
        )
    }

    private static func strippingFrontmatter(from source: String) -> String {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return source
        }
        guard let closingIndex = lines.dropFirst().firstIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed == "---" || trimmed == "..."
        }) else {
            return source
        }
        lines.removeFirst(closingIndex + 1)
        if lines.first?.isEmpty == true { lines.removeFirst() }
        return lines.joined(separator: "\n")
    }

    /// Canonicalizes line endings and surrounding blank space after AST
    /// formatting. Semantically significant hard breaks remain represented by
    /// the formatter and are not stripped from individual lines.
    private static func canonicalize(_ source: String) -> String {
        let lineNormalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let trimmed = lineNormalized.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed + "\n"
    }

    private func documentPlainText(_ blocks: [MarkdownBlock]) -> String {
        blocks
            .map(\.plainText)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func sourceDiagnostics(_ source: String) -> [MarkdownDiagnostic] {
        var diagnostics: [MarkdownDiagnostic] = []

        if let nullIndex = source.firstIndex(of: "\0") {
            let location = source.location(of: nullIndex)
            diagnostics.append(
                MarkdownDiagnostic(
                    severity: .warning,
                    message: "The document contains a null character that may not render as expected.",
                    line: location.line,
                    column: location.column
                )
            )
        }

        diagnostics.append(contentsOf: unclosedFenceDiagnostics(source))
        return diagnostics
    }

    /// CommonMark accepts an unclosed fenced block through end-of-file. This is
    /// valid recovery behavior but usually signals an accidental edit, so surface
    /// it as a best-effort warning without rejecting the document.
    private func unclosedFenceDiagnostics(_ source: String) -> [MarkdownDiagnostic] {
        var openFence: (character: Character, length: Int, line: Int)?

        for (offset, rawLine) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = String(rawLine).trimmingSuffix("\r")
            guard let fence = fenceMarker(in: line) else { continue }

            if let currentFence = openFence {
                if fence.character == currentFence.character && fence.length >= currentFence.length && fence.hasOnlyTrailingWhitespace {
                    openFence = nil
                }
            } else {
                openFence = (fence.character, fence.length, offset + 1)
            }
        }

        guard let openFence else { return [] }
        return [
            MarkdownDiagnostic(
                severity: .warning,
                message: "Fenced code block is not closed before the end of the document.",
                line: openFence.line,
                column: 1
            )
        ]
    }

    private func fenceMarker(in line: String) -> (character: Character, length: Int, hasOnlyTrailingWhitespace: Bool)? {
        let indentation = line.prefix { $0 == " " }.count
        guard indentation <= 3 else { return nil }

        let remainder = line.dropFirst(indentation)
        guard let character = remainder.first, character == "`" || character == "~" else { return nil }
        let markerLength = remainder.prefix { $0 == character }.count
        guard markerLength >= 3 else { return nil }

        let trailing = remainder.dropFirst(markerLength)
        return (character, markerLength, trailing.allSatisfy(\.isWhitespace))
    }
}

private struct Projection {
    var headings: [MarkdownHeading] = []
    var codeBlocks: [MarkdownCodeBlock] = []
    var diagnostics: [MarkdownDiagnostic] = []
    private var headingSlugCounts: [String: Int] = [:]

    mutating func convertBlocks(_ markups: MarkupChildren) -> [MarkdownBlock] {
        markups.compactMap { convertBlock($0) }
    }

    mutating func convertBlock(_ markup: any Markup) -> MarkdownBlock? {
        switch markup {
        case let paragraph as Paragraph:
            return .paragraph(convertText(paragraph.children))
        case let heading as Heading:
            let content = convertText(heading.children)
            let descriptor = makeHeading(level: heading.level, title: content.plainText)
            headings.append(descriptor)
            return .heading(descriptor, content: content)
        case let code as CodeBlock:
            let codeBlock = MarkdownCodeBlock(language: code.language, code: code.code)
            codeBlocks.append(codeBlock)
            return .code(codeBlock)
        case let quote as BlockQuote:
            return .quote(convertBlocks(quote.children))
        case let list as UnorderedList:
            return .unorderedList(convertListItems(list.children))
        case let list as OrderedList:
            return .orderedList(start: Int(list.startIndex), items: convertListItems(list.children))
        case is ThematicBreak:
            return .thematicBreak
        case let table as Table:
            return .table(convertTable(table))
        case let html as HTMLBlock:
            appendDiagnostic(
                severity: .information,
                message: "Raw HTML is preserved as text because the native reader does not execute HTML.",
                markup: html
            )
            return .html(html.rawHTML)
        default:
            let kind = String(describing: type(of: markup))
            let text = fallbackText(markup)
            appendDiagnostic(
                severity: .warning,
                message: "Unsupported Markdown block \(kind) was preserved as plain text.",
                markup: markup
            )
            return .unsupported(kind: kind, text: text)
        }
    }

    private mutating func convertListItems(_ children: MarkupChildren) -> [MarkdownListItem] {
        children.compactMap { markup in
            guard let item = markup as? ListItem else {
                appendDiagnostic(
                    severity: .warning,
                    message: "A malformed list child was omitted.",
                    markup: markup
                )
                return nil
            }

            let taskState: MarkdownTaskState?
            switch item.checkbox {
            case .checked:
                taskState = .checked
            case .unchecked:
                taskState = .unchecked
            case nil:
                taskState = nil
            }

            return MarkdownListItem(taskState: taskState, blocks: convertBlocks(item.children))
        }
    }

    private mutating func convertTable(_ table: Table) -> MarkdownTable {
        MarkdownTable(
            columnAlignments: table.columnAlignments.map { alignment in
                switch alignment {
                case .left: .left
                case .center: .center
                case .right: .right
                case nil: nil
                }
            },
            header: table.head.cells.map { convertTableCell($0) },
            rows: table.body.rows.map { row in
                row.cells.map { convertTableCell($0) }
            }
        )
    }

    private mutating func convertTableCell(_ cell: Table.Cell) -> MarkdownTableCell {
        MarkdownTableCell(
            content: convertText(cell.children),
            columnSpan: Int(cell.colspan),
            rowSpan: Int(cell.rowspan)
        )
    }

    private mutating func convertText(_ markups: MarkupChildren) -> MarkdownText {
        MarkdownText(inlines: markups.compactMap { convertInline($0) })
    }

    private mutating func convertInline(_ markup: any Markup) -> MarkdownInline? {
        switch markup {
        case let text as Text:
            return .text(text.string)
        case is SoftBreak:
            return .softBreak
        case is LineBreak:
            return .lineBreak
        case let code as InlineCode:
            return .code(code.code)
        case let emphasis as Emphasis:
            return .emphasis(convertInlines(emphasis.children))
        case let strong as Strong:
            return .strong(convertInlines(strong.children))
        case let strikethrough as Strikethrough:
            return .strikethrough(convertInlines(strikethrough.children))
        case let link as Link:
            if link.destination == nil {
                appendDiagnostic(
                    severity: .warning,
                    message: "A link has no destination.",
                    markup: link
                )
            }
            return .link(
                label: convertInlines(link.children),
                destination: link.destination,
                title: link.title
            )
        case let image as Image:
            if image.source == nil {
                appendDiagnostic(
                    severity: .warning,
                    message: "An image has no source.",
                    markup: image
                )
            }
            return .image(
                alt: convertInlines(image.children),
                source: image.source,
                title: image.title
            )
        case let html as InlineHTML:
            appendDiagnostic(
                severity: .information,
                message: "Inline HTML is preserved as text because the native reader does not execute HTML.",
                markup: html
            )
            return .html(html.rawHTML)
        case let symbol as SymbolLink:
            return .symbolLink(destination: symbol.destination)
        case let custom as CustomInline:
            return .unsupported(kind: "CustomInline", text: custom.text)
        default:
            let kind = String(describing: type(of: markup))
            let text = fallbackText(markup)
            appendDiagnostic(
                severity: .warning,
                message: "Unsupported inline Markdown \(kind) was preserved as plain text.",
                markup: markup
            )
            return .unsupported(kind: kind, text: text)
        }
    }

    private mutating func convertInlines(_ markups: MarkupChildren) -> [MarkdownInline] {
        markups.compactMap { convertInline($0) }
    }

    private mutating func makeHeading(level: Int, title: String) -> MarkdownHeading {
        let base = headingSlug(title)
        let count = (headingSlugCounts[base] ?? 0) + 1
        headingSlugCounts[base] = count
        let id = count == 1 ? base : "\(base)-\(count)"
        return MarkdownHeading(id: id, level: level, title: title)
    }

    private func headingSlug(_ title: String) -> String {
        let folded = title.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let scalars = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar).lowercased()) : "-"
        }
        let components = String(scalars).split(separator: "-", omittingEmptySubsequences: true)
        let slug = components.joined(separator: "-")
        return slug.isEmpty ? "section" : slug
    }

    private func fallbackText(_ markup: any Markup) -> String {
        var formatter = MarkupFormatter()
        formatter.visit(markup)
        return formatter.result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private mutating func appendDiagnostic(
        severity: MarkdownDiagnostic.Severity,
        message: String,
        markup: any Markup
    ) {
        diagnostics.append(
            MarkdownDiagnostic(
                severity: severity,
                message: message,
                line: markup.range?.lowerBound.line,
                column: markup.range?.lowerBound.column
            )
        )
    }
}

private extension String {
    func trimmingSuffix(_ suffix: Character) -> String {
        last == suffix ? String(dropLast()) : self
    }

    func location(of index: String.Index) -> (line: Int, column: Int) {
        let prefix = self[..<index]
        let line = prefix.reduce(1) { count, character in character == "\n" ? count + 1 : count }
        let lastLineStart = prefix.lastIndex(of: "\n").map { self.index(after: $0) } ?? startIndex
        let column = distance(from: lastLineStart, to: index) + 1
        return (line, column)
    }
}
