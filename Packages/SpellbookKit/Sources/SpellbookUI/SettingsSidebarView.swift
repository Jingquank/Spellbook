import SwiftUI

struct SettingsSidebarView: View {
    @Binding var selection: SettingsSectionID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(SpellbookDesign.Typography.sectionTitle)
                .bold()
                .padding(.horizontal, SpellbookDesign.Space.large)
                .padding(.top, SpellbookDesign.Sidebar.headerTopInset)
                .padding(.bottom, SpellbookDesign.Sidebar.headerBottomInset)

            ScrollView {
                LazyVStack(spacing: SpellbookDesign.Sidebar.rowSpacing) {
                    ForEach(SettingsSectionID.allCases) { section in
                        SidebarSelectionButton(
                            isSelected: selection == section,
                            action: { selection = section }
                        ) {
                            Label(section.label, systemImage: section.symbolName)
                                .font(SpellbookDesign.Typography.rowLabel)
                        }
                        .accessibilityIdentifier("Settings \(section.label)")
                    }
                }
                .padding(.horizontal, SpellbookDesign.Sidebar.horizontalInset)
                .padding(.vertical, SpellbookDesign.Sidebar.verticalInset)
            }
            .accessibilityIdentifier("Settings sidebar")
        }
        .background(SpellbookDesign.Palette.sidebar)
    }
}
