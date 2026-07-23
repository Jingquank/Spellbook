import SpellbookCore
import SwiftUI

public struct SpellbookRootView: View {
    @Environment(SpellbookModel.self) private var model
    @State private var interactionModality = InteractionModalityModel()
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all

    public init() {
        SpellbookDesign.registerFonts()
    }

    public var body: some View {
        @Bindable var model = model

        NavigationSplitView(columnVisibility: $splitViewVisibility) {
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
        .toolbarBackground(.hidden, for: .windowToolbar)
        .font(SpellbookDesign.Typography.body)
        .foregroundStyle(SpellbookDesign.Palette.textPrimary)
        .background(SpellbookDesign.Palette.canvas)
        .interfaceAppearance(textScale: model.textScale, density: model.density)
        .environment(\.interactionModality, interactionModality.current)
        .tint(SpellbookDesign.Palette.focus)
        .preferredColorScheme(preferredColorScheme)
        .task(model.start)
        .onAppear(perform: interactionModality.start)
        .onDisappear(perform: interactionModality.stop)
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
