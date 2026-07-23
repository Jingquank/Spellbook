import SpellbookCore
import SwiftUI

struct InstallationRowView: View {
    let installation: SkillInstallation
    let managedOperation: ManagedOperationRecord?
    let sourceState: InstallationSourceState?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: SpellbookDesign.Space.large) {
            AgentIconView(agent: installation.agent)

            VStack(alignment: .leading, spacing: SpellbookDesign.Space.micro) {
                Text(installation.agent.displayName)
                    .font(SpellbookDesign.Typography.rowLabel)
                Text(installation.entryURL.path(percentEncoded: false))
                    .font(SpellbookDesign.Typography.codeMetadata)
                    .foregroundStyle(SpellbookDesign.Palette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                if let revision = sourceState?.installedRevision {
                    Text("Revision \(revision.prefix(10))")
                        .font(SpellbookDesign.Typography.codeMetadata)
                        .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: SpellbookDesign.Space.micro) {
                if isSelected {
                    SpellbookIconView(icon: .check, size: .small, colorRole: .success)
                        .accessibilityHidden(true)
                }
                Text(installation.localState.label)
                    .font(SpellbookDesign.Typography.metadata.weight(installation.localState == .clean ? .regular : .medium))
                if let managedOperation {
                    Text(managedOperation.kind.label)
                        .font(SpellbookDesign.Typography.metadata)
                    Text(managedOperation.finishedAt, format: .relative(presentation: .named))
                        .font(SpellbookDesign.Typography.metadata)
                } else if let observedModifiedAt = installation.observedModifiedAt {
                    Text("Observed change")
                        .font(SpellbookDesign.Typography.metadata)
                    Text(observedModifiedAt, format: .relative(presentation: .named))
                        .font(SpellbookDesign.Typography.metadata)
                }
            }
            .foregroundStyle(SpellbookDesign.Palette.textPrimary)
        }
        .padding(.horizontal, SpellbookDesign.Installation.horizontalInset)
        .padding(.vertical, SpellbookDesign.Space.medium)
        .background(isSelected ? SpellbookDesign.Palette.selection : .clear)
    }
}
