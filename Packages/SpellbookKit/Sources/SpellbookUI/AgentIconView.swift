import SpellbookCore
import SwiftUI

struct AgentIconView: View {
    let agent: AgentKind

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(foregroundStyle)
            .frame(width: SpellbookMetrics.thumbnailSize, height: SpellbookMetrics.thumbnailSize)
            .background(backgroundStyle, in: .rect(cornerRadius: 4))
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
        case .codex: Color.secondary.opacity(0.14)
        }
    }
}
