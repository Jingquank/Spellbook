import Foundation

public enum AgentKind: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case claude
    case cursor
    case codex

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude: "Claude Code"
        case .cursor: "Cursor"
        case .codex: "Codex"
        }
    }
}

