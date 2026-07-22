import Foundation

public enum ActionableStatus: Int, Codable, Comparable, Hashable, Sendable {
    case updateAvailable = 1
    case modified = 2
    case actionRequired = 3
    case conflict = 4

    public static func < (lhs: ActionableStatus, rhs: ActionableStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .conflict: "Conflict needs attention"
        case .actionRequired: "Action required"
        case .modified: "Locally modified"
        case .updateAvailable: "Update available"
        }
    }
}
