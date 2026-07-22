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
                    Button("Reveal Recovery Copy", systemImage: "archivebox", action: revealRecoveryCopy)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .help("Reveal recovery copy")
                }
                if operation.targetURLs.count == 1, operation.recoveryURLs.count == 1 {
                    Button("Restore", systemImage: "arrow.uturn.backward") {
                        onRestore(operation)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .help("Review restore")
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
