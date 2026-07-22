import SpellbookCore
import SwiftUI

struct UpdateReviewSheet: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedIDs = Set<String>()
    @State private var isApplying = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Review updates")
                    .font(.title2.bold())
                Text("Clean updates can be applied together. Blocked packages remain unchanged and connected sources show every affected file.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            Divider()

            List(model.reviewedUpdateCandidates) { update in
                Toggle(isOn: selectionBinding(for: update)) {
                    updateLabel(update)
                }
                .toggleStyle(.checkbox)
                .disabled(!update.canApply)
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
            .frame(minHeight: 260)

            Divider()

            HStack {
                Text("\(selectedIDs.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    Task { await applyUpdates() }
                } label: {
                    ZStack {
                        Text(selectedIDs.count > 1 ? "Update Selected" : "Update")
                            .opacity(isApplying ? 0 : 1)
                            .accessibilityHidden(isApplying)
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Updating…")
                        }
                        .opacity(isApplying ? 1 : 0)
                        .accessibilityHidden(!isApplying)
                    }
                    .animation(SpellbookMotion.feedback(reduceMotion: reduceMotion), value: isApplying)
                }
                .accessibilityLabel(isApplying ? "Updating…" : (selectedIDs.count > 1 ? "Update Selected" : "Update"))
                .keyboardShortcut(.defaultAction)
                .disabled(selectedIDs.isEmpty || isApplying)
            }
            .padding(12)
        }
        .frame(minWidth: 480, idealWidth: 620, minHeight: 360, idealHeight: 440)
        .onAppear {
            selectedIDs = Set(model.reviewedUpdateCandidates.filter(\.canApply).map(\.id))
        }
        .alert("Couldn’t update packages", isPresented: showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func updateLabel(_ update: PackageUpdate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(update.displayName)
                    .font(.headline)
                if let agent = update.targetAgent {
                    Text(agent.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(short(update.currentRevision)) → \(short(update.targetRevision))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            if let blockingReason = update.blockingReason {
                Label(blockingReason, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(update.repositoryURL.path(percentEncoded: false))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if !update.affectedSkillNames.isEmpty {
                Text("\(update.affectedSkillNames.joined(separator: ", ")) · \(update.affectedInstallationCount) \(update.affectedInstallationCount == 1 ? "installation" : "installations")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }


            if !update.offeredSkillNames.isEmpty {
                Text("Available separately: \(update.offeredSkillNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let plan = update.mutationPlan {
                DisclosureGroup("Review file changes") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(plan.targets) { target in
                            MutationPlanTargetView(target: target)
                        }
                    }
                    .padding(.top, 6)
                }
                .font(.caption)
            }
        }
    }

    private var showsError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func selectionBinding(for update: PackageUpdate) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(update.id) },
            set: { selected in
                if selected {
                    selectedIDs.insert(update.id)
                } else {
                    selectedIDs.remove(update.id)
                }
            }
        )
    }

    private func short(_ revision: String) -> String {
        String(revision.prefix(7))
    }

    private func applyUpdates() async {
        isApplying = true
        defer { isApplying = false }

        do {
            try await model.applyUpdates(ids: selectedIDs)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
