import Foundation

public enum LocalState: String, Codable, Hashable, Sendable {
    case unverified
    case clean
    case modified
    case conflict
    case missing
    case accessRequired

    public var label: String {
        switch self {
        case .unverified: "Unverified"
        case .clean: "Clean"
        case .modified: "Modified"
        case .conflict: "Conflict"
        case .missing: "Missing"
        case .accessRequired: "Access required"
        }
    }

    public var permitsMutation: Bool {
        switch self {
        case .missing, .accessRequired: false
        case .unverified, .clean, .modified, .conflict: true
        }
    }
}
