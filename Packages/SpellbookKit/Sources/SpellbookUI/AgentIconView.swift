import SpellbookCore
import SwiftUI

struct AgentIconView: View {
    let agent: AgentKind

    var body: some View {
        Image(systemName: symbolName)
            .font(SpellbookDesign.Typography.micro.weight(.semibold))
            .foregroundStyle(foregroundStyle)
            .frame(width: SpellbookDesign.Sidebar.artworkSize, height: SpellbookDesign.Sidebar.artworkSize)
            .background(backgroundStyle, in: .rect(cornerRadius: SpellbookDesign.Radius.xSmall))
            .accessibilityLabel(agent.displayName)
    }

    private var symbolName: String {
        switch agent {
        case .claude: "sparkle"
        case .cursor: "cursorarrow.rays"
        case .codex: "chevron.left.forwardslash.chevron.right"
        }
    }

    private var foregroundStyle: Color {
        switch agent {
        case .claude: Color(red: 0.20, green: 0.09, blue: 0.03)
        case .cursor: .white
        case .codex: .primary
        }
    }

    private var backgroundStyle: Color {
        switch agent {
        case .claude: .orange
        case .cursor: .black
        case .codex: SpellbookDesign.Palette.grouped
        }
    }
}
