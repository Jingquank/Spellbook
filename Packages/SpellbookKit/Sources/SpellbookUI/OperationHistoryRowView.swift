import SpellbookCore
import SwiftUI

struct OperationHistoryRowView: View {
    let operation: ManagedOperationRecord
    let onRestore: (ManagedOperationRecord) -> Void

    var body: some View {
        LabeledContent {
            HStack(spacing: SpellbookDesign.Space.medium) {
                Text(operation.finishedAt, format: .relative(presentation: .named))
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                if !operation.recoveryURLs.isEmpty {
                    SpellbookIconButton(
                        icon: .archive,
                        label: "Reveal recovery copy",
                        size: .small,
                        frame: .compact,
                        action: revealRecoveryCopy
                    )
                }
                if operation.targetURLs.count == 1, operation.recoveryURLs.count == 1 {
                    SpellbookIconButton(
                        icon: .undo,
                        label: "Review restore",
                        size: .small,
                        frame: .compact
                    ) {
                        onRestore(operation)
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: SpellbookDesign.Space.micro) {
                Text("\(operation.kind.label) · \(operation.status.label)")
                if let target = operation.targetURLs.first {
                    Text(target.path(percentEncoded: false))
                        .font(SpellbookDesign.Typography.codeMetadata)
                        .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private func revealRecoveryCopy() {
        guard let recoveryURL = operation.recoveryURLs.first else { return }
        NSWorkspace.shared.activateFileViewerSelecting([recoveryURL])
    }
}
