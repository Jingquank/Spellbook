import Foundation

public struct InstallationSourceState: Identifiable, Codable, Hashable, Sendable {
    public let installationID: InstallationID
    public let packageID: PackageID
    public let track: String?
    public let installedRevision: String?
    public let baselineHash: String?
    public let lastCheckedAt: Date?

    public var id: InstallationID { installationID }

    public init(
        installationID: InstallationID,
        packageID: PackageID,
        track: String? = nil,
        installedRevision: String? = nil,
        baselineHash: String? = nil,
        lastCheckedAt: Date? = nil
    ) {
        self.installationID = installationID
        self.packageID = packageID
        self.track = track
        self.installedRevision = installedRevision
        self.baselineHash = baselineHash
        self.lastCheckedAt = lastCheckedAt
    }
}
