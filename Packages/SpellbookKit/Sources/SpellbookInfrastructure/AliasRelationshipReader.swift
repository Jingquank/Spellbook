import Foundation

enum AliasRelationshipReader {
    static func targetName(in markdown: String) -> String? {
        let pattern = #"(?i)alias\s+of\s+[`]?/([a-z0-9_-]+)"#
        guard
            let expression = try? NSRegularExpression(pattern: pattern),
            let match = expression.firstMatch(
                in: markdown,
                range: NSRange(markdown.startIndex..., in: markdown)
            ),
            let range = Range(match.range(at: 1), in: markdown)
        else { return nil }
        return String(markdown[range]).lowercased()
    }
}
