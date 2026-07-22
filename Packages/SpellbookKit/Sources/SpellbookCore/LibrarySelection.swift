import Foundation

public struct LibrarySelection: Hashable, Codable, Sendable, Identifiable {
    public let skillID: SkillID
    public let installationID: InstallationID?

    public var id: String {
        if let installationID {
            "\(skillID.rawValue)::\(installationID.rawValue)"
        } else {
            skillID.rawValue
        }
    }

    public init(skillID: SkillID, installationID: InstallationID? = nil) {
        self.skillID = skillID
        self.installationID = installationID
    }
}

