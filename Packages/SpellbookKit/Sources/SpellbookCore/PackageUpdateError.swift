import Foundation

public enum PackageUpdateError: LocalizedError, Sendable {
    case repositoryChanged
    case localChanges
    case notFastForward
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .repositoryChanged:
            "The repository changed after review. Check for updates again."
        case .localChanges:
            "This package has local Git changes. Review or commit them before updating."
        case .notFastForward:
            "The upstream update is not a safe fast-forward. Spellbook left the repository unchanged."
        case .commandFailed(let message):
            message
        }
    }
}
