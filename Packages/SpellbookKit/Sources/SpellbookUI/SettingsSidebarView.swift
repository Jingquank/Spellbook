import SwiftUI

struct SettingsSidebarView: View {
    @Binding var selection: SettingsSectionID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.title3)
                .bold()
                .padding(.horizontal, SpellbookMetrics.standardSpacing)
                .padding(.top, SpellbookMetrics.sidebarHeaderTopInset)
                .padding(.bottom, SpellbookMetrics.sidebarHeaderBottomInset)

            ScrollView {
                LazyVStack(spacing: SpellbookMetrics.sidebarRowSpacing) {
                    ForEach(SettingsSectionID.allCases) { section in
                        SidebarSelectionButton(
                            isSelected: selection == section,
                            action: { selection = section }
                        ) {
                            Label(section.label, systemImage: section.symbolName)
                                .font(.callout)
                        }
                        .accessibilityIdentifier("Settings \(section.label)")
                    }
                }
                .padding(.horizontal, SpellbookMetrics.sidebarHorizontalInset)
                .padding(.vertical, SpellbookMetrics.sidebarVerticalInset)
            }
            .accessibilityIdentifier("Settings sidebar")
        }
        .background(.background.secondary)
    }
}
