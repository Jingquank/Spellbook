import Foundation
import SpellbookCore

struct RecoveryJournalTarget: Codable, Sendable {
    let id: String
    let destinationURL: URL
    let action: ManagedMutationAction
    let expectedHash: String?
    let proposedHash: String?
    let backupURL: URL?
    let existed: Bool
}
