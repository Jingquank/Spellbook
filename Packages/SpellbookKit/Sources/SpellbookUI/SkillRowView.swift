import SpellbookCore
import SwiftUI

struct SkillRowView: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.interfaceDensity) private var interfaceDensity
    let skill: ProjectedSkill

    var body: some View {
        HStack(spacing: 8) {
            SkillIconView(
                thumbnail: skill.thumbnail,
                size: SpellbookMetrics.thumbnailSize
            )

            Text(skill.name)
                .font(.callout)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let status = skill.actionableStatus {
                StatusIndicatorView(status: status) {
                    model.activateStatus(for: skill)
                }
            }
        }
        .contentShape(.rect)
        .frame(minHeight: rowHeight)
    }

    private var rowHeight: Double {
        interfaceDensity.libraryRowHeight
    }
}
