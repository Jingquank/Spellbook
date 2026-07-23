import SpellbookCore
import SwiftUI

struct MutationPlanTargetView: View {
    let target: MutationTargetPlan

    var body: some View {
        DisclosureGroup {
            MutationDiffComparisonView(target: target)
                .padding(.top, SpellbookDesign.Space.medium)
        } label: {
            HStack(spacing: SpellbookDesign.Space.large) {
                SpellbookIconView(
                    icon: target.action == .remove ? .trash : .page,
                    size: .standard,
                    colorRole: .secondary
                )
                    .frame(width: SpellbookDesign.Size.icon)
                VStack(alignment: .leading, spacing: SpellbookDesign.Space.micro) {
                    Text(target.destinationURL.lastPathComponent)
                    Text(target.destinationURL.deletingLastPathComponent().path(percentEncoded: false))
                        .font(SpellbookDesign.Typography.codeMetadata)
                        .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Text("+\(target.diff.addedLineCount) −\(target.diff.removedLineCount)")
                    .font(SpellbookDesign.Typography.codeMetadata)
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
            }
        }
    }
}
