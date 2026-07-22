import Foundation

struct GitRepositoryMetadata: Sendable {
    let rootURL: URL
    let sourceURL: URL?
    let revision: String?
}

enum GitRepositoryInspector {
    static func inspect(
        from startURL: URL,
        boundedBy boundaryURL: URL,
        cache: GitRepositoryInspectionCache? = nil
    ) -> GitRepositoryMetadata? {
        let fileManager = FileManager.default
        let boundary = boundaryURL.standardizedFileURL
        var current = startURL.standardizedFileURL

        while isDescendantOrEqual(current, of: boundary) {
            if let cached = cache?.result(for: current) {
                if case .found(let metadata) = cached { return metadata }
                if current == boundary { break }
                let parent = current.deletingLastPathComponent()
                guard parent != current else { break }
                current = parent
                continue
            }
            let dotGit = current.appending(path: ".git")
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: dotGit.path, isDirectory: &isDirectory) {
                let configURL = gitConfigURL(dotGit, isDirectory: isDirectory.boolValue, repositoryRoot: current)
                let metadata = GitRepositoryMetadata(
                    rootURL: current,
                    sourceURL: configURL.flatMap(originURL(from:)),
                    revision: headRevision(in: current)
                )
                cache?.store(metadata, for: current)
                return metadata
            }
            cache?.store(nil, for: current)

            if current == boundary { break }
            let parent = current.deletingLastPathComponent()
            guard parent != current else { break }
            current = parent
        }
        return nil
    }

    static func trackedContentHash(for fileURL: URL, in repository: GitRepositoryMetadata) -> String? {
        let rootComponents = repository.rootURL.standardizedFileURL.pathComponents
        let fileComponents = fileURL.standardizedFileURL.pathComponents
        guard
            fileComponents.count > rootComponents.count,
            Array(fileComponents.prefix(rootComponents.count)) == rootComponents
        else { return nil }

        let relativePath = fileComponents.dropFirst(rootComponents.count).joined(separator: "/")
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = [
            "-C", repository.rootURL.path,
            "show", "HEAD:\(relativePath)"
        ]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return StableHasher.sha256(data)
    }

    private static func gitConfigURL(_ dotGitURL: URL, isDirectory: Bool, repositoryRoot: URL) -> URL? {
        if isDirectory {
            return dotGitURL.appending(path: "config")
        }

        guard
            let pointer = try? String(contentsOf: dotGitURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
            pointer.lowercased().hasPrefix("gitdir:")
        else { return nil }

        let value = pointer.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
        let gitDirectory: URL
        if value.hasPrefix("/") {
            gitDirectory = URL(filePath: value, directoryHint: .isDirectory)
        } else {
            gitDirectory = repositoryRoot.appending(path: value, directoryHint: .isDirectory).standardizedFileURL
        }

        let commonDirectoryFile = gitDirectory.appending(path: "commondir")
        if let commonValue = try? String(contentsOf: commonDirectoryFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !commonValue.isEmpty {
            let commonDirectory = commonValue.hasPrefix("/")
                ? URL(filePath: commonValue, directoryHint: .isDirectory)
                : gitDirectory.appending(path: commonValue, directoryHint: .isDirectory).standardizedFileURL
            return commonDirectory.appending(path: "config")
        }

        return gitDirectory.appending(path: "config")
    }

    private static func originURL(from configURL: URL) -> URL? {
        guard let config = try? String(contentsOf: configURL, encoding: .utf8) else { return nil }
        var inOrigin = false

        for line in config.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                inOrigin = trimmed.lowercased() == "[remote \"origin\"]"
                continue
            }
            guard inOrigin, let equals = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<equals].trimmingCharacters(in: .whitespaces).lowercased()
            guard key == "url" else { continue }
            return RepositoryURLNormalizer.url(from: String(trimmed[trimmed.index(after: equals)...]))
        }
        return nil
    }

    private static func headRevision(in repositoryRoot: URL) -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = ["-C", repositoryRoot.path, "rev-parse", "HEAD"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let revision = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return revision?.isEmpty == false ? revision : nil
    }

    private static func isDescendantOrEqual(_ url: URL, of ancestor: URL) -> Bool {
        let path = url.standardizedFileURL.pathComponents
        let ancestorPath = ancestor.standardizedFileURL.pathComponents
        return path.count >= ancestorPath.count && Array(path.prefix(ancestorPath.count)) == ancestorPath
    }
}

final class GitRepositoryInspectionCache: @unchecked Sendable {
    enum Result {
        case found(GitRepositoryMetadata)
        case missing
    }
    private var values = [String: Result]()

    func result(for directory: URL) -> Result? { values[directory.standardizedFileURL.path] }
    func store(_ metadata: GitRepositoryMetadata?, for directory: URL) {
        values[directory.standardizedFileURL.path] = metadata.map(Result.found) ?? .missing
    }
}
