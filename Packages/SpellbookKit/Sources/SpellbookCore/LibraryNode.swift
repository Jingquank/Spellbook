import Foundation

public enum LibraryNode: Identifiable, Hashable, Sendable {
    case skill(ProjectedSkill)
    case group(ProjectedGroup)

    public var id: String {
        switch self {
        case .skill(let skill): "skill::\(skill.id.id)"
        case .group(let group): "group::\(group.id)"
        }
    }
}

