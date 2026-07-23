import SpellbookCore
import SwiftUI

private enum SkillDetailSheet: Identifiable {
    case removalReview(ManagedMutationPlan)
    case connectSource
    case publishingReview(PublishingPlan)
    case publishingDestination
    case artwork

    var id: String {
        switch self {
        case .removalReview(let plan): "removal::\(plan.id)"
        case .connectSource: "connect-source"
        case .publishingReview(let plan): "publishing-review::\(plan.id)"
        case .publishingDestination: "publishing-destination"
        case .artwork: "artwork"
        }
    }
}

struct SkillDetailView: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.interfaceDensity) private var interfaceDensity
    let skill: SkillRecord

    @State private var presentedSheet: SkillDetailSheet?
    @State private var removalInstallation: SkillInstallation?
    @State private var mutationError: String?
    @AppStorage(PreferenceKey.showsManagementInspector) private var showsManagementInspector = true

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            readerPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsManagementInspector {
                Divider()
                SkillManagementInspectorView(skill: skill)
                    .frame(
                        minWidth: SpellbookDesign.Detail.inspectorMinimumWidth,
                        idealWidth: SpellbookDesign.Detail.inspectorIdealWidth,
                        maxWidth: SpellbookDesign.Detail.inspectorMaximumWidth
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(.container, edges: .top)
                    .zIndex(1)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .scrollContentBackground(.visible)
        .sheet(item: $presentedSheet) { sheet in
            presentedSheetContent(sheet)
        }
        .alert("Remove this installation?", isPresented: showsRemovalConfirmation) {
            Button("Cancel", role: .cancel) {
                removalInstallation = nil
            }
            Button("Review Removal", role: .destructive) {
                guard let installation = removalInstallation else { return }
                Task { await prepareRemoval(installation) }
            }
        } message: {
            if let removalInstallation {
                Text("Spellbook will prepare a recoverable removal for only \(removalInstallation.entryURL.lastPathComponent) for \(removalInstallation.agent.displayName). Adjacent files are left in place.")
            }
        }
        .alert("Couldn’t change skill", isPresented: showsMutationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(mutationError ?? "Unknown error")
        }
    }

    @ViewBuilder
    private var readerPane: some View {
        if #available(macOS 26.0, *) {
            nativeReaderPane
        } else {
            legacyReaderPane
        }
    }

    @available(macOS 26.0, *)
    private var nativeReaderPane: some View {
        ZStack(alignment: .top) {
            readerScrollView
                .safeAreaBar(edge: .top, spacing: 0) {
                    Color.clear
                        .frame(height: SpellbookDesign.Detail.fixedTitleBarHeight)
                }

            SkillDetailTopBarBackdrop()
            topBar
        }
    }

    private var legacyReaderPane: some View {
        readerScrollView
            .contentMargins(
                .top,
                SpellbookDesign.Detail.fixedTitleBarHeight,
                for: .scrollContent
            )
            .overlay(alignment: .top) {
                ZStack(alignment: .top) {
                    SkillDetailTopBarBackdrop()
                    topBar
                }
            }
    }

    private var readerScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: interfaceDensity.sectionSpacing) {
                SkillDetailHeaderView(
                    skill: skill,
                    thumbnail: model.thumbnail(for: skill),
                    showsReviewUpdate: showsReviewUpdate,
                    onReviewUpdate: { model.reviewUpdate(for: skill) },
                    onShowManagement: { showsManagementInspector = true }
                )
                Divider()
                NativeMarkdownReaderView(
                    source: model.selectedInstallation?.markdownSource ?? skill.markdownSource,
                    assetRootURL: model.selectedInstallation?.rootURL,
                    textScale: model.readerTextScale
                )
            }
            .frame(maxWidth: readerMaximumWidth, alignment: .leading)
            .padding(interfaceDensity.detailInset)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("Skill detail")
    }

    private var topBar: some View {
        SkillDetailTopBar(
            skillName: skill.name,
            horizontalInset: interfaceDensity.detailInset,
            showsManagementInspector: showsManagementInspector,
            onToggleManagementInspector: toggleManagementInspector
        ) {
            moreMenu
        }
    }

    private var moreMenu: some View {
        SpellbookIconMenu(
            icon: .more,
            label: "More actions",
            size: SpellbookIconUsage.denseChrome,
            frame: .compact,
            colorRole: .interactive
        ) {
            Button(
                "Reveal in Finder",
                systemImage: NativeSystemSymbol.folder.name,
                action: revealInFinder
            )
            .disabled(model.selectedInstallation == nil)
            sourceActionsMenu
            packageActionsMenu
            publishingActionsMenu
            manageActionsMenu
        }
        .accessibilityIdentifier("More actions")
    }

    private func toggleManagementInspector() {
        showsManagementInspector.toggle()
    }

    private var sourceActionsMenu: some View {
        Menu("Source", systemImage: NativeSystemSymbol.link.name) {
            if let sourceURL = skill.sourceURL ?? skill.websiteURL {
                Link("Open Source", destination: sourceURL)
            }
            Button(model.sourceConnection(for: skill) == nil ? "Connect Source…" : "Change Source…") {
                presentedSheet = .connectSource
            }
            .disabled(model.selectedSkillIsProvisionalCluster)
            if model.sourceConnection(for: skill) != nil {
                Divider()
                Button("Disconnect Source", systemImage: NativeSystemSymbol.disconnect.name, role: .destructive) {
                    Task { await model.disconnectSource(for: skill) }
                }
            }
        }
    }

    private var packageActionsMenu: some View {
        Menu("Package", systemImage: NativeSystemSymbol.packageBox.name) {
            Button("Artwork…", systemImage: NativeSystemSymbol.image.name) { presentedSheet = .artwork }
        }
    }

    private var publishingActionsMenu: some View {
        Menu("Publishing", systemImage: NativeSystemSymbol.publishing.name) {
            Button("Publish Package…") {
                Task { await preparePublishing() }
            }
            .disabled(model.publishingTarget(for: skill) == nil || model.selectedInstallation == nil)
            .disabled(model.selectedSkillIsProvisionalCluster)
            Button("Publishing Destination…") {
                presentedSheet = .publishingDestination
            }
        }
    }

    private var manageActionsMenu: some View {
        Menu("Manage", systemImage: NativeSystemSymbol.tools.name) {
            if model.selectedSkillIsProvisionalCluster {
                Button("Split Skill", systemImage: NativeSystemSymbol.split.name) {
                    Task { await model.splitSelectedSkillCluster() }
                }
            } else if model.canMergeCompatibleCopies(of: skill) {
                Button("Merge Compatible Copies", systemImage: NativeSystemSymbol.combine.name) {
                    Task { await model.mergeCompatibleCopies(of: skill) }
                }
            }
            baselineControl
            Divider()
            removeControl
        }
    }

    @ViewBuilder
    private var removeControl: some View {
        if skill.installations.count > 1 {
            Menu("Remove Installation", systemImage: NativeSystemSymbol.trash.name) {
                ForEach(skill.installations) { installation in
                    Button(installation.agent.displayName, role: .destructive) {
                        removalInstallation = installation
                    }
                    .disabled(!installation.localState.permitsMutation)
                }
            }
        } else {
            Button("Remove Installation", systemImage: NativeSystemSymbol.trash.name, role: .destructive) {
                removalInstallation = skill.installations.first
            }
            .disabled(skill.installations.isEmpty)
            .disabled(skill.installations.first.map { !$0.localState.permitsMutation } ?? true)
        }
    }

    @ViewBuilder
    private var baselineControl: some View {
        if skill.installations.count > 1 {
            Menu("Set Current as Baseline", systemImage: NativeSystemSymbol.badgeCheck.name) {
                ForEach(skill.installations) { installation in
                    Button(installation.agent.displayName) {
                        setBaseline(installation)
                    }
                    .disabled(!installation.localState.permitsMutation)
                }
            }
        } else {
            Button("Set Current as Baseline", systemImage: NativeSystemSymbol.badgeCheck.name) {
                guard let installation = skill.installations.first else { return }
                setBaseline(installation)
            }
            .disabled(skill.installations.isEmpty)
            .disabled(skill.installations.first.map { !$0.localState.permitsMutation } ?? true)
        }
    }

    private var readerMaximumWidth: Double {
        model.readerWidth == .focused
            ? SpellbookDesign.Detail.focusedReaderWidth
            : SpellbookDesign.Detail.wideReaderWidth
    }

    private var showsReviewUpdate: Bool {
        !model.selectedSkillIsProvisionalCluster
            && model.updateCandidates.contains { $0.packageIDs.contains(skill.packageID) }
    }

    private func revealInFinder() {
        guard let entryURL = model.selectedInstallation?.entryURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([entryURL])
    }

    private var showsRemovalConfirmation: Binding<Bool> {
        Binding(
            get: { removalInstallation != nil },
            set: { if !$0 { removalInstallation = nil } }
        )
    }

    private var showsMutationError: Binding<Bool> {
        Binding(
            get: { mutationError != nil },
            set: { if !$0 { mutationError = nil } }
        )
    }

    private func prepareRemoval(_ installation: SkillInstallation) async {
        do {
            presentedSheet = .removalReview(try await model.planRemoval(installation))
        } catch {
            mutationError = error.localizedDescription
        }
    }

    private func setBaseline(_ installation: SkillInstallation) {
        Task {
            await model.setCurrentAsBaseline(installation)
        }
    }

    private func preparePublishing() async {
        do {
            presentedSheet = .publishingReview(try await model.previewPublish(skill: skill))
        } catch {
            mutationError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func presentedSheetContent(_ sheet: SkillDetailSheet) -> some View {
        switch sheet {
        case .removalReview(let plan):
            MutationPlanReviewSheet(plan: plan) { _ in
                presentedSheet = nil
                removalInstallation = nil
            }
        case .connectSource:
            ConnectSourceSheet(
                skill: skill,
                existingConnection: model.sourceConnection(for: skill)
            )
        case .publishingReview(let plan):
            PublishingReviewSheet(plan: plan)
        case .publishingDestination:
            PublishingDestinationSheet(skill: skill)
        case .artwork:
            if let package = model.snapshot.package(id: skill.packageID) {
                ArtworkManagerSheet(package: package)
            } else {
                ContentUnavailableView(
                    "Package unavailable",
                    systemImage: NativeSystemSymbol.packageBox.name
                )
            }
        }
    }
}
