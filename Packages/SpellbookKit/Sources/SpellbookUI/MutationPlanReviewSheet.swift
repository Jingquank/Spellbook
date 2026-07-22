import SpellbookCore
import SwiftUI

struct MutationPlanReviewSheet: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let plan: ManagedMutationPlan
    let onCommit: (ManagedMutationReceipt) -> Void

    @State private var isCommitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text(reviewTitle)
                    .font(.title2.bold())
                Text("Spellbook will recheck every file, back up all existing targets, then verify each result.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(plan.targets) { target in
                        MutationPlanTargetView(target: target)
                        if target.id != plan.targets.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Text("\(plan.targets.count) \(plan.targets.count == 1 ? "file" : "files")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    Task { await commit() }
                } label: {
                    ZStack {
                        Text(commitTitle)
                            .opacity(isCommitting ? 0 : 1)
                            .accessibilityHidden(isCommitting)
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(inProgressTitle)
                        }
                        .opacity(isCommitting ? 1 : 0)
                        .accessibilityHidden(!isCommitting)
                    }
                    .animation(SpellbookMotion.feedback(reduceMotion: reduceMotion), value: isCommitting)
                }
                .accessibilityLabel(isCommitting ? inProgressTitle : commitTitle)
                .keyboardShortcut(.defaultAction)
                .disabled(isCommitting)
            }
            .padding(12)
        }
        .frame(minWidth: 520, idealWidth: 780, minHeight: 440, idealHeight: 560)
        .alert("Couldn’t apply change", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var reviewTitle: String {
        switch plan.kind {
        case .edit: "Review edit"
        case .apply: "Review agent installations"
        case .remove: "Review removal"
        case .update: "Review update"
        case .restore: "Review restore"
        }
    }

    private var commitTitle: String {
        switch plan.kind {
        case .edit: "Save"
        case .apply: "Apply"
        case .remove: "Move to Recovery"
        case .update: "Update"
        case .restore: "Restore"
        }
    }

    private var inProgressTitle: String {
        switch plan.kind {
        case .edit: "Saving…"
        case .apply: "Applying…"
        case .remove: "Moving…"
        case .update: "Updating…"
        case .restore: "Restoring…"
        }
    }

    private func commit() async {
        isCommitting = true
        defer { isCommitting = false }
        do {
            let receipt = try await model.execute(plan)
            onCommit(receipt)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
