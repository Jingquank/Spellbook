import Foundation
import SpellbookCore

public struct FSEventsSkillChangeMonitor: SkillChangeMonitoring, Sendable {
    private let registry: DiscoveryRootRegistry
    private let rootRefreshInterval: Duration

    public init(
        registry: DiscoveryRootRegistry,
        rootRefreshInterval: Duration = .seconds(5)
    ) {
        self.registry = registry
        self.rootRefreshInterval = rootRefreshInterval
    }

    public func changes() -> AsyncStream<FileChangeBatch> {
        let registry = registry
        let refreshInterval = rootRefreshInterval

        return AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                var watchedPaths = [String]()
                var watcher: FSEventWatcher?

                while !Task.isCancelled {
                    let roots = (try? await registry.skillDiscoveryRoots()) ?? []
                    let availablePaths = roots
                        .map(\.url.standardizedFileURL.path)
                        .filter { FileManager.default.fileExists(atPath: $0) }
                        .sorted()

                    if availablePaths != watchedPaths {
                        watcher?.stop()
                        watchedPaths = availablePaths
                        watcher = FSEventWatcher(paths: availablePaths) { changedPaths in
                            let urls = changedPaths.map { URL(filePath: $0) }
                            guard !urls.isEmpty else { return }
                            continuation.yield(FileChangeBatch(urls: urls))
                        }
                    }

                    do {
                        try await Task.sleep(for: refreshInterval)
                    } catch {
                        break
                    }
                }

                watcher?.stop()
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
