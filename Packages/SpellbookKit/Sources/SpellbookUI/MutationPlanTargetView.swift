import SpellbookCore
import SwiftUI

struct MutationPlanTargetView: View {
    let target: MutationTargetPlan

    var body: some View {
        DisclosureGroup {
            MutationDiffComparisonView(target: target)
                .padding(.top, 8)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: target.action == .remove ? "trash" : "doc.text")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.destinationURL.lastPathComponent)
                    Text(target.destinationURL.deletingLastPathComponent().path(percentEncoded: false))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Text("+\(target.diff.addedLineCount) −\(target.diff.removedLineCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
