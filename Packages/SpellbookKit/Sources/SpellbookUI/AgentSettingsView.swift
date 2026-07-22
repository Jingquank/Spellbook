import SpellbookCore
import SwiftUI

struct AgentSettingsView: View {
    @Environment(SpellbookModel.self) private var model

    var body: some View {
        Form {
            Section("Detected agents") {
                ForEach(AgentKind.allCases) { agent in
                    LabeledContent {
                        let roots = model.discoveryRoots.filter { $0.agent == agent }
                        VStack(alignment: .trailing, spacing: SpellbookDesign.Space.micro) {
                            Text("\(roots.count) \(roots.count == 1 ? "folder" : "folders")")
                                .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                            ForEach(roots.prefix(2)) { root in
                                Text(root.url.path(percentEncoded: false))
                                    .font(SpellbookDesign.Typography.codeMetadata)
                                    .foregroundStyle(SpellbookDesign.Palette.textTertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    } label: {
                        Label {
                            Text(agent.displayName)
                        } icon: {
                            AgentIconView(agent: agent)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Agents")
    }
}
