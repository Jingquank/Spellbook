import Foundation

public enum ManagedOperationStatus: String, Codable, Hashable, Sendable {
    case committed
    case rolledBack
    case failed
    case recovered
    case recoveryRequired

    public var label: String {
        switch self {
        case .committed: "Completed"
        case .rolledBack: "Rolled back"
        case .failed: "Failed"
        case .recovered: "Recovered"
        case .recoveryRequired: "Needs recovery"
        }
    }
}
