import SwiftUI

public struct SpellbookSettingsView: View {
    @Environment(SpellbookModel.self) private var model
    @State private var selection: SettingsSectionID? = .appearance

    public init() {
        SpellbookDesign.registerFonts()
    }

    public var body: some View {
        NavigationSplitView {
            SettingsSidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(
                    min: SpellbookDesign.Sidebar.minimumWidth,
                    ideal: SpellbookDesign.Sidebar.idealWidth,
                    max: SpellbookDesign.Sidebar.maximumWidth
                )
        } detail: {
            settingsDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .font(SpellbookDesign.Typography.body)
        .foregroundStyle(SpellbookDesign.Palette.textPrimary)
        .background(SpellbookDesign.Palette.canvas)
        // SwiftUI's Settings scene otherwise forces an expanded two-row toolbar.
        .background(WindowToolbarStyleConfigurator(toolbarStyle: .unified))
        .tint(SpellbookDesign.Palette.focus)
        .preferredColorScheme(preferredColorScheme)
    }

    @ViewBuilder
    private var settingsDetail: some View {
        switch selection ?? .appearance {
        case .general:
            GeneralSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .agents:
            AgentSettingsView()
        case .sources:
            SourceSettingsView()
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch model.appearanceMode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
