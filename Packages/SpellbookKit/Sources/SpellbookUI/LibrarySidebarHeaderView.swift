import SpellbookCore
import SwiftUI

struct LibrarySidebarHeaderView: View {
    @Environment(SpellbookModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: SpellbookDesign.Space.medium) {
            HStack(spacing: SpellbookDesign.Space.small) {
                LibrarySearchField(text: $model.searchText)
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        minHeight: SpellbookDesign.Sidebar.searchFieldHeight,
                        maxHeight: SpellbookDesign.Sidebar.searchFieldHeight
                    )
                    .layoutPriority(1)

                libraryViewMenu
            }

            HStack(spacing: SpellbookDesign.Space.medium) {
                libraryStatus
                Spacer(minLength: SpellbookDesign.Space.small)
                maintenanceButton(
                    "Scan",
                    symbol: "arrow.clockwise",
                    isDisabled: model.isScanning,
                    action: rescan
                )
                maintenanceButton(
                    "Check for Updates",
                    symbol: "arrow.down.circle",
                    isDisabled: model.isCheckingForUpdates || model.snapshot.skills.isEmpty,
                    action: checkForUpdates
                )
                .foregroundStyle(SpellbookDesign.Palette.update)
            }
        }
        .padding(.horizontal, SpellbookDesign.Sidebar.headerHorizontalInset)
        .padding(.vertical, SpellbookDesign.Sidebar.headerVerticalInset)
        .onChange(of: model.groupsFirst) { model.savePreferences() }
    }

    private var libraryViewMenu: some View {
        @Bindable var model = model

        return Menu {
            Section("Organize by") {
                Picker("Organize by", selection: $model.viewMode) {
                    Text("Skill").tag(LibraryViewMode.skillFirst)
                    Text("Agent").tag(LibraryViewMode.agentFirst)
                }
                .labelsHidden()
            }
            Section("Sort by") {
                ForEach(SidebarSortMode.allCases) { mode in
                    Button {
                        model.activeSortMode = mode
                    } label: {
                        if model.activeSortMode == mode {
                            Label(mode.displayName, systemImage: "checkmark")
                        } else {
                            Text(mode.displayName)
                        }
                    }
                }
            }
            if model.viewMode == .skillFirst {
                Divider()
                Toggle("Groups First", isOn: $model.groupsFirst)
            }
        } label: {
            Image(systemName: "rectangle.3.group")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Library View")
        .accessibilityLabel("Library View")
    }

    @ViewBuilder
    private var libraryStatus: some View {
        if model.isScanning {
            Label("Scanning \(model.scannedFileCount) files", systemImage: "arrow.clockwise")
                .foregroundStyle(SpellbookDesign.Palette.textSecondary)
        } else if model.isCheckingForUpdates {
            Label("Checking for updates", systemImage: "arrow.down.circle")
                .foregroundStyle(SpellbookDesign.Palette.update)
        } else if !model.updateCandidates.isEmpty {
            Button {
                model.reviewAllUpdates()
            } label: {
                Label("\(model.updateCandidates.count) updates", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(SpellbookDesign.Palette.update)
        } else {
            Label("\(model.logicalSkillCount) skills", systemImage: "checkmark.circle")
                .foregroundStyle(SpellbookDesign.Palette.textSecondary)
        }
    }

    private func maintenanceButton(
        _ label: String,
        symbol: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(label, systemImage: symbol, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .help(label)
    }

    private func rescan() {
        Task {
            await model.rescan()
        }
    }

    private func checkForUpdates() {
        Task {
            await model.checkForUpdates()
        }
    }
}
