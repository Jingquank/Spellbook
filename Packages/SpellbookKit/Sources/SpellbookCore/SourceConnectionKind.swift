public enum SourceConnectionKind: String, Codable, Hashable, Sendable, CaseIterable {
    case gitRepository
    case directFile

    public var label: String {
        switch self {
        case .gitRepository: "Git repository"
        case .directFile: "Direct Markdown file"
        }
    }
}
