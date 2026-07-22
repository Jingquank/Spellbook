import SpellbookCore
import SwiftUI

public struct SpellbookRootView: View {
    @Environment(SpellbookModel.self) private var model

    public init() {
        SpellbookDesign.registerFonts()
    }

    public var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            LibrarySidebarView()
                .navigationSplitViewColumnWidth(
                    min: SpellbookDesign.Sidebar.minimumWidth,
                    ideal: SpellbookDesign.Sidebar.idealWidth,
                    max: SpellbookDesign.Sidebar.maximumWidth
                )
        } detail: {
            SkillDetailContainerView()
        }
        .navigationSplitViewStyle(.balanced)
        .font(SpellbookDesign.Typography.body)
        .foregroundStyle(SpellbookDesign.Palette.textPrimary)
        .background(SpellbookDesign.Palette.canvas)
        .interfaceAppearance(textScale: model.textScale, density: model.density)
        .tint(SpellbookDesign.Palette.focus)
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
