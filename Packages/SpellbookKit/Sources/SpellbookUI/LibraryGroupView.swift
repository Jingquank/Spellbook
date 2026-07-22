import SpellbookCore
import SwiftUI

struct LibraryGroupView: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.interfaceDensity) private var interfaceDensity
    let group: ProjectedGroup
    @AppStorage private var isExpanded: Bool

    init(group: ProjectedGroup) {
        self.group = group
        _isExpanded = AppStorage(
            wrappedValue: true,
            PreferenceKey.packageDisclosurePrefix + group.id
        )
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(group.skills) { skill in
                SelectableSkillRow(skill: skill, isIndented: true)
            }
        } label: {
            HStack(spacing: SpellbookDesign.Space.medium) {
                GroupIdentityView(group: group)
                Text(group.title)
                    .lineLimit(1)
                Spacer(minLength: SpellbookDesign.Space.xSmall)
                if let status = group.actionableStatus {
                    StatusIndicatorView(status: status) {
                        model.activateStatus(in: group)
                    }
                }
            }
            .frame(minHeight: rowHeight)
        }
        .padding(.horizontal, SpellbookDesign.Space.small)
        .tint(SpellbookDesign.Palette.textSecondary)
        .accessibilityLabel("Package group \(group.title)")
    }

    private var rowHeight: Double {
        interfaceDensity.libraryRowHeight
    }
}
