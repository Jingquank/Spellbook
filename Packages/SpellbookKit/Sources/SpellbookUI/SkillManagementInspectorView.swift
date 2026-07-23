import SpellbookCore
import SwiftUI

enum SkillManagementState: Equatable {
    case clean
    case provisional
    case conflict
    case actionRequired
    case modified
    case updateAvailable
    case missingSource
    case multipleCandidates

    @MainActor
    static func resolve(skill: SkillRecord, model: SpellbookModel) -> Self {
        if model.selectedSkillIsProvisionalCluster { return .provisional }
        switch skill.actionableStatus {
        case .conflict: return .conflict
        case .actionRequired: return .actionRequired
        case .modified: return .modified
        case .updateAvailable: return .updateAvailable
        case nil: break
        }
        if model.sourceConnection(for: skill) == nil,
           model.provenance(for: skill) == nil {
            return model.candidates(for: skill).count > 1 ? .multipleCandidates : .missingSource
        }
        return .clean
    }

    var label: String {
        switch self {
        case .clean: "Clean"
        case .provisional: "Provisional"
        case .conflict: "Conflict"
        case .actionRequired: "Action required"
        case .modified: "Modified"
        case .updateAvailable: "Update available"
        case .missingSource: "Missing source"
        case .multipleCandidates: "Source candidates"
        }
    }

    var icon: SpellbookIcon {
        switch self {
        case .clean: .checkCircle
        case .provisional: .helpCircle
        case .conflict: .warningTriangle
        case .actionRequired: .warningCircle
        case .modified: .edit
        case .updateAvailable: .downloadCircle
        case .missingSource: .linkSlash
        case .multipleCandidates: .network
        }
    }

    var iconColorRole: SpellbookIconColorRole {
        switch self {
        case .clean: .success
        case .provisional, .missingSource, .multipleCandidates: .warning
        case .modified: .secondary
        case .updateAvailable: .update
        case .conflict, .actionRequired: .error
        }
    }

    var tint: Color {
        switch self {
        case .clean: SpellbookDesign.Palette.success
        case .provisional, .missingSource, .multipleCandidates:
            SpellbookDesign.Palette.warning
        case .modified: SpellbookDesign.Palette.textSecondary
        case .updateAvailable: SpellbookDesign.Palette.update
        case .conflict, .actionRequired: SpellbookDesign.Palette.error
        }
    }

    var guidance: String {
        switch self {
        case .clean: "Installations and source information are available in Manage."
        case .provisional: "Verify the source before applying remote updates."
        case .conflict: "Local and remote changes need resolution."
        case .actionRequired: "One installation needs attention before it can be changed."
        case .modified: "A local installation differs from its recorded baseline."
        case .updateAvailable: "A reviewed source update is available."
        case .missingSource: "Connect or discover a source to enable trusted updates."
        case .multipleCandidates: "Choose the source candidate that matches this skill."
        }
    }

    var actionTitle: String {
        switch self {
        case .conflict: "Resolve"
        case .updateAvailable: "Review"
        case .missingSource, .multipleCandidates, .provisional: "Inspect"
        default: "Manage"
        }
    }

    var prioritizesSource: Bool {
        switch self {
        case .provisional, .updateAvailable, .missingSource, .multipleCandidates: true
        default: false
        }
    }
}

struct SkillManagementInspectorView: View {
    @Environment(SpellbookModel.self) private var model
    let skill: SkillRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpellbookDesign.Space.xxxLarge) {
                Text("Manage")
                    .font(SpellbookDesign.Typography.sectionTitle)

                if state != .clean {
                    stateSection
                }

                if state.prioritizesSource {
                    SkillProvenanceView(skill: skill)
                    InstallationListView(skill: skill)
                } else {
                    InstallationListView(skill: skill)
                    SkillProvenanceView(skill: skill)
                }

                EvidenceInspectorView(evidence: model.evidence(for: skill))
            }
            .padding(SpellbookDesign.Space.xxLarge)
        }
        .background(SpellbookDesign.Palette.sidebar)
        .accessibilityIdentifier("Skill management inspector")
    }

    private var state: SkillManagementState {
        SkillManagementState.resolve(skill: skill, model: model)
    }

    private var stateSection: some View {
        VStack(alignment: .leading, spacing: SpellbookDesign.Space.medium) {
            HStack(spacing: SpellbookDesign.Space.medium) {
                SpellbookIconView(icon: state.icon, size: .standard, colorRole: state.iconColorRole)
                Text(state.label)
            }
                .font(SpellbookDesign.Typography.sectionTitle)
                .foregroundStyle(state.tint)
            Text(state.guidance)
                .font(SpellbookDesign.Typography.metadata)
                .foregroundStyle(SpellbookDesign.Palette.textSecondary)

            if state == .updateAvailable {
                Button("Review Update") { model.reviewUpdate(for: skill) }
            } else if state == .provisional {
                Button("Split Skill") {
                    Task { await model.splitSelectedSkillCluster() }
                }
            }
        }
    }
}
