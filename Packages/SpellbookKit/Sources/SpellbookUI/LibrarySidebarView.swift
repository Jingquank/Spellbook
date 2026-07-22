import SpellbookCore
import SwiftUI

struct LibrarySidebarView: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.interfaceDensity) private var interfaceDensity

    @State private var hasShownNonemptyLibrary = false
    @State private var firstRevealStage = 0

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            LibrarySidebarHeaderView()

            if let scanError = model.scanError, model.snapshot.skills.isEmpty {
                ContentUnavailableView(
                    "Couldn’t scan skills",
                    systemImage: "exclamationmark.triangle",
                    description: Text(scanError)
                )
            } else if model.snapshot.skills.isEmpty, !model.isScanning {
                ContentUnavailableView {
                    Label("No skills found", systemImage: "books.vertical")
                } description: {
                    Text("Spellbook checks the known Claude, Cursor, and Codex skill folders on this Mac.")
                } actions: {
                    Button("Scan Again", systemImage: "arrow.clockwise", action: rescan)
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

            Divider()

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
                } else if model.isCheckingForUpdates {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Checking for updates")
                }

                Button("Settings", systemImage: "gearshape", action: showSettings)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .help("Settings")
            }
            .font(SpellbookDesign.Typography.metadata)
            .padding(.horizontal, SpellbookDesign.Space.large)
            .padding(.vertical, SpellbookDesign.Space.xSmall)
            .frame(minHeight: interfaceDensity == .compact ? 34 : 44)
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

    private func rescan() {
        Task {
            await model.rescan()
        }
    }

    private func showSettings() {
        openSettings()
    }

    private var libraryScrollView: some View {
        ScrollView {
            VStack(spacing: SpellbookDesign.Sidebar.rowSpacing) {
                ForEach(model.projection.nodes) { node in
                    LibraryNodeView(node: node)
                }
            }
            .padding(.horizontal, SpellbookDesign.Sidebar.horizontalInset)
            .padding(.vertical, SpellbookDesign.Sidebar.verticalInset)
        }
        .accessibilityIdentifier("Library sidebar")
    }

    private var firstRevealEligibility: Bool {
        model.searchText.isEmpty
            && !model.isScanning
            && model.scanError == nil
            && !model.projection.nodes.isEmpty
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
