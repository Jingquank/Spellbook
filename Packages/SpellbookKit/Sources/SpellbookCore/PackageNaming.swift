import Foundation

public enum PackageTitleStrategy: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case automatic
    case repositoryTitle
    case custom

    public var id: String { rawValue }
}

public struct PackageNameEvidence: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let packageID: PackageID
    public let title: String
    public let kind: String
    public let repositoryURL: URL?
    public let revision: String?
    public let confidence: ProvenanceConfidence
    public let observedAt: Date

    public init(
        id: String,
        packageID: PackageID,
        title: String,
        kind: String,
        repositoryURL: URL? = nil,
        revision: String? = nil,
        confidence: ProvenanceConfidence,
        observedAt: Date = .now
    ) {
        self.id = id
        self.packageID = packageID
        self.title = title
        self.kind = kind
        self.repositoryURL = repositoryURL
        self.revision = revision
        self.confidence = confidence
        self.observedAt = observedAt
    }
}

public struct PackageTitleOverride: Identifiable, Hashable, Codable, Sendable {
    public var id: String { packageID.rawValue }
    public let packageID: PackageID
    public let strategy: PackageTitleStrategy
    public let customTitle: String?

    public init(packageID: PackageID, strategy: PackageTitleStrategy, customTitle: String? = nil) {
        self.packageID = packageID
        self.strategy = strategy
        self.customTitle = customTitle
    }
}

public struct SourceSearchRootRecord: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let url: URL
    public let isTrusted: Bool

    public init(url: URL, isTrusted: Bool = true) {
        self.url = url.standardizedFileURL
        self.isTrusted = isTrusted
        id = isTrusted ? self.url.path : "spotlight::\(self.url.path)"
    }
}

public struct IdentityClusterDecision: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let normalizedName: String
    public let memberSkillIDs: [SkillID]
    public let evidenceFingerprint: String
    public let isRejected: Bool

    public init(
        normalizedName: String,
        memberSkillIDs: [SkillID],
        evidenceFingerprint: String,
        isRejected: Bool
    ) {
        self.normalizedName = normalizedName
        self.memberSkillIDs = memberSkillIDs.sorted { $0.rawValue < $1.rawValue }
        self.evidenceFingerprint = evidenceFingerprint
        self.isRejected = isRejected
        id = "\(normalizedName)::\(self.memberSkillIDs.map(\.rawValue).joined(separator: ","))"
    }
}
