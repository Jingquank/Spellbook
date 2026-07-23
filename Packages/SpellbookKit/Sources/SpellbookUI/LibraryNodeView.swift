import SpellbookCore
import SwiftUI

struct LibraryNodeView: View {
    let node: LibraryNode

    var body: some View {
        switch node {
        case .skill(let skill):
            SelectableSkillRow(skill: skill)
        case .group(let group):
            LibraryGroupView(group: group)
        }
    }
}

struct SelectableSkillRow: View {
    @Environment(SpellbookModel.self) private var model
    let skill: ProjectedSkill
    var isIndented = false

    var body: some View {
        SkillRowView(skill: skill)
            .padding(.leading, isIndented ? SpellbookDesign.Space.large : SpellbookDesign.Sidebar.horizontalInset)
            .padding(.trailing, SpellbookDesign.Sidebar.horizontalInset)
            .contentShape(.rect)
            .onTapGesture {
                model.select(skill)
            }
            .focusable()
            .sidebarSelectionBackground(isSelected: isSelected)
            .onKeyPress(.return) {
                model.select(skill)
                return .handled
            }
            .accessibilityAction {
                model.select(skill)
            }
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var isSelected: Bool {
        guard let selection = model.selection, selection.skillID == skill.skillID else {
            return false
        }
        guard let installationID = skill.id.installationID else { return true }
        return selection.installationID == installationID
    }
}
