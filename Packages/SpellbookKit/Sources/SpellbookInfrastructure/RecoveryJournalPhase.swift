enum RecoveryJournalPhase: String, Codable, Sendable {
    case prepared
    case mutating
    case committed
    case rolledBack
    case recoveryRequired

    var isTerminal: Bool {
        switch self {
        case .committed, .rolledBack, .recoveryRequired: true
        case .prepared, .mutating: false
        }
    }
}
