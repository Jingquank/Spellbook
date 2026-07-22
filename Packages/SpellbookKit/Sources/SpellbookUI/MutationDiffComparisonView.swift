import SpellbookCore
import SwiftUI

struct MutationDiffComparisonView: View {
    let target: MutationTargetPlan

    var body: some View {
        ViewThatFits(in: .horizontal) {
            comparison(axis: .horizontal)
            comparison(axis: .vertical)
        }
        .clipShape(.rect(cornerRadius: SpellbookDesign.Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: SpellbookDesign.Radius.medium)
                .stroke(SpellbookDesign.Palette.separator, lineWidth: SpellbookDesign.Stroke.hairline)
        }
    }

    @ViewBuilder
    private func comparison(axis: Axis) -> some View {
        let current = contentColumn(
            title: target.originalText == nil ? "Current · New file" : "Current · −\(target.diff.removedLineCount)",
            text: target.originalText ?? "No file exists at this location.",
            tint: SpellbookDesign.Palette.diffRemoved
        )
        let proposed = contentColumn(
            title: target.action == .remove ? "Result · Removed" : "Proposed · +\(target.diff.addedLineCount)",
            text: target.proposedText ?? "This file will move to Spellbook Recovery.",
            tint: target.action == .remove ? Color.clear : SpellbookDesign.Palette.diffAdded
        )

        if axis == .horizontal {
            HStack(alignment: .top, spacing: SpellbookDesign.Stroke.standard) {
                current
                proposed
            }
        } else {
            VStack(alignment: .leading, spacing: SpellbookDesign.Stroke.standard) {
                current
                proposed
            }
        }
    }

    private func contentColumn(title: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(SpellbookDesign.Typography.metadata.weight(.medium))
                .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                .padding(.horizontal, SpellbookDesign.Space.large)
                .padding(.vertical, SpellbookDesign.Space.small)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                Text(text)
                    .font(SpellbookDesign.Typography.codeMetadata)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(SpellbookDesign.Space.large)
            }
            .frame(minHeight: SpellbookDesign.Reader.diffMinimumHeight, idealHeight: SpellbookDesign.Reader.diffIdealHeight, maxHeight: SpellbookDesign.Reader.diffMaximumHeight)
        }
        .frame(maxWidth: .infinity)
        .background(tint)
    }
}
