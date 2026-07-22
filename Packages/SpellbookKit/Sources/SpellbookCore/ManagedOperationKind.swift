import Foundation

public enum ManagedOperationKind: String, Codable, Hashable, Sendable {
    case edit
    case apply
    case remove
    case update
    case restore

    public var label: String {
        switch self {
        case .edit: "Edited"
        case .apply: "Applied"
        case .remove: "Removed"
        case .update: "Updated"
        case .restore: "Restored"
        }
    }
}
