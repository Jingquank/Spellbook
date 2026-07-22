import SpellbookCore
import SwiftUI

struct InstallationRowView: View {
    let installation: SkillInstallation
    let managedOperation: ManagedOperationRecord?
    let sourceState: InstallationSourceState?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            AgentIconView(agent: installation.agent)

            VStack(alignment: .leading, spacing: 2) {
                Text(installation.agent.displayName)
                    .font(.callout)
                Text(installation.entryURL.path(percentEncoded: false))
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                if let revision = sourceState?.installedRevision {
                    Text("Revision \(revision.prefix(10))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .accessibilityHidden(true)
                }
                Text(installation.localState.label)
                    .font(.caption.weight(installation.localState == .clean ? .regular : .medium))
                if let managedOperation {
                    Text(managedOperation.kind.label)
                        .font(.caption)
                    Text(managedOperation.finishedAt, format: .relative(presentation: .named))
                        .font(.caption)
                } else if let observedModifiedAt = installation.observedModifiedAt {
                    Text("Observed change")
                        .font(.caption)
                    Text(observedModifiedAt, format: .relative(presentation: .named))
                        .font(.caption)
                }
            }
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(.primary.opacity(isSelected ? 0.06 : 0))
    }
}
