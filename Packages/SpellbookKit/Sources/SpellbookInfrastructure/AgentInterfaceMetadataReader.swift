import Foundation

struct AgentInterfaceMetadata: Sendable {
    let displayName: String?
    let smallIconPath: String?
    let largeIconPath: String?
}

enum AgentInterfaceMetadataReader {
    static func read(from skillRoot: URL) -> AgentInterfaceMetadata? {
        let url = skillRoot.appending(path: "agents/openai.yaml")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let values = parseFlatYAML(text)
        return AgentInterfaceMetadata(
            displayName: values["display_name"],
            smallIconPath: values["icon_small"],
            largeIconPath: values["icon_large"]
        )
    }

    private static func parseFlatYAML(_ text: String) -> [String: String] {
        var values = [String: String]()
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                (value.hasPrefix("'") && value.hasSuffix("'")) {
                value.removeFirst()
                value.removeLast()
            }
            if !value.isEmpty { values[key] = value }
        }
        return values
    }
}
