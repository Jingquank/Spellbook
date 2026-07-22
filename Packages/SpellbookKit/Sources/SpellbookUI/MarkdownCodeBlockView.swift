import SpellbookMarkdown
import SwiftUI

struct MarkdownCodeBlockView: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.readerTextScale) private var readerTextScale
    let codeBlock: MarkdownCodeBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(codeBlock.language?.isEmpty == false ? codeBlock.language ?? "Code" : "Code")
                    .font(SpellbookDesign.Typography.metadata)
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)

                Spacer()

                Button("Copy code", systemImage: "doc.on.doc", action: copyCode)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .help("Copy code")
            }
            .padding(.horizontal, SpellbookDesign.Space.large)
            .frame(height: SpellbookDesign.Reader.codeHeaderHeight)

            Divider()

            codeContent
                .padding(SpellbookDesign.Space.large)
        }
        .background(SpellbookDesign.Palette.grouped, in: .rect(cornerRadius: SpellbookDesign.Radius.large))
        .overlay {
            RoundedRectangle(cornerRadius: SpellbookDesign.Radius.large)
                .stroke(SpellbookDesign.Palette.separator, lineWidth: SpellbookDesign.Stroke.hairline)
        }
    }

    @ViewBuilder
    private var codeContent: some View {
        if model.wrapsCode {
            codeText
        } else {
            ScrollView(.horizontal) {
                codeText
            }
            .scrollIndicators(.automatic)
        }
    }

    private var codeText: some View {
        Text(codeBlock.code)
            .font(readerTextScale.codeFont)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: !model.wrapsCode, vertical: true)
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(codeBlock.code, forType: .string)
    }
}
