import Foundation

/// An immutable, dependency-free representation of a parsed Markdown document.
///
/// `MarkdownDocument` is safe to cache or pass between actors. The swift-markdown
/// syntax tree used to create it remains an implementation detail of this module.
public struct MarkdownDocument: Equatable, Sendable {
    public let blocks: [MarkdownBlock]
    public let plainText: String
    public let normalizedContent: String
    public let headings: [MarkdownHeading]
    public let codeBlocks: [MarkdownCodeBlock]
    public let diagnostics: [MarkdownDiagnostic]

    init(
        blocks: [MarkdownBlock],
        plainText: String,
        normalizedContent: String,
        headings: [MarkdownHeading],
        codeBlocks: [MarkdownCodeBlock],
        diagnostics: [MarkdownDiagnostic]
    ) {
        self.blocks = blocks
        self.plainText = plainText
        self.normalizedContent = normalizedContent
        self.headings = headings
        self.codeBlocks = codeBlocks
        self.diagnostics = diagnostics
    }

    public var isEmpty: Bool {
        blocks.isEmpty
    }
}

/// A reader-level Markdown block. Associated values contain only immutable,
/// `Sendable` Spellbook values and Foundation scalar types.
public indirect enum MarkdownBlock: Equatable, Sendable {
    case paragraph(MarkdownText)
    case heading(MarkdownHeading, content: MarkdownText)
    case code(MarkdownCodeBlock)
    case quote([MarkdownBlock])
    case unorderedList([MarkdownListItem])
    case orderedList(start: Int, items: [MarkdownListItem])
    case thematicBreak
    case table(MarkdownTable)
    case html(String)
    case unsupported(kind: String, text: String)

    /// Text suitable for search indexing and accessibility fallbacks.
    public var plainText: String {
        switch self {
        case .paragraph(let content):
            content.plainText
        case .heading(_, let content):
            content.plainText
        case .code(let codeBlock):
            codeBlock.code
        case .quote(let blocks):
            blocks.map(\.plainText).filter { !$0.isEmpty }.joined(separator: "\n\n")
        case .unorderedList(let items):
            items.map(\.plainText).filter { !$0.isEmpty }.joined(separator: "\n")
        case .orderedList(_, let items):
            items.map(\.plainText).filter { !$0.isEmpty }.joined(separator: "\n")
        case .thematicBreak:
            ""
        case .table(let table):
            table.plainText
        case .html(let html):
            html
        case .unsupported(_, let text):
            text
        }
    }
}

public struct MarkdownText: Equatable, Sendable {
    public let inlines: [MarkdownInline]

    public init(inlines: [MarkdownInline]) {
        self.inlines = inlines
    }

    public var plainText: String {
        inlines.map(\.plainText).joined()
    }
}

/// Inline semantics used by the native reader. Links and images preserve their
/// unresolved source strings so the UI can resolve them under an authorized root.
public indirect enum MarkdownInline: Equatable, Sendable {
    case text(String)
    case softBreak
    case lineBreak
    case code(String)
    case emphasis([MarkdownInline])
    case strong([MarkdownInline])
    case strikethrough([MarkdownInline])
    case link(label: [MarkdownInline], destination: String?, title: String?)
    case image(alt: [MarkdownInline], source: String?, title: String?)
    case html(String)
    case symbolLink(destination: String?)
    case unsupported(kind: String, text: String)

    public var plainText: String {
        switch self {
        case .text(let text), .code(let text), .html(let text):
            text
        case .softBreak:
            " "
        case .lineBreak:
            "\n"
        case .emphasis(let children),
             .strong(let children),
             .strikethrough(let children):
            children.map(\.plainText).joined()
        case .link(let label, _, _), .image(let label, _, _):
            label.map(\.plainText).joined()
        case .symbolLink(let destination):
            destination ?? ""
        case .unsupported(_, let text):
            text
        }
    }
}

public struct MarkdownHeading: Equatable, Hashable, Identifiable, Sendable {
    /// A stable-within-content slug, with a numeric suffix for duplicate headings.
    public let id: String
    public let level: Int
    public let title: String

    public init(id: String, level: Int, title: String) {
        self.id = id
        self.level = level
        self.title = title
    }
}

public struct MarkdownCodeBlock: Equatable, Sendable {
    public let language: String?
    public let code: String

    public init(language: String? = nil, code: String) {
        self.language = language
        self.code = code
    }
}

public struct MarkdownListItem: Equatable, Sendable {
    public let taskState: MarkdownTaskState?
    public let blocks: [MarkdownBlock]

    public init(taskState: MarkdownTaskState? = nil, blocks: [MarkdownBlock]) {
        self.taskState = taskState
        self.blocks = blocks
    }

    public var plainText: String {
        blocks.map(\.plainText).filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

public enum MarkdownTaskState: Equatable, Sendable {
    case checked
    case unchecked
}

public struct MarkdownTable: Equatable, Sendable {
    public let columnAlignments: [MarkdownTableAlignment?]
    public let header: [MarkdownTableCell]
    public let rows: [[MarkdownTableCell]]

    public init(
        columnAlignments: [MarkdownTableAlignment?],
        header: [MarkdownTableCell],
        rows: [[MarkdownTableCell]]
    ) {
        self.columnAlignments = columnAlignments
        self.header = header
        self.rows = rows
    }

    public var plainText: String {
        ([header] + rows)
            .map { $0.map(\.content.plainText).joined(separator: "\t") }
            .joined(separator: "\n")
    }
}

public struct MarkdownTableCell: Equatable, Sendable {
    public let content: MarkdownText
    public let columnSpan: Int
    public let rowSpan: Int

    public init(content: MarkdownText, columnSpan: Int = 1, rowSpan: Int = 1) {
        self.content = content
        self.columnSpan = columnSpan
        self.rowSpan = rowSpan
    }
}

public enum MarkdownTableAlignment: Equatable, Sendable {
    case left
    case center
    case right
}

public struct MarkdownDiagnostic: Equatable, Sendable {
    public let severity: Severity
    public let message: String
    public let line: Int?
    public let column: Int?

    public init(severity: Severity, message: String, line: Int? = nil, column: Int? = nil) {
        self.severity = severity
        self.message = message
        self.line = line
        self.column = column
    }

    public enum Severity: Equatable, Sendable {
        case information
        case warning
    }
}
