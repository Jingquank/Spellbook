import SpellbookCore
import SwiftUI

struct GeneralSettingsView: View {
    @Environment(SpellbookModel.self) private var model
    @State private var pendingRestorePlan: ManagedMutationPlan?
    @State private var restoreError: String?

    var body: some View {
        @Bindable var model = model

        Form {
            Section("Discovery") {
                Toggle("Scan known folders when Spellbook opens", isOn: $model.scanOnLaunch)
                LabeledContent("Last scan") {
                    if let scannedAt = model.snapshot.scannedAt {
                        Text(scannedAt, format: .dateTime)
                    } else {
                        Text("Not yet scanned")
                            .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                    }
                }
                Button(action: rescan) {
                    SpellbookIconLabel(title: "Scan Now", icon: .refresh)
                }
                    .disabled(model.isScanning)
            }

            OperationHistorySectionView(
                operations: model.recentOperations,
                onRestore: prepareRestore
            )

            if let catalogError = model.catalogError {
                Section("Catalog") {
                    SpellbookIconLabel(
                        title: catalogError,
                        icon: .warningTriangle,
                        colorRole: .warning
                    )
                        .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                    Button {
                        Task { await model.rebuildCatalog() }
                    } label: {
                        SpellbookIconLabel(title: "Preserve and Rebuild Index", icon: .refreshDouble)
                    }
                }
            }

            if let preservedCatalogURL = model.preservedCatalogURL {
                Section("Preserved catalog") {
                    LabeledContent("Location") {
                        Text(preservedCatalogURL.path(percentEncoded: false))
                            .font(SpellbookDesign.Typography.codeMetadata)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([preservedCatalogURL])
                    } label: {
                        SpellbookIconLabel(title: "Reveal in Finder", icon: .folder)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .sheet(item: $pendingRestorePlan) { plan in
            MutationPlanReviewSheet(plan: plan) { _ in
                pendingRestorePlan = nil
            }
        }
        .alert("Couldn’t prepare restore", isPresented: Binding(
            get: { restoreError != nil },
            set: { if !$0 { restoreError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreError ?? "Unknown error")
        }
    }

    private func rescan() {
        Task {
            await model.rescan()
        }
    }

    private func prepareRestore(_ operation: ManagedOperationRecord) {
        Task {
            do {
                pendingRestorePlan = try await model.planRestore(operation)
            } catch {
                restoreError = error.localizedDescription
            }
        }
    }
}
