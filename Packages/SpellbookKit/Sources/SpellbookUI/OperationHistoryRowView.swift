import SpellbookCore
import SwiftUI

struct OperationHistoryRowView: View {
    let operation: ManagedOperationRecord
    let onRestore: (ManagedOperationRecord) -> Void

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Text(operation.finishedAt, format: .relative(presentation: .named))
                    .foregroundStyle(.secondary)
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
            VStack(alignment: .leading, spacing: 2) {
                Text("\(operation.kind.label) · \(operation.status.label)")
                if let target = operation.targetURLs.first {
                    Text(target.path(percentEncoded: false))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
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
