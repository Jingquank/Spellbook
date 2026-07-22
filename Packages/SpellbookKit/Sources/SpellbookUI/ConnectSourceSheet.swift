import SpellbookCore
import SwiftUI

struct ConnectSourceSheet: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let skill: SkillRecord
    let existingConnection: SourceConnection?

    @State private var kind: SourceConnectionKind = .gitRepository
    @State private var source = ""
    @State private var branch = ""
    @State private var subdirectory = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: SpellbookDesign.Space.xSmall) {
                Text(existingConnection == nil ? "Connect source" : "Change source")
                    .font(SpellbookDesign.Typography.sheetTitle)
                Text("Connect the package that contains \(skill.name). Updates remain manual and always show a review first.")
                    .font(SpellbookDesign.Typography.body)
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
            }
            .padding(SpellbookDesign.Sheet.contentPadding)

            Divider()

            Form {
                Picker("Source type", selection: $kind) {
                    ForEach(SourceConnectionKind.allCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                TextField(
                    kind == .gitRepository ? "Repository URL" : "Markdown file URL",
                    text: $source,
                    prompt: Text(kind == .gitRepository
                        ? "https://github.com/owner/repository.git"
                        : "https://example.com/SKILL.md")
                )
                if kind == .gitRepository {
                    TextField("Branch or tag", text: $branch, prompt: Text("Default branch"))
                    TextField("Package subdirectory", text: $subdirectory, prompt: Text("Optional"))
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Text("Current installations become the initial local baseline.")
                    .font(SpellbookDesign.Typography.metadata)
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Connect") {
                    Task { await connect() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
            .padding(SpellbookDesign.Sheet.sectionPadding)
        }
        .frame(minWidth: SpellbookDesign.Sheet.standardWidth, idealWidth: SpellbookDesign.Sheet.xWideWidth, minHeight: SpellbookDesign.Sheet.standardHeight, idealHeight: SpellbookDesign.Sheet.sourceIdealHeight)
        .onAppear(perform: loadExistingConnection)
        .alert("Couldn’t connect source", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func loadExistingConnection() {
        guard let existingConnection else { return }
        kind = existingConnection.kind
        source = existingConnection.sourceURL.absoluteString
        branch = existingConnection.branch ?? ""
        subdirectory = existingConnection.subdirectory ?? ""
    }

    private func connect() async {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceURL = trimmed.hasPrefix("/") ? URL(filePath: trimmed) : URL(string: trimmed)
        guard let sourceURL, sourceURL.scheme != nil else {
            errorMessage = "Enter a complete URL, including https://, file://, or an absolute local path."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await model.connectSource(
                to: skill,
                kind: kind,
                sourceURL: sourceURL,
                branch: branch,
                subdirectory: subdirectory
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
