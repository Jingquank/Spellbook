import Foundation

public struct InstallerPackageComponent: Hashable, Codable, Sendable {
    public let name: String
    public let relativePath: String
    public let installedFiles: [String]

    public init(name: String, relativePath: String, installedFiles: [String]) {
        self.name = name
        self.relativePath = relativePath
        self.installedFiles = installedFiles
    }
}

public struct InstallerPackageReceipt: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let packageSlug: String
    public let displayName: String?
    public let version: String?
    public let agent: AgentKind
    public let receiptURL: URL
    public let skillRootURL: URL
    public let components: [InstallerPackageComponent]
    public let sourceURL: URL?
    public let sourceRevision: String?
    public let observedAt: Date

    public init(
        id: String,
        packageSlug: String,
        displayName: String? = nil,
        version: String? = nil,
        agent: AgentKind,
        receiptURL: URL,
        skillRootURL: URL,
        components: [InstallerPackageComponent],
        sourceURL: URL? = nil,
        sourceRevision: String? = nil,
        observedAt: Date = .now
    ) {
        self.id = id
        self.packageSlug = packageSlug
        self.displayName = displayName
        self.version = version
        self.agent = agent
        self.receiptURL = receiptURL
        self.skillRootURL = skillRootURL
        self.components = components
        self.sourceURL = sourceURL
        self.sourceRevision = sourceRevision
        self.observedAt = observedAt
    }

    public var membershipKey: String {
        let componentNames = components.map(\.name).map(Self.normalized).sorted().joined(separator: ",")
        return "\(Self.normalized(packageSlug))::\(componentNames)"
    }

    private static func normalized(_ value: String) -> String {
        String(value.lowercased().filter { $0.isLetter || $0.isNumber })
    }
}
