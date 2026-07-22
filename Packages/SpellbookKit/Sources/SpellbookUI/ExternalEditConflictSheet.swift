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
            VStack(alignment: .leading, spacing: 5) {
                Text("This skill changed outside Spellbook")
                    .font(.title2.bold())
                Text("Both versions are preserved. Choose which version should remain in the editor; keeping your draft still requires a separate save review.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            Divider()

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 1) {
                    versionColumn(title: "External version", text: external.text)
                    versionColumn(title: "Your draft", text: draft)
                }
                VStack(alignment: .leading, spacing: 8) {
                    versionColumn(title: "External version", text: external.text)
                    versionColumn(title: "Your draft", text: draft)
                }
            }
            .padding(20)

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
            .padding(12)
        }
        .frame(minWidth: 520, idealWidth: 760, minHeight: 440, idealHeight: 520)
    }

    private func versionColumn(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(10)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                Text(text)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 160)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 0.5)
        }
    }
}
