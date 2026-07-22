import SpellbookCore
import SwiftUI

struct SkillMetadataView: View {
    let skill: SkillRecord

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
            if let author = skill.author {
                MetadataRowView(label: "Author", value: author)
            }
            if let sourceURL = skill.sourceURL {
                MetadataLinkRowView(label: "Repository", title: sourceURL.host() ?? sourceURL.absoluteString, url: sourceURL)
            } else if let websiteURL = skill.websiteURL {
                MetadataLinkRowView(label: "Website", title: websiteURL.host() ?? websiteURL.absoluteString, url: websiteURL)
            }
            MetadataRowView(label: "Installed for", value: installedAgents)
            MetadataRowView(label: "Installations", value: skill.installations.count.formatted())
        }
        .font(.callout)
    }

    private var installedAgents: String {
        skill.installations
            .map(\.agent.displayName)
            .sorted()
            .joined(separator: ", ")
    }
}

