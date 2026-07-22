import SpellbookCore
import SwiftUI
import UniformTypeIdentifiers

struct SourceSettingsView: View {
    @Environment(SpellbookModel.self) private var model
    @State private var selectedAgent = AgentKind.codex
    @State private var showsFolderImporter = false
    @State private var importerError: String?
    @State private var publishingRepository = ""
    @State private var publishingBranch = "main"
    @State private var publishingError: String?
    @State private var showsSourceRootImporter = false

    var body: some View {
        @Bindable var model = model

        Form {
            Section("Additional folders") {
                Picker("Treat skills as", selection: $selectedAgent) {
                    ForEach(AgentKind.allCases) { agent in
                        Text(agent.displayName).tag(agent)
                    }
                }

                Button("Add Folder…", systemImage: "folder.badge.plus", action: showFolderImporter)

                if customRoots.isEmpty {
                    Text("No additional folders")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(customRoots) { root in
                        LabeledContent {
                            Button("Stop Scanning", systemImage: "minus.circle") {
                                remove(root)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                            .help("Stop scanning this folder")
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(root.agent.displayName)
                                Text(root.url.path(percentEncoded: false))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                }

                if let rootError = model.rootError ?? importerError {
                    Label(rootError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Sources") {
                LabeledContent("Repositories", value: "\(model.repositories.count)")
                LabeledContent("Verified packages", value: "\(verifiedPackageCount)")
                LabeledContent("Needs review", value: "\(reviewCandidateCount)")
                Text("Spellbook checks installer receipts, symlinks, enclosing Git history, manifests, and frontmatter. GitHub search is available from each skill when local evidence is not enough.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Source backtracking") {
                Toggle("Prefer repository titles for all packages", isOn: $model.preferRepositoryTitles)
                Text("Generic labels such as “Skills” are replaced automatically. This option also uses repository titles for packages that already have a useful local name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(model.sourceSearchRoots) { root in
                    LabeledContent {
                        Button("Remove", systemImage: "minus.circle") {
                            Task { await model.removeSourceSearchRoot(root) }
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                    } label: {
                        Text(root.url.path)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Button("Add Trusted Code Root…", systemImage: "folder.badge.plus") {
                    showsSourceRootImporter = true
                }
                Toggle("Search entire user directory with Spotlight", isOn: $model.searchesEntireHome)
                Text("Off by default. Spellbook never expands beyond the trusted roots above unless you explicitly enable this option.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Personal publishing repository") {
                TextField("Existing Git URL or local bare repository", text: $publishingRepository)
                    .textFieldStyle(.roundedBorder)
                TextField("Branch", text: $publishingBranch)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Text("Spellbook never creates a repository or force-pushes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let target = model.publishingTargets.first(where: { $0.packageOverrideIDs.isEmpty }) {
                        Button("Remove", role: .destructive) {
                            Task { await model.removePublishingTarget(target) }
                        }
                    }
                    Button("Save") { savePublishingTarget() }
                        .disabled(publishingRepository.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let publishingError {
                    Label(publishingError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Sources")
        .fileImporter(
            isPresented: $showsFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: importFolder
        )
        .fileImporter(
            isPresented: $showsSourceRootImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: importSourceRoot
        )
        .task { loadPublishingTarget() }
        .onChange(of: model.preferRepositoryTitles) { model.savePreferences() }
        .onChange(of: model.searchesEntireHome) {
            Task { await model.setSearchesEntireHome(model.searchesEntireHome) }
        }
    }

    private var customRoots: [DiscoveryRootRecord] {
        model.discoveryRoots.filter { !$0.isKnown }
    }

    private var verifiedPackageCount: Int {
        model.packageProvenance.filter { $0.confidence == .verified }.count
    }

    private var reviewCandidateCount: Int {
        model.sourceCandidates.filter { !$0.isRejected }.count
    }

    private func showFolderImporter() {
        importerError = nil
        showsFolderImporter = true
    }

    private func importFolder(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await model.addDiscoveryRoot(agent: selectedAgent, url: url)
            }
        case .failure(let error):
            importerError = error.localizedDescription
        }
    }

    private func remove(_ root: DiscoveryRootRecord) {
        Task {
            await model.removeDiscoveryRoot(id: root.id)
        }
    }

    private func importSourceRoot(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await model.addSourceSearchRoot(url) }
        case .failure(let error):
            importerError = error.localizedDescription
        }
    }

    private func loadPublishingTarget() {
        guard let target = model.publishingTargets.first(where: { $0.packageOverrideIDs.isEmpty }) else { return }
        publishingRepository = target.repositoryURL.isFileURL
            ? target.repositoryURL.path
            : target.repositoryURL.absoluteString
        publishingBranch = target.branch
    }

    private func savePublishingTarget() {
        let raw = publishingRepository.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = raw.hasPrefix("/") ? URL(filePath: raw) : URL(string: raw)
        guard let url else {
            publishingError = "Enter a valid Git URL or absolute local path."
            return
        }
        Task {
            do {
                try await model.configurePublishingTarget(repositoryURL: url, branch: publishingBranch)
                publishingError = nil
            } catch {
                publishingError = error.localizedDescription
            }
        }
    }
}
