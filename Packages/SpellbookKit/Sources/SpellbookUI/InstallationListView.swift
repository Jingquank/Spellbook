import SpellbookCore
import SwiftUI

struct InstallationListView: View {
    @Environment(SpellbookModel.self) private var model
    let skill: SkillRecord

    var body: some View {
        VStack(alignment: .leading, spacing: SpellbookDesign.Space.medium) {
            Text("Installations")
                .font(SpellbookDesign.Typography.sectionTitle)

            VStack(spacing: 0) {
                ForEach(skill.installations) { installation in
                    Button {
                        model.selectInstallation(installation, for: skill)
                    } label: {
                        InstallationRowView(
                            installation: installation,
                            managedOperation: model.latestManagedOperation(for: installation),
                            sourceState: model.sourceState(for: installation),
                            isSelected: model.selectedInstallation?.id == installation.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show \(installation.agent.displayName) installation")
                    if installation.id != skill.installations.last?.id {
                        Divider()
                            .padding(.leading, SpellbookDesign.Installation.dividerIndent)
                    }
                }
            }
            .background(SpellbookDesign.Palette.grouped, in: .rect(cornerRadius: SpellbookDesign.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: SpellbookDesign.Radius.large)
                    .stroke(SpellbookDesign.Palette.separator, lineWidth: SpellbookDesign.Stroke.hairline)
            }
        }
    }
}
