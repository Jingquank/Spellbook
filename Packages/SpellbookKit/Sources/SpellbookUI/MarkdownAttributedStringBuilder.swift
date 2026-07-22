import SpellbookMarkdown
import SwiftUI

enum MarkdownAttributedStringBuilder {
    static func build(_ text: MarkdownText) -> AttributedString {
        text.inlines.reduce(into: AttributedString()) { result, inline in
            result.append(build(inline))
        }
    }

    private static func build(_ inline: MarkdownInline) -> AttributedString {
        switch inline {
        case .text(let text):
            return AttributedString(text)
        case .softBreak:
            return AttributedString(" ")
        case .lineBreak:
            return AttributedString("\n")
        case .code(let code):
            return styled(code, intent: .code)
        case .emphasis(let children):
            return styled(children, intent: .emphasized)
        case .strong(let children):
            return styled(children, intent: .stronglyEmphasized)
        case .strikethrough(let children):
            return styled(children, intent: .strikethrough)
        case .link(let label, let destination, _):
            var result = build(children: label)
            if let destination, let url = URL(string: destination) {
                result.link = url
            }
            return result
        case .image(let alt, _, _):
            let altText = build(children: alt)
            let description = altText.characters.isEmpty
                ? "Image"
                : String(altText.characters)
            return AttributedString("[\(description)]")
        case .html(let html):
            return AttributedString(html)
        case .symbolLink(let destination):
            return AttributedString(destination ?? "Symbol")
        case .unsupported(_, let text):
            return AttributedString(text)
        }
    }

    private static func build(children: [MarkdownInline]) -> AttributedString {
        children.reduce(into: AttributedString()) { result, child in
            result.append(build(child))
        }
    }

    private static func styled(
        _ text: String,
        intent: InlinePresentationIntent
    ) -> AttributedString {
        var result = AttributedString(text)
        result.inlinePresentationIntent = intent
        return result
    }

    private static func styled(
        _ children: [MarkdownInline],
        intent: InlinePresentationIntent
    ) -> AttributedString {
        var result = build(children: children)
        result.inlinePresentationIntent = intent
        return result
    }
}
