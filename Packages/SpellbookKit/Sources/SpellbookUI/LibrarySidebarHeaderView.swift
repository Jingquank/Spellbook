import SpellbookCore
import SwiftUI

struct LibrarySidebarHeaderView: View {
    @Environment(SpellbookModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: SpellbookMetrics.standardSpacing) {
            HStack {
                Text("Spellbook")
                    .font(.title3)
                    .bold()

                Spacer()

                Button("Scan", systemImage: "arrow.clockwise", action: rescan)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .disabled(model.isScanning)
                    .help("Scan for skills")

                Button("Check for Updates", systemImage: "arrow.down.circle", action: checkForUpdates)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .disabled(model.isCheckingForUpdates || model.snapshot.skills.isEmpty)
                    .help("Check connected sources and Git packages for updates")

                Menu {
                    Section("Sort") {
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
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Sort library")
            }

            QuietLibraryModeControl(selection: $model.viewMode)
                .frame(width: 150)
        }
        .padding(.horizontal, SpellbookMetrics.standardSpacing)
        .padding(.top, SpellbookMetrics.sidebarHeaderTopInset)
        .padding(.bottom, SpellbookMetrics.sidebarHeaderBottomInset)
        .onChange(of: model.groupsFirst) { model.savePreferences() }
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
