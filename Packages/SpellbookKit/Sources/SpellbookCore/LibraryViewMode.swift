import Foundation

public enum LibraryViewMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case skillFirst
    case agentFirst

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .skillFirst: "Skills"
        case .agentFirst: "Agents"
        }
    }
}

