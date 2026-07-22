import SpellbookCore
import SwiftUI

struct ApplyToAgentsSheet: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let skill: SkillRecord
    let sourceInstallation: SkillInstallation
    let content: String

    @State private var selectedAgents = Set<AgentKind>()
    @State private var suggestedURLs = [AgentKind: URL]()
    @State private var isApplying = false
    @State private var errorMessage: String?
    @State private var pendingPlan: ManagedMutationPlan?

    private var candidates: [AgentKind] {
        AgentKind.allCases.filter { $0 != sourceInstallation.agent }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Apply to other agents")
                    .font(.title2.bold())
                Text("Choose each independent installation Spellbook may replace or create. Existing files are checked again before writing.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            Divider()

            VStack(spacing: 0) {
                ForEach(candidates) { agent in
                    Toggle(isOn: binding(for: agent)) {
                        targetLabel(for: agent)
                    }
                    .toggleStyle(.checkbox)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)

                    if agent != candidates.last {
                        Divider().padding(.leading, 54)
                    }
                }
            }

            Divider()

            HStack {
                Text("\(content.utf8.count.formatted()) bytes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Review") {
                    Task { await preparePlan() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedAgents.isEmpty || isApplying)
            }
            .padding(12)
        }
        .frame(minWidth: 460, idealWidth: 560, minHeight: 300)
        .task(loadSuggestedURLs)
        .sheet(item: $pendingPlan) { plan in
            MutationPlanReviewSheet(plan: plan) { _ in
                pendingPlan = nil
                dismiss()
            }
        }
        .alert("Couldn’t apply skill", isPresented: showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func targetLabel(for agent: AgentKind) -> some View {
        let existing = skill.installations.first { $0.agent == agent }
        let url = existing?.entryURL ?? suggestedURLs[agent]

        return HStack(spacing: 10) {
            AgentIconView(agent: agent)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(agent.displayName)
                    Text(existing == nil ? "New" : "Installed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(url?.path(percentEncoded: false) ?? "Resolving location…")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var showsError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func binding(for agent: AgentKind) -> Binding<Bool> {
        Binding(
            get: { selectedAgents.contains(agent) },
            set: { isSelected in
                if isSelected {
                    selectedAgents.insert(agent)
                } else {
                    selectedAgents.remove(agent)
                }
            }
        )
    }

    private func loadSuggestedURLs() async {
        for agent in candidates where skill.installations.allSatisfy({ $0.agent != agent }) {
            suggestedURLs[agent] = await model.suggestedEntryURL(for: agent, skillName: skill.name)
        }
    }

    private func preparePlan() async {
        isApplying = true
        defer { isApplying = false }

        do {
            pendingPlan = try await model.planApply(
                content,
                skill: skill,
                to: selectedAgents
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
