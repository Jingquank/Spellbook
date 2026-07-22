import SpellbookCore
import SwiftUI

struct ExternalEditConflictSheet: View {
    @Environment(\.dismiss) private var dismiss

    let draft: String
    let external: ManagedFileContent
    let useExternalVersion: () -> Void
    let keepDraft: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: SpellbookDesign.Space.xSmall) {
                Text("This skill changed outside Spellbook")
                    .font(SpellbookDesign.Typography.sheetTitle)
                Text("Both versions are preserved. Choose which version should remain in the editor; keeping your draft still requires a separate save review.")
                    .font(SpellbookDesign.Typography.body)
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
            }
            .padding(SpellbookDesign.Sheet.contentPadding)

            Divider()

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: SpellbookDesign.Stroke.standard) {
                    versionColumn(title: "External version", text: external.text)
                    versionColumn(title: "Your draft", text: draft)
                }
                VStack(alignment: .leading, spacing: SpellbookDesign.Space.medium) {
                    versionColumn(title: "External version", text: external.text)
                    versionColumn(title: "Your draft", text: draft)
                }
            }
            .padding(SpellbookDesign.Sheet.contentPadding)

            Divider()

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Use External Version") {
                    useExternalVersion()
                    dismiss()
                }
                Button("Keep My Draft") {
                    keepDraft()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(SpellbookDesign.Sheet.sectionPadding)
        }
        .frame(minWidth: SpellbookDesign.Sheet.wideWidth, idealWidth: SpellbookDesign.Sheet.editorWidth, minHeight: SpellbookDesign.Sheet.reviewHeight, idealHeight: SpellbookDesign.Sheet.xTallHeight)
    }

    private func versionColumn(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(SpellbookDesign.Typography.metadata.weight(.medium))
                .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                .padding(SpellbookDesign.Space.large)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                Text(text)
                    .font(SpellbookDesign.Typography.codeMetadata)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(SpellbookDesign.Space.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: SpellbookDesign.Sheet.editorMinimumHeight)
        .overlay {
            RoundedRectangle(cornerRadius: SpellbookDesign.Radius.medium)
                .stroke(SpellbookDesign.Palette.separator, lineWidth: SpellbookDesign.Stroke.hairline)
        }
    }
}
