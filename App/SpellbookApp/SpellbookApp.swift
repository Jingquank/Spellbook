import SpellbookInfrastructure
import SpellbookUI
import SwiftUI

@main
struct SpellbookApp: App {
    @State private var model: SpellbookModel

    init() {
        SpellbookUIBootstrap.prepareDesignSystem()
        if ProcessInfo.processInfo.arguments.contains("--ui-test-fixture") {
            _model = State(initialValue: UITestFixtures.makeModel())
            return
        }
        let initialStore: GRDBCatalogStore?
        let initialCatalogError: String?
        do {
            initialStore = try GRDBCatalogStore()
            initialCatalogError = nil
        } catch {
            initialStore = nil
            initialCatalogError = "Spellbook could not open its catalog. Your skill files are untouched. Preserve the damaged index before rebuilding it. \(error.localizedDescription)"
        }
        let catalog = CatalogStoreProxy(
            store: initialStore,
            unavailableReason: initialCatalogError ?? "The Spellbook catalog is unavailable."
        )
        let catalogRepairer = CatalogRepairService(proxy: catalog)
        let rootRegistry = DiscoveryRootRegistry(catalog: catalog)
        let manager = FileSystemSkillManager(catalog: catalog)
        _model = State(initialValue: SpellbookModel(
            scanner: FileSystemSkillScanner(registry: rootRegistry, catalog: catalog),
            manager: manager,
            changeMonitor: FSEventsSkillChangeMonitor(registry: rootRegistry),
            updater: SourceUpdateCoordinator(catalog: catalog, manager: manager),
            sourceDiscovery: GitHubSourceDiscovery(),
            packageTitleDiscovery: GitHubPackageTitleDiscovery(),
            packageArtworkDiscovery: GitHubPackageArtworkDiscovery(),
            publisher: GitPackagePublisher(),
            catalog: catalog,
            rootManager: rootRegistry,
            catalogRepairer: catalogRepairer,
            initialCatalogError: initialCatalogError
        ))
    }

    var body: some Scene {
        WindowGroup {
            SpellbookRootView()
                .environment(model)
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1180, height: 780)
        .windowToolbarStyle(.unified(showsTitle: false))

        Settings {
            SpellbookSettingsView()
                .environment(model)
                .interfaceAppearance(textScale: model.textScale, density: model.density)
                .frame(
                    minWidth: 520,
                    idealWidth: 620,
                    minHeight: 400,
                    idealHeight: 460
                )
        }
    }
}
