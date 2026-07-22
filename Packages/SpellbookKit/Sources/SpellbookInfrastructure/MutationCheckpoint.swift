public enum MutationCheckpoint: String, CaseIterable, Sendable {
    case validated
    case backupsCreated
    case journalPrepared
    case beforeTargetMutation
    case afterTargetVerification
    case beforeCommit
}
