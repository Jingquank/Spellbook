import SpellbookCore
import SwiftUI

struct PublishingReviewSheet: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let plan: PublishingPlan

    @State private var approvesNewFiles = false
    @State private var isPublishing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: SpellbookDesign.Space.xSmall) {
                Text("Publish \(plan.packageName)")
                    .font(SpellbookDesign.Typography.sheetTitle)
                Text("\(plan.agent.displayName) → \(plan.target.repositoryURL.host ?? plan.target.repositoryURL.path) · \(plan.target.branch)")
                    .font(SpellbookDesign.Typography.body)
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
            }
            .padding(SpellbookDesign.Sheet.contentPadding)
            Divider()

            List(plan.changes) { change in
                HStack(spacing: SpellbookDesign.Space.large) {
                    SpellbookIconView(
                        icon: change.isArtwork ? .image : .page,
                        size: .standard,
                        colorRole: .secondary
                    )
                        .frame(width: SpellbookDesign.Size.sidebarArtwork)
                    VStack(alignment: .leading, spacing: SpellbookDesign.Space.micro) {
                        Text(change.relativePath)
                            .font(SpellbookDesign.Typography.codeBody)
                        Text(change.isNew ? "New file" : "Modified")
                            .font(SpellbookDesign.Typography.metadata)
                            .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, SpellbookDesign.Space.micro)
            }
            .listStyle(.inset)

            if hasNewFiles {
                Divider()
                Toggle("Approve \(newFileCount) new \(newFileCount == 1 ? "file" : "files")", isOn: $approvesNewFiles)
                    .padding(SpellbookDesign.Space.large)
            }

            Divider()
            HStack {
                Text("Spellbook will commit and push directly. It will stop if the remote branch moves.")
                    .font(SpellbookDesign.Typography.metadata)
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Commit and Push") {
                    Task { await publish() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(plan.changes.isEmpty || isPublishing || (hasNewFiles && !approvesNewFiles))
            }
            .padding(SpellbookDesign.Space.large)
        }
        .frame(minWidth: SpellbookDesign.Sheet.reviewWidth, minHeight: SpellbookDesign.Sheet.tallHeight)
        .alert("Couldn’t publish package", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var newFileCount: Int { plan.changes.filter(\.isNew).count }
    private var hasNewFiles: Bool { newFileCount > 0 }

    private func publish() async {
        isPublishing = true
        defer { isPublishing = false }
        do {
            try await model.publish(plan, approveNewFiles: approvesNewFiles)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
