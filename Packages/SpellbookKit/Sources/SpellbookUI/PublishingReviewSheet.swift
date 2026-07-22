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
            VStack(alignment: .leading, spacing: 5) {
                Text("Publish \(plan.packageName)")
                    .font(.title2.bold())
                Text("\(plan.agent.displayName) → \(plan.target.repositoryURL.host ?? plan.target.repositoryURL.path) · \(plan.target.branch)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            Divider()

            List(plan.changes) { change in
                HStack(spacing: 10) {
                    Image(systemName: change.isArtwork ? "photo" : "doc")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(change.relativePath)
                            .font(.callout.monospaced())
                        Text(change.isNew ? "New file" : "Modified")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 3)
            }
            .listStyle(.inset)

            if hasNewFiles {
                Divider()
                Toggle("Approve \(newFileCount) new \(newFileCount == 1 ? "file" : "files")", isOn: $approvesNewFiles)
                    .padding(14)
            }

            Divider()
            HStack {
                Text("Spellbook will commit and push directly. It will stop if the remote branch moves.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Commit and Push") {
                    Task { await publish() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(plan.changes.isEmpty || isPublishing || (hasNewFiles && !approvesNewFiles))
            }
            .padding(14)
        }
        .frame(minWidth: 620, minHeight: 460)
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
