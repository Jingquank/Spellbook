import Foundation

enum RepositoryURLNormalizer {
    static func url(from rawValue: String) -> URL? {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let markdownStart = value.range(of: "]("), value.hasSuffix(")") {
            value = String(value[markdownStart.upperBound..<value.index(before: value.endIndex)])
        }

        if value.hasPrefix("git@"), let colon = value.firstIndex(of: ":") {
            let hostStart = value.index(value.startIndex, offsetBy: 4)
            let host = value[hostStart..<colon]
            let path = value[value.index(after: colon)...]
            value = "https://\(host)/\(path)"
        } else if value.hasPrefix("ssh://git@") {
            value = value.replacingOccurrences(of: "ssh://git@", with: "https://")
        }

        guard var components = URLComponents(string: value), components.scheme != nil else { return nil }
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        components.host = components.host?.lowercased()

        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        if path.lowercased().hasSuffix(".git") {
            path.removeLast(4)
        }
        components.path = path

        return components.url
    }

    static func stableString(_ url: URL) -> String {
        let normalized = self.url(from: url.absoluteString) ?? url
        return normalized.absoluteString
    }
}
