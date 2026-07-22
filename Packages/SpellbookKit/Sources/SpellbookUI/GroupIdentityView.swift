import SpellbookCore
import SwiftUI

struct GroupIdentityView: View {
    let group: ProjectedGroup

    var body: some View {
        switch group.kind {
        case .package:
            if let thumbnail = group.thumbnail {
                SkillIconView(thumbnail: thumbnail, size: SpellbookDesign.Sidebar.artworkSize)
            }
        case .agent:
            AgentIconView(agent: agent)
        }
    }

    private var agent: AgentKind {
        AgentKind.allCases.first { group.title == $0.displayName } ?? .codex
    }
}
