import Foundation
import SpellbookCore

enum ArtworkResolver {
    private static let supportedExtensions = ["png", "jpg", "jpeg", "webp", "svg", "icns"]
    private static let maximumBytes = 5 * 1_024 * 1_024

    static func resolveSkillArtwork(
        skillRoot: URL,
        packageRoot: URL,
        skillName: String,
        interfaceMetadata: AgentInterfaceMetadata?,
        frontmatterPath: String?,
        cache: ArtworkResolutionCache? = nil
    ) -> ArtworkReference? {
        let declared = [
            interfaceMetadata?.smallIconPath,
            interfaceMetadata?.largeIconPath,
            frontmatterPath
        ].compactMap { $0 }

        for path in declared {
            if let reference = reference(
                path: path,
                relativeTo: skillRoot,
                boundary: skillRoot,
                scope: .skill,
                confidence: .verified
            ) { return reference }
        }

        let slug = slugified(skillName)
        let candidates = supportedExtensions.flatMap { ext in
            [
                "assets/\(slug)-icon.\(ext)",
                "assets/icon.\(ext)",
                "\(slug)-icon.\(ext)",
                "icon.\(ext)"
            ]
        }
        return conventionalReference(
            candidates: candidates,
            root: skillRoot,
            scope: .skill,
            cache: cache
        )
    }

    static func resolvePackageArtwork(
        packageRoot: URL,
        declaredPath: String?,
        cache: ArtworkResolutionCache? = nil
    ) -> ArtworkReference? {
        if let declaredPath, let reference = reference(
            path: declaredPath,
            relativeTo: packageRoot,
            boundary: packageRoot,
            scope: .package,
            confidence: .verified
        ) { return reference }

        let candidates = supportedExtensions.flatMap { ext in
            ["logo.\(ext)", "icon.\(ext)", "assets/logo.\(ext)", "assets/icon.\(ext)"]
        }
        return conventionalReference(
            candidates: candidates,
            root: packageRoot,
            scope: .package,
            cache: cache
        )
    }

    private static func conventionalReference(
        candidates: [String],
        root: URL,
        scope: ArtworkScope,
        cache: ArtworkResolutionCache?
    ) -> ArtworkReference? {
        let available = cache?.availableRelativePaths(in: root)
            ?? availableRelativePaths(in: root)
        for candidate in candidates where available.contains(candidate.lowercased()) {
            if let reference = reference(
                path: candidate,
                relativeTo: root,
                boundary: root,
                scope: scope,
                confidence: .likely
            ) { return reference }
        }
        return nil
    }

    fileprivate static func availableRelativePaths(in root: URL) -> Set<String> {
        let fileManager = FileManager.default
        var paths = Set<String>()
        if let files = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for file in files where supportedExtensions.contains(file.pathExtension.lowercased()) {
                paths.insert(file.lastPathComponent.lowercased())
            }
        }
        let assets = root.appending(path: "assets", directoryHint: .isDirectory)
        if let files = try? fileManager.contentsOfDirectory(
            at: assets,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for file in files where supportedExtensions.contains(file.pathExtension.lowercased()) {
                paths.insert("assets/\(file.lastPathComponent.lowercased())")
            }
        }
        return paths
    }

    private static func reference(
        path: String,
        relativeTo root: URL,
        boundary: URL,
        scope: ArtworkScope,
        confidence: ProvenanceConfidence
    ) -> ArtworkReference? {
        let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "./", with: "", options: [.anchored])
        guard !cleanPath.isEmpty else { return nil }
        let url = root.appending(path: cleanPath).standardizedFileURL
        let resolved = url.resolvingSymlinksInPath()
        let resolvedBoundary = boundary.standardizedFileURL.resolvingSymlinksInPath()
        guard resolved.isDescendantOrEqual(to: resolvedBoundary) else { return nil }
        guard supportedExtensions.contains(resolved.pathExtension.lowercased()) else { return nil }
        guard !FileManager.default.isExecutableFile(atPath: resolved.path) else { return nil }
        guard
            let values = try? resolved.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
            values.isRegularFile == true,
            let size = values.fileSize,
            size > 0,
            size <= maximumBytes,
            let data = try? Data(contentsOf: resolved, options: .mappedIfSafe),
            isSafe(data: data, extension: resolved.pathExtension.lowercased())
        else { return nil }

        return ArtworkReference(
            scope: scope,
            declaredPath: cleanPath,
            localURL: resolved,
            contentHash: StableHasher.sha256(data),
            confidence: confidence
        )
    }

    private static func isSafe(data: Data, extension fileExtension: String) -> Bool {
        switch fileExtension {
        case "png":
            return data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        case "jpg", "jpeg":
            return data.starts(with: [0xFF, 0xD8, 0xFF])
        case "webp":
            return data.count >= 12
                && String(data: data.prefix(4), encoding: .ascii) == "RIFF"
                && String(data: data.dropFirst(8).prefix(4), encoding: .ascii) == "WEBP"
        case "icns":
            return String(data: data.prefix(4), encoding: .ascii) == "icns"
        case "svg":
            guard let text = String(data: data, encoding: .utf8) else { return false }
            let lowered = text.lowercased()
            return lowered.contains("<svg")
                && !lowered.contains("<script")
                && !lowered.contains("javascript:")
                && !lowered.contains("href=\"http")
                && !lowered.contains("href='http")
                && !lowered.contains("xlink:href=\"http")
        default:
            return false
        }
    }

    private static func slugified(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
    }
}

final class ArtworkResolutionCache: @unchecked Sendable {
    private var values = [String: Set<String>]()

    func availableRelativePaths(in root: URL) -> Set<String> {
        let key = root.standardizedFileURL.path
        if let value = values[key] { return value }
        let value = ArtworkResolver.availableRelativePaths(in: root)
        values[key] = value
        return value
    }
}

private extension URL {
    func isDescendantOrEqual(to ancestor: URL) -> Bool {
        let components = standardizedFileURL.pathComponents
        let ancestorComponents = ancestor.standardizedFileURL.pathComponents
        return components.count >= ancestorComponents.count
            && Array(components.prefix(ancestorComponents.count)) == ancestorComponents
    }
}
