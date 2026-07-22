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
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Copy code", systemImage: "doc.on.doc", action: copyCode)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .help("Copy code")
            }
            .padding(.horizontal, 12)
            .frame(height: 34)

            Divider()

            codeContent
                .padding(12)
        }
        .background(.background.secondary, in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator, lineWidth: 0.5)
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
