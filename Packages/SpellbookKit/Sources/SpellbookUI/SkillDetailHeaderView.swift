import SpellbookCore
import SwiftUI

struct SkillDetailHeaderView: View {
    @Environment(SpellbookModel.self) private var model

    let skill: SkillRecord
    let thumbnail: SkillThumbnail
    let onShowManagement: () -> Void

    @State private var showsFullSummary = false

    var body: some View {
        VStack(alignment: .leading, spacing: SpellbookDesign.Space.large) {
            HStack(alignment: .top, spacing: SpellbookDesign.Space.large) {
                SkillIconView(
                    thumbnail: thumbnail,
                    size: SpellbookDesign.Detail.artworkSize
                )

                VStack(alignment: .leading, spacing: SpellbookDesign.Space.small) {
                    Text(skill.name)
                        .font(SpellbookDesign.Typography.detailTitle)

                    if !skill.summary.isEmpty {
                        Text(skill.summary)
                            .font(SpellbookDesign.Typography.body)
                            .foregroundStyle(SpellbookDesign.Palette.textPrimary)
                            .lineLimit(
                                showsFullSummary
                                    ? nil
                                    : SpellbookDesign.Detail.summaryCollapsedLines
                            )
                            .textSelection(.enabled)

                        if skill.summary.count > 180 {
                            Button(showsFullSummary ? "Less" : "More") {
                                showsFullSummary.toggle()
                            }
                            .buttonStyle(.link)
                            .font(SpellbookDesign.Typography.metadata)
                        }
                    }

                    Label(compactSummary, systemImage: managementState.symbol)
                        .font(SpellbookDesign.Typography.metadata)
                        .foregroundStyle(managementState.tint)
                }

                Spacer(minLength: SpellbookDesign.Space.large)
            }

            HStack(spacing: SpellbookDesign.Space.large) {
                Label(managementState.guidance, systemImage: managementState.symbol)
                    .font(SpellbookDesign.Typography.metadata)
                    .foregroundStyle(managementState.tint)
                Spacer(minLength: SpellbookDesign.Space.medium)
                Button(managementState.actionTitle, action: onShowManagement)
            }
            .padding(SpellbookDesign.Space.large)
            .background(
                SpellbookDesign.Palette.grouped,
                in: .rect(cornerRadius: SpellbookDesign.Radius.medium)
            )
        }
    }

    private var managementState: SkillManagementState {
        SkillManagementState.resolve(skill: skill, model: model)
    }

    private var compactSummary: String {
        let count = skill.installations.count
        return "\(count) installation\(count == 1 ? "" : "s") · \(sourceSummary) · \(managementState.label)"
    }

    private var sourceSummary: String {
        let sourceURL = model.provenance(for: skill)?.originURL
            ?? model.provenance(for: skill)?.updateURL
            ?? skill.sourceURL
            ?? skill.websiteURL
        guard let sourceURL else { return "Source unverified" }
        let host = sourceURL.host ?? sourceURL.absoluteString
        let path = sourceURL.path == "/" ? "" : sourceURL.path
        return host + path
    }
}
