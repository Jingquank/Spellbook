import SpellbookCore
import SwiftUI

struct SkillDetailHeaderView: View {
    let skill: SkillRecord
    let thumbnail: SkillThumbnail

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SkillIconView(
                thumbnail: thumbnail,
                size: SpellbookMetrics.detailThumbnailSize
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(skill.name)
                    .font(.title2)
                    .bold()

                if !skill.summary.isEmpty {
                    Text(skill.summary)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: SpellbookMetrics.standardSpacing)

            if let status = skill.actionableStatus {
                Label(status.label, systemImage: symbolName(for: status))
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: .capsule)
            }
        }
    }

    private func symbolName(for status: ActionableStatus) -> String {
        switch status {
        case .conflict: "exclamationmark.triangle"
        case .actionRequired: "exclamationmark.circle"
        case .modified: "pencil.circle"
        case .updateAvailable: "arrow.down.circle"
        }
    }
}
