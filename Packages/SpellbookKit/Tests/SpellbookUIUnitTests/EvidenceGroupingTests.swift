import Foundation
import SpellbookCore
import Testing
@testable import SpellbookUI

@Suite("Evidence grouping")
struct EvidenceGroupingTests {
    @Test("Normalizes URLs, deduplicates observations, and preserves chronology")
    func groupsEvidence() throws {
        let packageID = PackageID(rawValue: "package")
        let installationID = InstallationID(rawValue: "installation")
        let earlier = Date(timeIntervalSince1970: 100)
        let later = Date(timeIntervalSince1970: 200)
        let first = SourceEvidence(
            id: "first",
            packageID: packageID,
            installationID: installationID,
            kind: "manifest",
            sourceURL: URL(string: "https://www.github.com/Owner/Repo/?ref=old"),
            revision: "abc",
            confidence: .likely,
            explanation: "Manifest points to repository.",
            observedAt: earlier
        )
        let duplicate = SourceEvidence(
            id: "duplicate",
            packageID: packageID,
            installationID: installationID,
            kind: "manifest",
            sourceURL: URL(string: "https://github.com/Owner/Repo"),
            revision: "abc",
            confidence: .likely,
            explanation: "Manifest points to repository.",
            observedAt: later
        )
        let verified = SourceEvidence(
            id: "verified",
            packageID: packageID,
            installationID: installationID,
            kind: "content-match",
            sourceURL: URL(string: "https://github.com/Owner/Repo/"),
            contentHash: "def",
            confidence: .verified,
            explanation: "Content hash matches.",
            observedAt: earlier
        )

        let group = try #require(EvidenceGrouper.groups(from: [first, duplicate, verified]).first)
        #expect(group.normalizedSource == "https://github.com/Owner/Repo")
        #expect(group.strongestConfidence == .verified)
        #expect(group.kinds == ["content-match", "manifest"])
        #expect(group.supportingInstallationCount == 1)
        #expect(group.records.count == 2)
        #expect(group.records.first?.id == "duplicate")
    }
}
