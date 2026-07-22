import Foundation

struct PackageManifestMetadata: Sendable {
    let rootURL: URL
    let name: String?
    let author: String?
    let sourceURL: URL?
    let websiteURL: URL?
    let stableID: String?
    let artworkPath: String?
}

enum PackageManifestReader {
    private static let manifestPaths = [
        ".claude-plugin/plugin.json",
        ".codex-plugin/plugin.json",
        "plugin.json",
        "manifest.json",
        "package.json"
    ]

    static func read(
        from startURL: URL,
        boundedBy boundaryURL: URL,
        cache: PackageManifestResolutionCache? = nil
    ) -> PackageManifestMetadata? {
        let boundary = boundaryURL.standardizedFileURL
        var current = startURL.standardizedFileURL

        while isDescendantOrEqual(current, of: boundary) {
            if let cached = cache?.result(for: current) {
                if case .found(let metadata) = cached { return metadata }
            } else {
                let metadata = manifest(in: current)
                cache?.store(metadata, for: current)
                if let metadata { return metadata }
            }

            if current == boundary { break }
            let parent = current.deletingLastPathComponent()
            guard parent != current else { break }
            current = parent
        }
        return nil
    }

    private static func manifest(in root: URL) -> PackageManifestMetadata? {
        let available = Set((try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: []
        ))?.map(\.lastPathComponent) ?? [])
        for manifestPath in manifestPaths {
            let firstComponent = manifestPath.split(separator: "/").first.map(String.init) ?? manifestPath
            guard available.contains(firstComponent) else { continue }
            let manifestURL = root.appending(path: manifestPath)
            if let metadata = decode(manifestURL, rootURL: root) { return metadata }
        }
        return nil
    }

    private static func decode(_ url: URL, rootURL: URL) -> PackageManifestMetadata? {
        guard
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let repositoryValue: String? = {
            if let value = object["repository"] as? String { return value }
            if let repository = object["repository"] as? [String: Any] {
                return repository["url"] as? String
            }
            return object["source"] as? String
        }()

        let author: String? = {
            if let value = object["author"] as? String { return value }
            if let author = object["author"] as? [String: Any] { return author["name"] as? String }
            return nil
        }()

        let interface = object["interface"] as? [String: Any]
        let artworkPath = interface?["iconSmall"] as? String
            ?? interface?["icon_small"] as? String
            ?? interface?["logo"] as? String
            ?? interface?["composerIcon"] as? String
            ?? object["iconSmall"] as? String
            ?? object["iconLarge"] as? String
            ?? object["icon"] as? String
            ?? object["logo"] as? String

        return PackageManifestMetadata(
            rootURL: rootURL,
            name: object["name"] as? String ?? object["displayName"] as? String,
            author: author,
            sourceURL: repositoryValue.flatMap(RepositoryURLNormalizer.url(from:)),
            websiteURL: (object["homepage"] as? String).flatMap(RepositoryURLNormalizer.url(from:)),
            stableID: object["id"] as? String,
            artworkPath: artworkPath
        )
    }

    private static func isDescendantOrEqual(_ url: URL, of ancestor: URL) -> Bool {
        let path = url.standardizedFileURL.pathComponents
        let ancestorPath = ancestor.standardizedFileURL.pathComponents
        return path.count >= ancestorPath.count && Array(path.prefix(ancestorPath.count)) == ancestorPath
    }
}

final class PackageManifestResolutionCache: @unchecked Sendable {
    enum Result {
        case found(PackageManifestMetadata)
        case missing
    }

    private var values = [String: Result]()

    func result(for directory: URL) -> Result? {
        values[directory.standardizedFileURL.path]
    }

    func store(_ metadata: PackageManifestMetadata?, for directory: URL) {
        values[directory.standardizedFileURL.path] = metadata.map(Result.found) ?? .missing
    }
}
