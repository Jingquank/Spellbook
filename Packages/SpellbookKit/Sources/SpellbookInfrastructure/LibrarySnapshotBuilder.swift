import Foundation
import SpellbookCore

enum LibrarySnapshotBuilder {
    private struct ContentSource {
        let sourceURL: URL
        let agent: AgentKind
    }
    static func snapshot(from discoveries: [DiscoveredSkill], scannedAt: Date) -> LibrarySnapshot {
        let aliasTargets = Set(discoveries.compactMap(\.aliasTarget))
        let sourceByContent = verifiedSourceByContent(discoveries)
        let skillGroups = Dictionary(grouping: discoveries) { discovery in
            effectiveSkillKey(
                discovery,
                aliasTargets: aliasTargets,
                sourceByContent: sourceByContent
            )
        }

        var skills = [SkillRecord]()
        var packageDiscoveries = [String: [DiscoveredSkill]]()
        var packageSkillIDs = [String: Set<SkillID>]()

        for (logicalSkillKey, discoveries) in skillGroups {
            let packageKey = effectivePackageKey(
                discoveries,
                aliasTargets: aliasTargets,
                sourceByContent: sourceByContent
            )
            let packageID = PackageID(rawValue: "package-\(StableHasher.sha256(packageKey))")
            let skillID = SkillID(rawValue: "skill-\(StableHasher.sha256("\(packageKey)::\(logicalSkillKey)"))")
            skills.append(makeSkill(discoveries, packageID: packageID, skillID: skillID))
            packageDiscoveries[packageKey, default: []].append(contentsOf: discoveries)
            packageSkillIDs[packageKey, default: []].insert(skillID)
        }

        let packages = packageDiscoveries.map { packageKey, discoveries in
            let packageID = PackageID(rawValue: "package-\(StableHasher.sha256(packageKey))")
            let aliasName = aliasPackageName(
                discoveries,
                aliasTargets: aliasTargets
            )
            return makePackage(
                discoveries,
                packageID: packageID,
                skillIDs: Array(packageSkillIDs[packageKey, default: []]),
                preferredName: aliasName
            )
        }

        return LibrarySnapshot(
            packages: packages.sorted(by: packageOrder),
            skills: skills.sorted(by: skillOrder),
            scannedAt: scannedAt
        )
    }

    private static func verifiedSourceByContent(
        _ discoveries: [DiscoveredSkill]
    ) -> [String: [ContentSource]] {
        var sources = [String: [ContentSource]]()
        for discovery in discoveries.sorted(by: discoveryOrder) {
            if let sourceURL = discovery.packageSourceURL, discovery.sourceConfidence == .verified {
                sources[discovery.contentIdentityKey, default: []].append(ContentSource(
                    sourceURL: sourceURL,
                    agent: discovery.installation.agent
                ))
            }
        }
        return sources
    }

    private static func effectiveSkillKey(
        _ discovery: DiscoveredSkill,
        aliasTargets: Set<String>,
        sourceByContent: [String: [ContentSource]]
    ) -> String {
        let name = normalizedName(discovery.name)
        if discovery.aliasTarget != nil || aliasTargets.contains(name) {
            return "alias-skill:\(name)"
        }
        if let membershipKey = discovery.provenanceHint?.packageMembershipKey {
            return "\(membershipKey)::skill::\(name)"
        }
        if let sourceURL = inferredVerifiedSource(for: discovery, sourceByContent: sourceByContent) {
            return "source:\(RepositoryURLNormalizer.stableString(sourceURL))::\(name)"
        }
        if let sourceURL = discovery.packageSourceURL {
            let prefix = discovery.sourceConfidence == .verified ? "source" : "declared-source:\(discovery.installation.agent.rawValue)"
            return "\(prefix):\(RepositoryURLNormalizer.stableString(sourceURL))::\(name)"
        }
        return "local:\(discovery.installation.id.rawValue)"
    }

    private static func effectivePackageKey(
        _ discoveries: [DiscoveredSkill],
        aliasTargets: Set<String>,
        sourceByContent: [String: [ContentSource]]
    ) -> String {
        if let membershipKey = discoveries.compactMap({ $0.provenanceHint?.packageMembershipKey }).sorted().first {
            return membershipKey
        }
        if let aliasTarget = discoveries.compactMap(\.aliasTarget).sorted().first {
            return "alias-package:\(aliasTarget)"
        }
        let normalizedNames = discoveries.map { discovery in
            normalizedName(discovery.name)
        }
        if let target = normalizedNames.first(where: aliasTargets.contains) {
            return "alias-package:\(target)"
        }
        if let verified = discoveries.first(where: { $0.sourceConfidence == .verified }),
           let sourceURL = verified.packageSourceURL
                ?? inferredVerifiedSource(for: verified, sourceByContent: sourceByContent) {
            return "source:\(RepositoryURLNormalizer.stableString(sourceURL))"
        }
        if let declared = discoveries.first(where: { $0.packageSourceURL != nil }),
           let sourceURL = declared.packageSourceURL {
            return "declared-source:\(declared.installation.agent.rawValue):\(RepositoryURLNormalizer.stableString(sourceURL))"
        }
        return discoveries.sorted(by: discoveryOrder).first?.packageID.rawValue ?? UUID().uuidString
    }

    private static func inferredVerifiedSource(
        for discovery: DiscoveredSkill,
        sourceByContent: [String: [ContentSource]]
    ) -> URL? {
        let candidates = sourceByContent[discovery.contentIdentityKey, default: []]
            .filter { $0.agent != discovery.installation.agent }
        let byStableURL = Dictionary(grouping: candidates) {
            RepositoryURLNormalizer.stableString($0.sourceURL)
        }
        guard byStableURL.count == 1 else { return nil }
        return byStableURL.values.first?.first?.sourceURL
    }

    private static func aliasPackageName(
        _ discoveries: [DiscoveredSkill],
        aliasTargets: Set<String>
    ) -> String? {
        let normalizedNames = discoveries.map { discovery in
            normalizedName(discovery.name)
        }
        let target = discoveries.compactMap(\.aliasTarget).sorted().first
            ?? normalizedNames.first(where: aliasTargets.contains)
        return target.map(humanized)
    }

    private static func makeSkill(
        _ discoveries: [DiscoveredSkill],
        packageID: PackageID,
        skillID: SkillID
    ) -> SkillRecord {
        let ordered = discoveries.sorted(by: discoveryOrder)
        let first = ordered[0]
        let installations = ordered.map(\.installation).uniqued(on: \.id)

        return SkillRecord(
            id: skillID,
            packageID: packageID,
            name: firstNonempty(ordered.map(\.name)) ?? first.name,
            summary: firstNonempty(ordered.map(\.summary)) ?? "",
            author: firstNonempty(ordered.map(\.author)),
            websiteURL: ordered.lazy.compactMap(\.websiteURL).first,
            sourceURL: ordered.lazy.compactMap(\.sourceURL).first,
            artwork: preferredArtwork(in: ordered, keyPath: \.skillArtwork),
            markdownSource: installations.first?.markdownSource ?? first.markdownSource,
            installations: installations
        )
    }

    private static func makePackage(
        _ discoveries: [DiscoveredSkill],
        packageID: PackageID,
        skillIDs: [SkillID],
        preferredName: String?
    ) -> SkillPackageRecord {
        let ordered = discoveries.sorted(by: discoveryOrder)
        let first = ordered[0]
        return SkillPackageRecord(
            id: packageID,
            name: preferredName ?? firstNonempty(ordered.map(\.packageName)) ?? first.packageName,
            author: firstNonempty(ordered.map(\.packageAuthor)),
            sourceURL: ordered.lazy.compactMap(\.packageSourceURL).first,
            websiteURL: ordered.lazy.compactMap(\.packageWebsiteURL).first,
            artwork: preferredArtwork(in: ordered, keyPath: \.packageArtwork),
            skillIDs: skillIDs.sorted { $0.rawValue < $1.rawValue }
        )
    }

    private static func discoveryOrder(_ lhs: DiscoveredSkill, _ rhs: DiscoveredSkill) -> Bool {
        if lhs.installation.agent != rhs.installation.agent {
            let lhsRank = AgentKind.allCases.firstIndex(of: lhs.installation.agent) ?? .max
            let rhsRank = AgentKind.allCases.firstIndex(of: rhs.installation.agent) ?? .max
            return lhsRank < rhsRank
        }
        return lhs.installation.entryURL.path < rhs.installation.entryURL.path
    }

    private static func packageOrder(_ lhs: SkillPackageRecord, _ rhs: SkillPackageRecord) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private static func skillOrder(_ lhs: SkillRecord, _ rhs: SkillRecord) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private static func firstNonempty(_ values: [String?]) -> String? {
        values.compactMap { value -> String? in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }.first
    }

    private static func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
    }

    private static func humanized(_ value: String) -> String {
        value.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func preferredArtwork(
        in discoveries: [DiscoveredSkill],
        keyPath: KeyPath<DiscoveredSkill, ArtworkReference?>
    ) -> ArtworkReference? {
        let withArtwork = discoveries.filter { $0[keyPath: keyPath] != nil }
        let verified = withArtwork.filter { $0.sourceConfidence == .verified }
        return (verified.isEmpty ? withArtwork : verified)
            .sorted(by: discoveryOrder)
            .first?[keyPath: keyPath]
    }
}

private extension Array {
    func uniqued<Key: Hashable>(on keyPath: KeyPath<Element, Key>) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}
