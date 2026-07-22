import Foundation
import SpellbookCore

public actor DiscoveryRootRegistry: DiscoveryRootManaging {
    private let knownRoots: [DiscoveryRootRecord]
    private let catalog: (any CatalogStore)?
    private var customRoots = [DiscoveryRootRecord]()
    private var hasLoaded = false

    public init(
        knownRoots: [SkillDiscoveryRoot] = SkillDiscoveryRoot.known,
        catalog: (any CatalogStore)? = nil
    ) {
        self.knownRoots = knownRoots.map {
            DiscoveryRootRecord(agent: $0.agent, url: $0.url, isKnown: true)
        }
        self.catalog = catalog
    }

    public func roots() async throws -> [DiscoveryRootRecord] {
        try await loadIfNeeded()
        return (knownRoots + customRoots).sorted(by: Self.rootOrder)
    }

    public func addRoot(_ root: DiscoveryRootRecord) async throws {
        try await loadIfNeeded()
        let custom = DiscoveryRootRecord(agent: root.agent, url: root.url, isKnown: false)
        guard !knownRoots.contains(where: { $0.id == custom.id }) else { return }
        guard !customRoots.contains(where: { $0.id == custom.id }) else { return }
        customRoots.append(custom)
        customRoots.sort(by: Self.rootOrder)
        try await catalog?.saveCustomRoots(customRoots)
    }

    public func removeRoot(id: String) async throws {
        try await loadIfNeeded()
        customRoots.removeAll { $0.id == id }
        try await catalog?.saveCustomRoots(customRoots)
    }

    public func skillDiscoveryRoots() async throws -> [SkillDiscoveryRoot] {
        try await roots().map { SkillDiscoveryRoot(agent: $0.agent, url: $0.url) }
    }

    private func loadIfNeeded() async throws {
        guard !hasLoaded else { return }
        customRoots = try await catalog?.loadCustomRoots() ?? []
        hasLoaded = true
    }

    private static func rootOrder(_ lhs: DiscoveryRootRecord, _ rhs: DiscoveryRootRecord) -> Bool {
        if lhs.agent != rhs.agent { return lhs.agent.rawValue < rhs.agent.rawValue }
        return lhs.url.path.localizedStandardCompare(rhs.url.path) == .orderedAscending
    }
}
