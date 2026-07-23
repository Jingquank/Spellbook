import SpellbookCore
import SwiftUI

struct LibrarySidebarView: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.interfaceDensity) private var interfaceDensity
    @State private var hasShownNonemptyLibrary = false
    @State private var firstRevealStage = 0
    @State private var scrollMetrics = SidebarScrollMetrics()

    var body: some View {
        @Bindable var model = model

        Group {
            if #available(macOS 26.0, *), showsScrollableLibrary {
                nativeScrollableSidebar
            } else {
                standardSidebar
            }
        }
        .background(SpellbookDesign.Palette.sidebar)
        .task(id: model.searchText) {
            await model.updateSearchResults()
        }
        .task(id: firstRevealTaskID) {
            await performFirstRevealIfNeeded()
        }
        .alert("Couldn’t check for updates", isPresented: showsUpdateError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.updateError ?? "Unknown error")
        }
    }

    private var standardSidebar: some View {
        VStack(spacing: 0) {
            LibrarySidebarHeaderView()

            libraryContent

            Divider()
            sidebarFooter
        }
    }

    @available(macOS 26.0, *)
    private var nativeScrollableSidebar: some View {
        ZStack {
            if model.projection.nodes.isEmpty {
                ContentUnavailableView.search
            } else if isAwaitingFirstReveal {
                ProgressView("Loading skills…")
                    .opacity(firstRevealStage == 0 ? 1 : 0)
                    .allowsHitTesting(false)

                nativeLibraryScrollView
                    .opacity(firstRevealStage == 2 ? 1 : 0)
            } else {
                nativeLibraryScrollView
            }
        }
        .safeAreaBar(edge: .top, spacing: 0) {
            LibrarySidebarHeaderView()
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                sidebarFooter
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }

    @ViewBuilder
    private var libraryContent: some View {
        if let scanError = model.scanError, model.snapshot.skills.isEmpty {
            ContentUnavailableView(
                "Couldn’t scan skills",
                systemImage: NativeSystemSymbol.warning.name,
                description: Text(scanError)
            )
        } else if model.snapshot.skills.isEmpty, !model.isScanning {
            ContentUnavailableView {
                Label("No skills found", systemImage: NativeSystemSymbol.bookStack.name)
            } description: {
                Text("Spellbook checks the known Claude, Cursor, and Codex skill folders on this Mac.")
            } actions: {
                Button(
                    "Scan Again",
                    systemImage: NativeSystemSymbol.refresh.name,
                    action: rescan
                )
            }
        } else if model.projection.nodes.isEmpty {
            ContentUnavailableView.search
        } else if isAwaitingFirstReveal {
            ZStack {
                ProgressView("Loading skills…")
                    .opacity(firstRevealStage == 0 ? 1 : 0)
                    .allowsHitTesting(false)

                libraryScrollView
                    .opacity(firstRevealStage == 2 ? 1 : 0)
            }
        } else {
            libraryScrollView
        }
    }

    private var sidebarFooter: some View {
        HStack(spacing: SpellbookDesign.Space.medium) {
            if model.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Scanning skills")
                Text("Scanning \(model.scannedFileCount) files")
                    .foregroundStyle(SpellbookDesign.Palette.textPrimary)
            } else {
                Text("\(model.logicalSkillCount) skills · \(model.installationCount) installations")
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
            }

            Spacer()

            if !model.updateCandidates.isEmpty {
                Button("\(model.updateCandidates.count) updates") {
                    model.reviewAllUpdates()
                }
                .buttonStyle(.plain)
                .foregroundStyle(SpellbookDesign.Palette.textPrimary)
                .sidebarHoverSurface()
            } else if model.isCheckingForUpdates {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Checking for updates")
            }

            SpellbookIconButton(
                icon: .settings,
                label: "Settings",
                size: .small,
                frame: .compact,
                action: showSettings
            )
        }
        .font(SpellbookDesign.Typography.metadata)
        .padding(.horizontal, SpellbookDesign.Space.large)
        .padding(.vertical, SpellbookDesign.Space.xSmall)
        .frame(minHeight: interfaceDensity == .compact ? 34 : 44)
    }

    private func rescan() {
        Task {
            await model.rescan()
        }
    }

    private func showSettings() {
        openSettings()
    }

    @ViewBuilder
    private var libraryScrollView: some View {
        if #available(macOS 26.0, *) {
            nativeLibraryScrollView
        } else {
            legacyLibraryScrollView
        }
    }

    @available(macOS 26.0, *)
    private var nativeLibraryScrollView: some View {
        ScrollView {
            libraryRows
        }
        .accessibilityIdentifier("Library sidebar")
    }

    private var libraryRows: some View {
        VStack(spacing: SpellbookDesign.Sidebar.rowSpacing) {
            ForEach(model.projection.nodes) { node in
                LibraryNodeView(node: node)
                    .id(node.id)
            }
        }
        .padding(.horizontal, SpellbookDesign.Sidebar.horizontalInset)
        .padding(.vertical, SpellbookDesign.Sidebar.verticalInset)
    }

    private var legacyLibraryScrollView: some View {
        GeometryReader { viewport in
            let edgeVisibility = SidebarScrollEdgeVisibility(metrics: scrollMetrics)

            ZStack(alignment: .top) {
                ScrollView {
                    libraryRows
                        .background {
                            GeometryReader { content in
                                Color.clear.preference(
                                    key: SidebarScrollMetricsKey.self,
                                    value: SidebarScrollMetrics(
                                        contentMinY: content.frame(in: .named("LibrarySidebarScroll")).minY,
                                        contentHeight: content.size.height,
                                        viewportHeight: viewport.size.height
                                    )
                                )
                            }
                        }
                }
                .coordinateSpace(name: "LibrarySidebarScroll")
                .accessibilityIdentifier("Library sidebar")

                VStack(spacing: 0) {
                    SidebarScrollEdgeVeil(edge: .top, isVisible: edgeVisibility.showsTop)
                    Spacer()
                    SidebarScrollEdgeVeil(edge: .bottom, isVisible: edgeVisibility.showsBottom)
                }
            }
            .onPreferenceChange(SidebarScrollMetricsKey.self) {
                scrollMetrics = $0
            }
        }
    }

    private var firstRevealEligibility: Bool {
        model.searchText.isEmpty
            && !model.isScanning
            && model.scanError == nil
            && !model.projection.nodes.isEmpty
    }

    private var showsScrollableLibrary: Bool {
        model.scanError == nil
            && !model.snapshot.skills.isEmpty
    }

    private var isAwaitingFirstReveal: Bool {
        !hasShownNonemptyLibrary
            && model.searchText.isEmpty
            && !model.projection.nodes.isEmpty
    }

    private var firstRevealTaskID: String {
        [
            firstRevealEligibility ? "eligible" : "ineligible",
            model.searchText.isEmpty ? "idle-search" : "active-search",
            model.projection.nodes.isEmpty ? "empty" : "populated"
        ].joined(separator: ":")
    }

    @MainActor
    private func performFirstRevealIfNeeded() async {
        guard !hasShownNonemptyLibrary else { return }

        // Search is a high-frequency keyboard action and must never inherit the
        // first-load animation. Seeing results also consumes the one-time reveal.
        if !model.searchText.isEmpty, !model.projection.nodes.isEmpty {
            firstRevealStage = 2
            hasShownNonemptyLibrary = true
            return
        }

        guard firstRevealEligibility else { return }
        firstRevealStage = 0

        withAnimation(SpellbookMotion.firstRevealExit(reduceMotion: reduceMotion)) {
            firstRevealStage = 1
        }

        do {
            try await Task.sleep(for: .seconds(
                reduceMotion
                    ? SpellbookMotion.reducedFirstRevealExitDuration
                    : SpellbookMotion.firstRevealExitDuration
            ))
        } catch {
            return
        }
        guard firstRevealEligibility else { return }

        withAnimation(SpellbookMotion.firstRevealEntrance(reduceMotion: reduceMotion)) {
            firstRevealStage = 2
        }

        do {
            try await Task.sleep(for: .seconds(
                reduceMotion
                    ? SpellbookMotion.reducedFirstRevealEntranceDuration
                    : SpellbookMotion.firstRevealEntranceDuration
            ))
        } catch {
            return
        }
        hasShownNonemptyLibrary = true
    }

    private var showsUpdateError: Binding<Bool> {
        Binding(
            get: { model.updateError != nil },
            set: { if !$0 { model.dismissUpdateError() } }
        )
    }
}
