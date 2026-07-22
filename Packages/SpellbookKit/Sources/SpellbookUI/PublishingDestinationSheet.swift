import SpellbookCore
import SwiftUI

struct PublishingDestinationSheet: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let skill: SkillRecord

    @State private var repository = ""
    @State private var branch = "main"
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SpellbookDesign.Space.xLarge) {
            Text("Publishing destination")
                .font(SpellbookDesign.Typography.sheetTitle)
            Text("Override the personal Spellbook repository for this package. Spellbook only connects to an existing repository.")
                .font(SpellbookDesign.Typography.body)
                .foregroundStyle(SpellbookDesign.Palette.textSecondary)

            Form {
                TextField("Git URL or absolute local path", text: $repository)
                TextField("Branch", text: $branch)
            }
            .formStyle(.grouped)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(SpellbookDesign.Typography.metadata)
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
            }

            HStack {
                if hasOverride {
                    Button("Use Personal Default", role: .destructive) {
                        Task {
                            await model.removePublishingOverride(for: skill)
                            dismiss()
                        }
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save Override") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(repository.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(SpellbookDesign.Sheet.contentPadding)
        .frame(minWidth: SpellbookDesign.Sheet.compactWidth, idealWidth: SpellbookDesign.Sheet.sourceIdealWidth, minHeight: SpellbookDesign.Sheet.compactHeight, idealHeight: SpellbookDesign.Sheet.destinationIdealHeight)
        .task { load() }
    }

    private var override: PublishingTarget? {
        model.publishingTargets.first { $0.packageOverrideIDs.contains(skill.packageID) }
    }

    private var hasOverride: Bool { override != nil }

    private func load() {
        guard let target = override else { return }
        repository = target.repositoryURL.isFileURL ? target.repositoryURL.path : target.repositoryURL.absoluteString
        branch = target.branch
    }

    private func save() {
        let raw = repository.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = raw.hasPrefix("/") ? URL(filePath: raw) : URL(string: raw)
        guard let url else {
            errorMessage = "Enter a valid Git URL or absolute local path."
            return
        }
        Task {
            do {
                try await model.configurePublishingOverride(for: skill, repositoryURL: url, branch: branch)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
