import SwiftUI

public struct SpellbookSettingsView: View {
    @Environment(SpellbookModel.self) private var model
    @State private var selection: SettingsSectionID? = .appearance

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SettingsSidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(
                    min: SpellbookMetrics.sidebarMinimumWidth,
                    ideal: SpellbookMetrics.sidebarIdealWidth,
                    max: SpellbookMetrics.sidebarMaximumWidth
                )
        } detail: {
            settingsDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        // SwiftUI's Settings scene otherwise forces an expanded two-row toolbar.
        .background(WindowToolbarStyleConfigurator(toolbarStyle: .unified))
        .tint(Color(nsColor: .secondaryLabelColor))
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
