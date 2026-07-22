import SpellbookCore
import SwiftUI

private enum SkillDetailSheet: Identifiable {
    case editor(SkillInstallation)
    case removalReview(ManagedMutationPlan)
    case connectSource
    case publishingReview(PublishingPlan)
    case publishingDestination
    case artwork

    var id: String {
        switch self {
        case .editor(let installation): "editor::\(installation.id.rawValue)"
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
    @State private var showsCustomPackageName = false
    @State private var customPackageName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: interfaceDensity.sectionSpacing) {
                SkillDetailHeaderView(
                    skill: skill,
                    thumbnail: model.thumbnail(for: skill)
                )
                Divider()
                SkillMetadataView(skill: skill)
                InstallationListView(skill: skill)
                SkillProvenanceView(skill: skill)
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
        .scrollContentBackground(.visible)
        .navigationTitle(skill.name)
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
        .alert("Package name", isPresented: $showsCustomPackageName) {
            TextField("Name", text: $customPackageName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                Task {
                    await model.setPackageTitleStrategy(
                        .custom,
                        customTitle: customPackageName,
                        for: skill.packageID
                    )
                }
            }
            .disabled(customPackageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("This name stays local and always wins over repository metadata.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !model.selectedSkillIsProvisionalCluster,
                   model.updateCandidates.contains(where: { $0.packageIDs.contains(skill.packageID) }) {
                    Button("Review Update", systemImage: "arrow.down.circle") {
                        model.reviewUpdate(for: skill)
                    }
                    .labelStyle(.iconOnly)
                    .help("Review update for this skill")
                }
                editControl

                Menu("More", systemImage: "ellipsis") {
                    Button("Reveal in Finder", systemImage: "folder", action: revealInFinder)
                        .disabled(model.selectedInstallation == nil)
                    sourceActionsMenu
                    packageActionsMenu
                    publishingActionsMenu
                    manageActionsMenu
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("More actions")
            }
        }
    }

    private var sourceActionsMenu: some View {
        Menu("Source", systemImage: "link") {
            if let sourceURL = skill.sourceURL ?? skill.websiteURL {
                Link("Open Source", destination: sourceURL)
            }
            Button(model.sourceConnection(for: skill) == nil ? "Connect Source…" : "Change Source…") {
                presentedSheet = .connectSource
            }
            .disabled(model.selectedSkillIsProvisionalCluster)
            if model.sourceConnection(for: skill) != nil {
                Divider()
                Button("Disconnect Source", systemImage: "link.badge.minus", role: .destructive) {
                    Task { await model.disconnectSource(for: skill) }
                }
            }
        }
    }

    private var packageActionsMenu: some View {
        Menu("Package", systemImage: "shippingbox") {
            titleStrategyButton("Automatic", strategy: .automatic)
            titleStrategyButton("Use Repository Title", strategy: .repositoryTitle)
            Button("Use Custom Name…") {
                customPackageName = model.snapshot.package(id: skill.packageID)?.name ?? skill.name
                showsCustomPackageName = true
            }
            Divider()
            Button("Artwork…", systemImage: "photo") { presentedSheet = .artwork }
        }
    }

    private var publishingActionsMenu: some View {
        Menu("Publishing", systemImage: "arrow.up.doc") {
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
        Menu("Manage", systemImage: "wrench.and.screwdriver") {
            if model.selectedSkillIsProvisionalCluster {
                Button("Split Skill", systemImage: "rectangle.split.2x1") {
                    Task { await model.splitSelectedSkillCluster() }
                }
            } else if model.canMergeCompatibleCopies(of: skill) {
                Button("Merge Compatible Copies", systemImage: "rectangle.on.rectangle") {
                    Task { await model.mergeCompatibleCopies(of: skill) }
                }
            }
            baselineControl
            Divider()
            removeControl
        }
    }

    private func titleStrategyButton(
        _ title: String,
        strategy: PackageTitleStrategy
    ) -> some View {
        Button {
            Task { await model.setPackageTitleStrategy(strategy, for: skill.packageID) }
        } label: {
            if packageTitleStrategy == strategy {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private var packageTitleStrategy: PackageTitleStrategy {
        model.packageTitleOverrides.first { $0.packageID == skill.packageID }?.strategy ?? .automatic
    }

    @ViewBuilder
    private var editControl: some View {
        if skill.installations.count > 1 {
            Menu("Edit", systemImage: "square.and.pencil") {
                ForEach(skill.installations) { installation in
                    Button(installation.agent.displayName) {
                        presentedSheet = .editor(installation)
                    }
                    .disabled(!installation.localState.permitsMutation)
                }
            }
            .accessibilityLabel("Edit skill")
        } else {
            Button("Edit", systemImage: "square.and.pencil") {
                guard let installation = skill.installations.first else { return }
                presentedSheet = .editor(installation)
            }
            .disabled(skill.installations.isEmpty)
            .disabled(skill.installations.first.map { !$0.localState.permitsMutation } ?? true)
        }
    }

    @ViewBuilder
    private var removeControl: some View {
        if skill.installations.count > 1 {
            Menu("Remove Installation", systemImage: "trash") {
                ForEach(skill.installations) { installation in
                    Button(installation.agent.displayName, role: .destructive) {
                        removalInstallation = installation
                    }
                    .disabled(!installation.localState.permitsMutation)
                }
            }
        } else {
            Button("Remove Installation", systemImage: "trash", role: .destructive) {
                removalInstallation = skill.installations.first
            }
            .disabled(skill.installations.isEmpty)
            .disabled(skill.installations.first.map { !$0.localState.permitsMutation } ?? true)
        }
    }

    @ViewBuilder
    private var baselineControl: some View {
        if skill.installations.count > 1 {
            Menu("Set Current as Baseline", systemImage: "checkmark.seal") {
                ForEach(skill.installations) { installation in
                    Button(installation.agent.displayName) {
                        setBaseline(installation)
                    }
                    .disabled(!installation.localState.permitsMutation)
                }
            }
        } else {
            Button("Set Current as Baseline", systemImage: "checkmark.seal") {
                guard let installation = skill.installations.first else { return }
                setBaseline(installation)
            }
            .disabled(skill.installations.isEmpty)
            .disabled(skill.installations.first.map { !$0.localState.permitsMutation } ?? true)
        }
    }

    private var readerMaximumWidth: Double {
        model.readerWidth == .focused
            ? SpellbookMetrics.focusedReaderWidth
            : SpellbookMetrics.wideReaderWidth
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
        case .editor(let installation):
            SkillEditorSheet(skill: skill, installation: installation)
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
                ContentUnavailableView("Package unavailable", systemImage: "shippingbox")
            }
        }
    }
}
