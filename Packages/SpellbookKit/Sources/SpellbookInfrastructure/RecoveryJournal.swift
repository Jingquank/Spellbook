import Foundation
import SpellbookCore

struct RecoveryJournal: Codable, Sendable {
    let operationID: String
    let kind: ManagedOperationKind
    let startedAt: Date
    var phase: RecoveryJournalPhase
    let targets: [RecoveryJournalTarget]
}
