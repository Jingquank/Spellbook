import SpellbookCore
import SwiftUI

public struct SpellbookRootView: View {
    @Environment(SpellbookModel.self) private var model

    public init() {}

    public var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            LibrarySidebarView()
                .navigationSplitViewColumnWidth(
                    min: SpellbookMetrics.sidebarMinimumWidth,
                    ideal: SpellbookMetrics.sidebarIdealWidth,
                    max: SpellbookMetrics.sidebarMaximumWidth
                )
        } detail: {
            SkillDetailContainerView()
        }
        .navigationSplitViewStyle(.balanced)
        .interfaceAppearance(textScale: model.textScale, density: model.density)
        .tint(Color(nsColor: .secondaryLabelColor))
        .preferredColorScheme(preferredColorScheme)
        .task(model.start)
        .sheet(isPresented: $model.showsUpdateReview) {
            UpdateReviewSheet()
        }
        .onChange(of: model.preferences) {
            model.savePreferences()
        }
        .onChange(of: model.viewMode) {
            model.savePreferences()
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
