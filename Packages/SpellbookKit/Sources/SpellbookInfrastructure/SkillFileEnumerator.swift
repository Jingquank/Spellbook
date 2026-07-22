import Foundation

enum SkillFileEnumerator {
    private static let ignoredDirectoryNames: Set<String> = [
        ".git", ".build", "DerivedData", "node_modules"
    ]

    static func entries(in rootURL: URL) -> [URL] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory) else {
            return []
        }

        if !isDirectory.boolValue {
            return isSkillEntry(rootURL) ? [rootURL.standardizedFileURL] : []
        }

        var entries = regularEntries(in: rootURL)
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        if let children = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: Array(keys),
            options: []
        ) {
            for child in children {
                guard
                    let values = try? child.resourceValues(forKeys: keys),
                    values.isSymbolicLink == true
                else { continue }
                let target = child.resolvingSymlinksInPath()
                var targetIsDirectory: ObjCBool = false
                guard
                    fileManager.fileExists(atPath: target.path, isDirectory: &targetIsDirectory),
                    targetIsDirectory.boolValue
                else { continue }
                entries.append(contentsOf: regularEntries(in: target).compactMap { targetEntry in
                    guard let relative = relativePath(targetEntry, to: target) else { return nil }
                    return child.appending(path: relative).standardizedFileURL
                })
            }
        }

        return entries.uniqued().sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private static func regularEntries(in rootURL: URL) -> [URL] {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        var entries = [URL]()
        while let item = enumerator.nextObject() as? URL {
            guard let values = try? item.resourceValues(forKeys: Set(keys)) else { continue }

            if values.isDirectory == true {
                if values.isSymbolicLink == true || ignoredDirectoryNames.contains(item.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard values.isRegularFile == true, values.isSymbolicLink != true, isSkillEntry(item) else {
                continue
            }
            entries.append(item.standardizedFileURL)
        }

        return entries
    }

    private static func isSkillEntry(_ url: URL) -> Bool {
        let filename = url.lastPathComponent.lowercased()
        return filename == "skill.md" || filename.hasSuffix(".agent.claude.md")
    }

    private static func relativePath(_ url: URL, to ancestor: URL) -> String? {
        let path = url.standardizedFileURL.pathComponents
        let root = ancestor.standardizedFileURL.pathComponents
        guard path.count >= root.count, Array(path.prefix(root.count)) == root else { return nil }
        return path.dropFirst(root.count).joined(separator: "/")
    }
}

private extension Array where Element == URL {
    func uniqued() -> [URL] {
        var seen = Set<String>()
        return filter { seen.insert($0.standardizedFileURL.path).inserted }
    }
}
