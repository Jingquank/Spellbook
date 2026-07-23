import AppKit
import SpellbookCore
import SwiftUI

struct AgentIconView: View {
    @Environment(\.colorScheme) private var colorScheme
    let agent: AgentKind

    var body: some View {
        Group {
            if let image = bundledImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            }
        }
        .frame(width: SpellbookDesign.Size.agentMark, height: SpellbookDesign.Size.agentMark)
        .accessibilityLabel(agent.displayName)
    }

    private var assetName: String {
        switch agent {
        case .claude: "agent-claude-code"
        case .cursor: "agent-cursor"
        case .codex: "agent-codex"
        }
    }

    private var bundledImage: NSImage? {
        if let catalogImage = Bundle.module.image(forResource: assetName) {
            return catalogImage
        }
        let filename = switch agent {
        case .claude: "agent-claude-code.png"
        case .codex: "agent-codex.png"
        case .cursor:
            colorScheme == .dark ? "agent-cursor-dark.png" : "agent-cursor-light.png"
        }
        let url = Bundle.module.resourceURL?
            .appending(path: "Icons.xcassets")
            .appending(path: "\(assetName).imageset")
            .appending(path: filename)
        return url.flatMap(NSImage.init(contentsOf:))
    }
}
