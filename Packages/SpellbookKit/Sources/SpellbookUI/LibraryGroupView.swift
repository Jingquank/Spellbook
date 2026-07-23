import SpellbookCore
import SwiftUI

struct LibraryGroupView: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.interfaceDensity) private var interfaceDensity
    @Environment(\.interactionModality) private var interactionModality
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        VStack(spacing: SpellbookDesign.Sidebar.rowSpacing) {
            HStack(spacing: SpellbookDesign.Space.micro) {
                Button(action: toggleExpanded) {
                    HStack(spacing: SpellbookDesign.Space.medium) {
                        SpellbookIconView(
                            icon: .disclosure,
                            size: .compact,
                            colorRole: .secondary
                        )
                            .frame(width: SpellbookDesign.Space.medium)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))

                        GroupIdentityView(group: group)
                        Text(group.title)
                            .lineLimit(1)
                        Spacer(minLength: SpellbookDesign.Space.xSmall)
                    }
                    .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .sidebarSelectionBackground(isSelected: false)
                .accessibilityLabel("Package group \(group.title)")
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

                if let status = group.actionableStatus {
                    StatusIndicatorView(status: status) {
                        model.activateStatus(in: group)
                    }
                    .sidebarHoverSurface(
                        horizontalPadding: SpellbookDesign.Space.xSmall,
                        verticalPadding: SpellbookDesign.Space.xSmall
                    )
                }
            }

            if isExpanded {
                VStack(spacing: SpellbookDesign.Sidebar.rowSpacing) {
                    ForEach(group.skills) { skill in
                        SelectableSkillRow(skill: skill, isIndented: true)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, SpellbookDesign.Space.small)
    }

    private var rowHeight: Double {
        interfaceDensity.libraryRowHeight
    }

    private func toggleExpanded() {
        if interactionModality == .pointer {
            withAnimation(SpellbookMotion.sidebarDisclosure(reduceMotion: reduceMotion)) {
                isExpanded.toggle()
            }
        } else {
            isExpanded.toggle()
        }
    }
}
