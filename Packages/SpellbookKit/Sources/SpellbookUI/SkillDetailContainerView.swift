import SwiftUI

struct SkillDetailContainerView: View {
    @Environment(SpellbookModel.self) private var model

    var body: some View {
        if let skill = model.selectedSkill {
            SkillDetailView(skill: skill)
                .id(skill.id)
        } else {
            ContentUnavailableView(
                "Choose a skill",
                systemImage: NativeSystemSymbol.book.name,
                description: Text("Select a skill to read its instructions and inspect its installations.")
            )
        }
    }
}
