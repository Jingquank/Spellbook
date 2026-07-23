import SpellbookCore
import SwiftUI

struct SkillDetailHeaderView: View {
    @Environment(SpellbookModel.self) private var model

    let skill: SkillRecord
    let thumbnail: SkillThumbnail
    let showsReviewUpdate: Bool
    let onReviewUpdate: () -> Void
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
                    titleAndUpdate

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

                    HStack(spacing: SpellbookDesign.Space.small) {
                        SpellbookIconView(
                            icon: managementState.icon,
                            size: .small,
                            colorRole: managementState.iconColorRole
                        )
                        Text(compactSummary)
                    }
                        .font(SpellbookDesign.Typography.metadata)
                        .foregroundStyle(managementState.tint)
                }

                Spacer(minLength: SpellbookDesign.Space.large)
            }

            HStack(spacing: SpellbookDesign.Space.large) {
                HStack(spacing: SpellbookDesign.Space.medium) {
                    SpellbookIconView(
                        icon: managementState.icon,
                        size: .small,
                        colorRole: managementState.iconColorRole
                    )
                    Text(managementState.guidance)
                }
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

    private var titleAndUpdate: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: SpellbookDesign.Space.medium) {
                title
                    .fixedSize(horizontal: true, vertical: false)
                reviewUpdateButton
            }

            VStack(alignment: .leading, spacing: SpellbookDesign.Space.medium) {
                title
                reviewUpdateButton
            }
        }
    }

    private var title: some View {
        Text(skill.name)
            .font(SpellbookDesign.Typography.detailTitle)
            .lineLimit(1)
    }

    @ViewBuilder
    private var reviewUpdateButton: some View {
        if showsReviewUpdate {
            Button(action: onReviewUpdate) {
                SpellbookIconLabel(
                    title: "Review Update",
                    icon: .downloadCircle,
                    size: .small,
                    colorRole: .interactive
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(SpellbookDesign.Palette.interaction)
            .accessibilityIdentifier("Review Update")
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
