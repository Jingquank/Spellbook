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
            VStack(alignment: .leading, spacing: SpellbookDesign.Space.small) {
                Text("Apply to other agents")
                    .font(SpellbookDesign.Typography.sheetTitle)
                Text("Choose each independent installation Spellbook may replace or create. Existing files are checked again before writing.")
                    .font(SpellbookDesign.Typography.body)
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
            }
            .padding(SpellbookDesign.Sheet.contentPadding)

            Divider()

            VStack(spacing: 0) {
                ForEach(candidates) { agent in
                    Toggle(isOn: binding(for: agent)) {
                        targetLabel(for: agent)
                    }
                    .toggleStyle(.checkbox)
                    .padding(.horizontal, SpellbookDesign.Sheet.contentPadding)
                    .padding(.vertical, SpellbookDesign.Space.large)

                    if agent != candidates.last {
                        Divider().padding(.leading, SpellbookDesign.Sheet.dividerIndent)
                    }
                }
            }

            Divider()

            HStack {
                Text("\(content.utf8.count.formatted()) bytes")
                    .font(SpellbookDesign.Typography.metadata)
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Review") {
                    Task { await preparePlan() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedAgents.isEmpty || isApplying)
            }
            .padding(SpellbookDesign.Sheet.sectionPadding)
        }
        .frame(minWidth: SpellbookDesign.Sheet.standardWidth, idealWidth: SpellbookDesign.Sheet.xWideWidth, minHeight: SpellbookDesign.Sheet.shortHeight)
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

        return HStack(spacing: SpellbookDesign.Space.large) {
            AgentIconView(agent: agent)
            VStack(alignment: .leading, spacing: SpellbookDesign.Space.micro) {
                HStack(spacing: SpellbookDesign.Space.small) {
                    Text(agent.displayName)
                    Text(existing == nil ? "New" : "Installed")
                        .font(SpellbookDesign.Typography.micro)
                        .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                }
                Text(url?.path(percentEncoded: false) ?? "Resolving location…")
                    .font(SpellbookDesign.Typography.codeMetadata)
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
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
