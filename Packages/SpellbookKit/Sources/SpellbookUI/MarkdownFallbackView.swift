import SwiftUI

struct MarkdownFallbackView: View {
    let label: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpellbookDesign.Space.small) {
            Text(label)
                .font(SpellbookDesign.Typography.metadata)
                .foregroundStyle(SpellbookDesign.Palette.textSecondary)
            Text(text)
                .font(SpellbookDesign.Typography.codeBody)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SpellbookDesign.Space.large)
        .background(SpellbookDesign.Palette.grouped, in: .rect(cornerRadius: SpellbookDesign.Radius.medium))
    }
}
