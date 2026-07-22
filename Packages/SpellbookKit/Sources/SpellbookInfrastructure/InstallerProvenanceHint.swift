import Foundation
import SpellbookCore

struct InstallerProvenanceHint: Sendable {
    let sourceURL: URL?
    let skillPath: String?
    let contentHash: String?
    let installedAt: Date?
    let updatedAt: Date?
    let sourceConfidence: ProvenanceConfidence?
    let packageMembershipKey: String?
    let packageName: String?
    let packageVersion: String?
    let sourceRevision: String?
    let receiptID: String?
    let explanation: String
}
