import SpellbookCore
import SwiftUI

struct SkillEditorSheet: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let skill: SkillRecord
    let installation: SkillInstallation

    @State private var draft = ""
    @State private var loadedContent: ManagedFileContent?
    @State private var errorMessage: String?
    @State private var isPlanning = false
    @State private var hasCommitted = false
    @State private var saveCompletionEpoch = 0
    @State private var showsApplySheet = false
    @State private var pendingPlan: ManagedMutationPlan?
    @State private var externalContent: ManagedFileContent?
    @State private var showsExternalConflict = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if loadedContent == nil, errorMessage == nil {
                ProgressView("Opening skill…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MarkdownSourceEditorView(
                    text: $draft,
                    fontSize: model.readerTextScale.editorPointSize
                )
            }

            Divider()
            footer
        }
        .frame(minWidth: 520, idealWidth: 760, minHeight: 480, idealHeight: 600)
        .task(load)
        .alert("Couldn’t save skill", isPresented: showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .sheet(isPresented: $showsApplySheet) {
            ApplyToAgentsSheet(
                skill: skill,
                sourceInstallation: installation,
                content: draft
            )
        }
        .sheet(item: $pendingPlan) { plan in
            MutationPlanReviewSheet(plan: plan, onCommit: didCommit)
        }
        .sheet(isPresented: $showsExternalConflict) {
            if let externalContent {
                ExternalEditConflictSheet(
                    draft: draft,
                    external: externalContent,
                    useExternalVersion: useExternalVersion,
                    keepDraft: keepDraftAfterConflict
                )
            }
        }
        .onChange(of: currentInstallationHash) {
            Task { await reconcileExternalEdit() }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AgentIconView(agent: installation.agent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Edit \(skill.name)")
                    .font(.headline)
                Text(installation.entryURL.path(percentEncoded: false))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        HStack {
            ZStack(alignment: .leading) {
                unsavedFooterLeading
                    .opacity(showsApplyAction ? 0 : 1)
                    .accessibilityHidden(showsApplyAction)
                Button("Apply to other agents…") {
                    showsApplySheet = true
                }
                .opacity(showsApplyAction ? 1 : 0)
                .accessibilityHidden(!showsApplyAction)
            }
            .animation(SpellbookMotion.feedback(reduceMotion: reduceMotion), value: saveCompletionEpoch)

            Spacer()

            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button {
                if !isDirty {
                    dismiss()
                } else if externalContent != nil {
                    showsExternalConflict = true
                } else {
                    Task { await prepareSave() }
                }
            } label: {
                ZStack {
                    Text("Save")
                        .opacity(isDirty ? 1 : 0)
                        .accessibilityHidden(!isDirty)
                    Text("Done")
                        .opacity(isDirty ? 0 : 1)
                        .accessibilityHidden(isDirty)
                }
                .animation(SpellbookMotion.feedback(reduceMotion: reduceMotion), value: saveCompletionEpoch)
            }
            .accessibilityLabel(isDirty ? "Save" : "Done")
            .keyboardShortcut(.defaultAction)
            .disabled(loadedContent == nil || isPlanning)
        }
        .padding(12)
    }

    @ViewBuilder
    private var unsavedFooterLeading: some View {
        if externalContent != nil {
            Button("Review external change…", systemImage: "exclamationmark.triangle") {
                showsExternalConflict = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(.orange)
        } else {
            Text(isDirty ? "Unsaved changes" : "Spellbook checks for outside changes before writing.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var showsError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var isDirty: Bool {
        guard let loadedContent else { return false }
        return draft != loadedContent.text
    }

    private var showsApplyAction: Bool {
        hasCommitted && !isDirty
    }

    private func load() async {
        do {
            let content = try await model.read(installation)
            loadedContent = content
            draft = content.text
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prepareSave() async {
        guard let loadedContent else { return }
        isPlanning = true
        defer { isPlanning = false }

        do {
            pendingPlan = try await model.planSave(
                draft,
                installation: installation,
                expectedHash: loadedContent.contentHash
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func didCommit(_ receipt: ManagedMutationReceipt) {
        guard let loadedContent, let outcome = receipt.outcomes.first else { return }
        self.loadedContent = ManagedFileContent(
            url: installation.entryURL,
            text: draft,
            contentHash: outcome.resultingHash ?? loadedContent.contentHash
        )
        hasCommitted = true
        saveCompletionEpoch &+= 1
        pendingPlan = nil
    }

    private var currentInstallationHash: String? {
        model.snapshot.skill(id: skill.id)?
            .installations.first(where: { $0.id == installation.id })?
            .contentHash
    }

    private func reconcileExternalEdit() async {
        guard
            let loadedContent,
            let currentInstallationHash,
            currentInstallationHash != loadedContent.contentHash
        else { return }
        do {
            let latest = try await model.read(installation)
            if draft == loadedContent.text {
                self.loadedContent = latest
                draft = latest.text
                externalContent = nil
            } else {
                externalContent = latest
                showsExternalConflict = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func useExternalVersion() {
        guard let externalContent else { return }
        loadedContent = externalContent
        draft = externalContent.text
        self.externalContent = nil
    }

    private func keepDraftAfterConflict() {
        guard let externalContent else { return }
        loadedContent = externalContent
        self.externalContent = nil
    }
}
