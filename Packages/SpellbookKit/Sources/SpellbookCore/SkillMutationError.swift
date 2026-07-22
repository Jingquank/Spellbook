import Foundation

public enum SkillMutationError: LocalizedError, Sendable {
    case unreadable(URL)
    case invalidText(URL)
    case changedSinceReview(URL)
    case destinationAlreadyExists(URL)
    case verificationFailed(URL)
    case invalidPlan
    case recoveryUnsafe(URL)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let url):
            "Spellbook could not read \(url.lastPathComponent)."
        case .invalidText(let url):
            "\(url.lastPathComponent) is not valid UTF-8 text."
        case .changedSinceReview:
            "This skill changed outside Spellbook. Review the latest version before saving."
        case .destinationAlreadyExists(let url):
            "A file already exists at \(url.path). Spellbook will not overwrite it without review."
        case .verificationFailed:
            "Spellbook could not verify the saved content and restored the previous file when possible."
        case .invalidPlan:
            "This operation plan is incomplete or no longer valid. Review the change again."
        case .recoveryUnsafe(let url):
            "Spellbook did not overwrite \(url.lastPathComponent) because it changed after the interrupted operation."
        }
    }
}
