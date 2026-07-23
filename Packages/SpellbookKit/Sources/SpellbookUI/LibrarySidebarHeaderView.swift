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
                    icon: .refresh,
                    isDisabled: model.isScanning,
                    action: rescan
                )
                maintenanceButton(
                    "Check for Updates",
                    icon: .downloadCircle,
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

        return SpellbookIconMenu(
            icon: .filterList,
            label: "Library View",
            size: SpellbookIconUsage.denseChrome,
            frame: .compact,
            colorRole: .interactive
        ) {
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
                            Label(mode.displayName, systemImage: NativeSystemSymbol.checkmark.name)
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
        }
    }

    @ViewBuilder
    private var libraryStatus: some View {
        if model.isScanning {
            SpellbookIconLabel(
                title: "Scanning \(model.scannedFileCount) files",
                icon: .refresh,
                colorRole: .secondary
            )
                .foregroundStyle(SpellbookDesign.Palette.textSecondary)
        } else if model.isCheckingForUpdates {
            SpellbookIconLabel(
                title: "Checking for updates",
                icon: .downloadCircle,
                colorRole: .update
            )
                .foregroundStyle(SpellbookDesign.Palette.update)
        } else if !model.updateCandidates.isEmpty {
            Button {
                model.reviewAllUpdates()
            } label: {
                SpellbookIconLabel(
                    title: "\(model.updateCandidates.count) updates",
                    icon: .downloadCircle,
                    colorRole: .update
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(SpellbookDesign.Palette.update)
            .sidebarHoverSurface()
        } else {
            SpellbookIconLabel(
                title: "\(model.logicalSkillCount) skills",
                icon: .checkCircle,
                colorRole: .secondary
            )
                .foregroundStyle(SpellbookDesign.Palette.textSecondary)
        }
    }

    private func maintenanceButton(
        _ label: String,
        icon: SpellbookIcon,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        SpellbookIconButton(
            icon: icon,
            label: label,
            size: SpellbookIconUsage.standardControl,
            frame: .compact,
            colorRole: .interactive,
            action: action
        )
            .disabled(isDisabled)
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
