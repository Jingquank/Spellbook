import SpellbookCore
import SwiftUI

struct InstallationListView: View {
    @Environment(SpellbookModel.self) private var model
    let skill: SkillRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Installations")
                .font(.headline)

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
                            .padding(.leading, 38)
                    }
                }
            }
            .background(.background.secondary, in: .rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 0.5)
            }
        }
    }
}
