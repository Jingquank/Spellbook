import Foundation

struct FrontmatterMetadata: Sendable {
    let name: String?
    let summary: String?
    let author: String?
    let websiteURL: URL?
    let sourceURL: URL?
    let packageName: String?
    let stableID: String?
    let artworkPath: String?

    static func parse(_ markdown: String) -> FrontmatterMetadata {
        let values = parseValues(markdown)
        return FrontmatterMetadata(
            name: value(in: values, keys: ["name", "title", "metadata.name"]),
            summary: value(in: values, keys: ["description", "summary", "metadata.description", "metadata.summary"]),
            author: value(in: values, keys: ["author", "authors", "metadata.author"]),
            websiteURL: url(in: values, keys: ["website", "homepage", "url", "metadata.website", "metadata.homepage"]),
            sourceURL: url(in: values, keys: [
                "source", "repository", "repository.url", "repo", "github",
                "metadata.source", "metadata.repository", "metadata.repository.url"
            ]),
            packageName: value(in: values, keys: ["package", "package-name", "package_name", "metadata.package"]),
            stableID: value(in: values, keys: ["id", "slug", "skill-id", "skill_id", "metadata.id"]),
            artworkPath: value(in: values, keys: [
                "icon", "icon-small", "icon_small", "logo",
                "metadata.icon", "metadata.icon-small", "metadata.icon_small", "metadata.logo"
            ])
        )
    }

    private static func parseValues(_ markdown: String) -> [String: String] {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").split(
            separator: "\n",
            omittingEmptySubsequences: false
        ).map(String.init)

        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return [:] }
        guard let end = lines.dropFirst().firstIndex(where: {
            let line = $0.trimmingCharacters(in: .whitespaces)
            return line == "---" || line == "..."
        }) else { return [:] }

        let frontmatter = Array(lines[1..<end])
        var result = [String: String]()
        var parentKey: String?
        var index = 0

        while index < frontmatter.count {
            let line = frontmatter[index]
            let indent = line.prefix { $0 == " " || $0 == "\t" }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            index += 1

            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), let colon = trimmed.firstIndex(of: ":") else {
                continue
            }

            let rawKey = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            guard !rawKey.isEmpty else { continue }
            let key = indent > 0 && parentKey != nil ? "\(parentKey!).\(rawKey)" : rawKey
            var rawValue = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)

            if indent == 0 {
                parentKey = rawValue.isEmpty ? rawKey : nil
            }

            if rawValue == ">" || rawValue == "|" || rawValue == ">-" || rawValue == "|-" {
                let preservesLines = rawValue.hasPrefix("|")
                var continuationLines = [String]()
                while index < frontmatter.count {
                    let continuation = frontmatter[index]
                    let continuationIndent = continuation.prefix { $0 == " " || $0 == "\t" }.count
                    guard continuation.trimmingCharacters(in: .whitespaces).isEmpty || continuationIndent > indent else {
                        break
                    }
                    continuationLines.append(continuation.trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                rawValue = continuationLines.joined(separator: preservesLines ? "\n" : " ")
            }

            let cleaned = cleanScalar(rawValue)
            if !cleaned.isEmpty {
                result[key] = cleaned
            }
        }

        return result
    }

    private static func value(in values: [String: String], keys: [String]) -> String? {
        keys.lazy.compactMap { values[$0] }.first
    }

    private static func url(in values: [String: String], keys: [String]) -> URL? {
        guard let value = value(in: values, keys: keys) else { return nil }
        return RepositoryURLNormalizer.url(from: value)
    }

    private static func cleanScalar(_ value: String) -> String {
        var value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
            (value.hasPrefix("'") && value.hasSuffix("'")) {
            value.removeFirst()
            value.removeLast()
        }
        if value.hasPrefix("[") && value.hasSuffix("]") {
            value.removeFirst()
            value.removeLast()
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
