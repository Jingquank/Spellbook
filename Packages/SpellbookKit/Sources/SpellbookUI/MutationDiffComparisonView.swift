import SpellbookCore
import SwiftUI

struct MutationDiffComparisonView: View {
    let target: MutationTargetPlan

    var body: some View {
        ViewThatFits(in: .horizontal) {
            comparison(axis: .horizontal)
            comparison(axis: .vertical)
        }
        .clipShape(.rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private func comparison(axis: Axis) -> some View {
        let current = contentColumn(
            title: target.originalText == nil ? "Current · New file" : "Current · −\(target.diff.removedLineCount)",
            text: target.originalText ?? "No file exists at this location.",
            tint: Color.red.opacity(0.045)
        )
        let proposed = contentColumn(
            title: target.action == .remove ? "Result · Removed" : "Proposed · +\(target.diff.addedLineCount)",
            text: target.proposedText ?? "This file will move to Spellbook Recovery.",
            tint: target.action == .remove ? Color.clear : Color.green.opacity(0.045)
        )

        if axis == .horizontal {
            HStack(alignment: .top, spacing: 1) {
                current
                proposed
            }
        } else {
            VStack(alignment: .leading, spacing: 1) {
                current
                proposed
            }
        }
    }

    private func contentColumn(title: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                Text(text)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(10)
            }
            .frame(minHeight: 150, idealHeight: 190, maxHeight: 220)
        }
        .frame(maxWidth: .infinity)
        .background(tint)
    }
}
