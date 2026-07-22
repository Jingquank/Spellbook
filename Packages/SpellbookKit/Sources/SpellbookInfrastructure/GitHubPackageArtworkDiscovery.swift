import CryptoKit
import Foundation
import ImageIO
import SpellbookCore

public actor GitHubPackageArtworkDiscovery: PackageArtworkDiscovering {
    private struct RepositoryMetadata: Decodable {
        struct Owner: Decodable {
            let login: String
            let type: String
            let avatarURL: URL

            enum CodingKeys: String, CodingKey {
                case login, type
                case avatarURL = "avatar_url"
            }
        }

        let defaultBranch: String
        let owner: Owner

        enum CodingKeys: String, CodingKey {
            case owner
            case defaultBranch = "default_branch"
        }
    }

    private struct GraphQLResponse: Decodable {
        struct DataValue: Decodable {
            struct Repository: Decodable {
                let usesCustomOpenGraphImage: Bool
                let openGraphImageURL: URL

                enum CodingKeys: String, CodingKey {
                    case usesCustomOpenGraphImage
                    case openGraphImageURL = "openGraphImageUrl"
                }
            }
            let repository: Repository?
        }
        let data: DataValue
    }

    private struct ReadmeCandidate {
        let source: String
        let alt: String
        let context: String
        let location: Int
    }

    private struct InspectedImage {
        let reference: ArtworkReference
        let width: Int
        let height: Int
    }

    private let maximumBytes = 5 * 1_024 * 1_024
    private var githubAuthenticated: Bool?

    public init() {}

    public func discoverArtwork(for query: PackageArtworkQuery) async throws -> [PackageArtworkEvidence] {
        if query.sourceURL.isFileURL {
            return try await localArtwork(for: query)
        }
        guard query.sourceURL.host?.lowercased() == "github.com",
              let repository = repositoryCoordinates(query.sourceURL)
        else {
            throw SourceDiscoveryError.unavailable("Artwork discovery supports verified GitHub and local repositories.")
        }
        return try await githubArtwork(for: query, repository: repository)
    }

    private func githubArtwork(
        for query: PackageArtworkQuery,
        repository: String
    ) async throws -> [PackageArtworkEvidence] {
        let authenticated = isGitHubAuthenticated()
        let metadataData: Data
        if authenticated {
            metadataData = try runGH(["api", "repos/\(repository)"])
        } else {
            let url = URL(string: "https://api.github.com/repos/\(repository)")!
            metadataData = try await request(url, accept: "application/vnd.github+json").0
        }
        let metadata = try JSONDecoder().decode(RepositoryMetadata.self, from: metadataData)
        let revision = query.revision ?? metadata.defaultBranch
        let observedAt = Date()
        var evidence = [PackageArtworkEvidence]()

        if authenticated,
           let previewURL = try customSocialPreviewURL(repository: repository),
           let inspected = await inspectRemoteImage(previewURL, declaredName: "github-social-preview") {
            evidence.append(PackageArtworkEvidence(
                packageID: query.packageID,
                sourceKind: .githubSocialPreview,
                artwork: inspected.reference,
                contentMode: .fill,
                repositoryURL: query.sourceURL,
                revision: revision,
                observedAt: observedAt
            ))
        }

        if metadata.owner.type.caseInsensitiveCompare("Organization") == .orderedSame,
           let inspected = await inspectRemoteImage(
               metadata.owner.avatarURL,
               declaredName: "github-organization-avatar"
           ) {
            evidence.append(PackageArtworkEvidence(
                packageID: query.packageID,
                sourceKind: .githubOrganizationAvatar,
                artwork: inspected.reference,
                contentMode: .fill,
                repositoryURL: query.sourceURL,
                revision: revision,
                observedAt: observedAt
            ))
        }

        let readme: String?
        if authenticated {
            let data = try? runGH([
                "api", "repos/\(repository)/readme",
                "-X", "GET",
                "-H", "Accept: application/vnd.github.raw+json",
                "-f", "ref=\(revision)"
            ])
            readme = data.flatMap { String(data: $0, encoding: .utf8) }
        } else {
            var components = URLComponents(string: "https://api.github.com/repos/\(repository)/readme")!
            components.queryItems = [URLQueryItem(name: "ref", value: revision)]
            let data = try? await request(
                components.url!,
                accept: "application/vnd.github.raw+json"
            ).0
            readme = data.flatMap { String(data: $0, encoding: .utf8) }
        }
        if let readme,
           let readmeEvidence = await firstRemoteReadmeImage(
               in: readme,
               query: query,
               repository: repository,
               revision: revision,
               observedAt: observedAt
           ) {
            evidence.append(readmeEvidence)
        }

        if metadata.owner.type.caseInsensitiveCompare("User") == .orderedSame,
           let inspected = await inspectRemoteImage(
               metadata.owner.avatarURL,
               declaredName: "github-owner-avatar"
           ) {
            evidence.append(PackageArtworkEvidence(
                packageID: query.packageID,
                sourceKind: .githubOwnerAvatar,
                artwork: inspected.reference,
                contentMode: .fill,
                repositoryURL: query.sourceURL,
                revision: revision,
                observedAt: observedAt
            ))
        }
        return evidence
    }

    private func localArtwork(for query: PackageArtworkQuery) async throws -> [PackageArtworkEvidence] {
        let root = query.sourceURL.standardizedFileURL
        guard let rootContents = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        let readmeURLs = rootContents
            .filter {
                $0.deletingPathExtension().lastPathComponent.caseInsensitiveCompare("readme") == .orderedSame
                    && ["", "md", "markdown"].contains($0.pathExtension.lowercased())
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        guard let readmeURL = readmeURLs.first,
        let markdown = try? String(contentsOf: readmeURL, encoding: .utf8)
        else { return [] }

        for candidate in readmeCandidates(in: markdown) where !isBlocked(candidate) {
            guard let url = resolveLocal(candidate.source, relativeTo: readmeURL, boundary: root) else { continue }
            guard let inspected = inspectLocalImage(url) else { continue }
            if qualifiesForReadme(inspected) {
                return [PackageArtworkEvidence(
                    packageID: query.packageID,
                    sourceKind: .readmeImage,
                    artwork: inspected.reference,
                    contentMode: .fill,
                    repositoryURL: query.sourceURL,
                    revision: query.revision,
                    observedAt: .now
                )]
            }
        }
        return []
    }

    private func firstRemoteReadmeImage(
        in markdown: String,
        query: PackageArtworkQuery,
        repository: String,
        revision: String,
        observedAt: Date
    ) async -> PackageArtworkEvidence? {
        for candidate in readmeCandidates(in: markdown) where !isBlocked(candidate) {
            guard let url = resolveRemote(candidate.source, repository: repository, revision: revision),
                  let inspected = await inspectRemoteImage(url, declaredName: "readme-image"),
                  qualifiesForReadme(inspected)
            else { continue }
            return PackageArtworkEvidence(
                packageID: query.packageID,
                sourceKind: .readmeImage,
                artwork: inspected.reference,
                contentMode: .fill,
                repositoryURL: query.sourceURL,
                revision: revision,
                observedAt: observedAt
            )
        }
        return nil
    }

    private func readmeCandidates(in markdown: String) -> [ReadmeCandidate] {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
        var prefixLines = [String]()
        for lineValue in lines {
            let line = String(lineValue)
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("## ") { break }
            prefixLines.append(line)
        }
        let prefix = prefixLines.joined(separator: "\n")
        var candidates = [ReadmeCandidate]()

        let markdownPattern = #"!\[([^\]]*)\]\(([^\s\)]+)(?:\s+[\"'][^\"']*[\"'])?\)"#
        if let regex = try? NSRegularExpression(pattern: markdownPattern) {
            let range = NSRange(prefix.startIndex..., in: prefix)
            for match in regex.matches(in: prefix, range: range) {
                guard let sourceRange = Range(match.range(at: 2), in: prefix) else { continue }
                let alt = Range(match.range(at: 1), in: prefix).map { String(prefix[$0]) } ?? ""
                let context = lineContext(for: match.range.location, in: prefix)
                candidates.append(ReadmeCandidate(
                    source: String(prefix[sourceRange]),
                    alt: alt,
                    context: context,
                    location: match.range.location
                ))
            }
        }

        let htmlPattern = #"<img\b[^>]*>"#
        if let regex = try? NSRegularExpression(pattern: htmlPattern, options: [.caseInsensitive]) {
            let range = NSRange(prefix.startIndex..., in: prefix)
            for match in regex.matches(in: prefix, range: range) {
                guard let tagRange = Range(match.range, in: prefix) else { continue }
                let tag = String(prefix[tagRange])
                guard let source = htmlAttribute("src", in: tag) else { continue }
                let context = lineContext(for: match.range.location, in: prefix)
                candidates.append(ReadmeCandidate(
                    source: source,
                    alt: htmlAttribute("alt", in: tag) ?? "",
                    context: context,
                    location: match.range.location
                ))
            }
        }
        return candidates.sorted { $0.location < $1.location }
    }

    private func htmlAttribute(_ name: String, in tag: String) -> String? {
        let pattern = #"(?:^|\s)"# + NSRegularExpression.escapedPattern(for: name)
            + #"\s*=\s*(?:[\"']([^\"']*)[\"']|([^\s>]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag))
        else { return nil }
        for index in 1..<match.numberOfRanges {
            if let range = Range(match.range(at: index), in: tag) { return String(tag[range]) }
        }
        return nil
    }

    private func lineContext(for utf16Location: Int, in text: String) -> String {
        let location = String.Index(utf16Offset: utf16Location, in: text)
        let start = text[..<location].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
        let end = text[location...].firstIndex(of: "\n") ?? text.endIndex
        return String(text[start..<end])
    }

    private func isBlocked(_ candidate: ReadmeCandidate) -> Bool {
        let value = "\(candidate.alt) \(candidate.source) \(candidate.context)".lowercased()
        let tokens = Set(value.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        let blocked = Set(["license", "licence", "mit", "badge", "badges", "shield", "shields", "build", "ci", "coverage", "status"])
        return !tokens.isDisjoint(with: blocked) || value.contains("shields.io")
    }

    private func qualifiesForReadme(_ image: InspectedImage) -> Bool {
        guard image.width >= 64, image.height >= 64 else { return false }
        let ratio = Double(image.width) / Double(image.height)
        return (0.75...1.33).contains(ratio)
    }

    private func inspectLocalImage(_ url: URL) -> InspectedImage? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              let kind = detectedKind(data, suggestedExtension: url.pathExtension),
              isSafe(data, kind: kind),
              let dimensions = dimensions(of: data, kind: kind)
        else { return nil }
        return InspectedImage(
            reference: ArtworkReference(
                scope: .package,
                declaredPath: url.lastPathComponent,
                localURL: url,
                contentHash: digest(data),
                confidence: .verified
            ),
            width: dimensions.width,
            height: dimensions.height
        )
    }

    private func inspectRemoteImage(_ url: URL, declaredName: String) async -> InspectedImage? {
        guard url.scheme?.lowercased() == "https",
              let (data, response) = try? await request(url, accept: "image/*"),
              !data.isEmpty,
              data.count <= maximumBytes,
              let kind = detectedKind(
                  data,
                  suggestedExtension: url.pathExtension.isEmpty
                      ? response.mimeType?.split(separator: "/").last.map(String.init) ?? ""
                      : url.pathExtension
              ),
              isSafe(data, kind: kind),
              let dimensions = dimensions(of: data, kind: kind)
        else { return nil }
        return InspectedImage(
            reference: ArtworkReference(
                scope: .package,
                declaredPath: "\(declaredName).\(kind)",
                remoteURL: url,
                contentHash: digest(data),
                confidence: .verified
            ),
            width: dimensions.width,
            height: dimensions.height
        )
    }

    private func detectedKind(_ data: Data, suggestedExtension: String) -> String? {
        let ext = suggestedExtension.lowercased()
        if ["png", "jpg", "jpeg", "webp", "svg", "icns"].contains(ext) { return ext == "jpeg" ? "jpg" : ext }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpg" }
        if data.count >= 12,
           String(data: data.prefix(4), encoding: .ascii) == "RIFF",
           String(data: data.dropFirst(8).prefix(4), encoding: .ascii) == "WEBP" { return "webp" }
        if String(data: data.prefix(4), encoding: .ascii) == "icns" { return "icns" }
        if String(data: data.prefix(512), encoding: .utf8)?.lowercased().contains("<svg") == true { return "svg" }
        return nil
    }

    private func isSafe(_ data: Data, kind: String) -> Bool {
        guard !data.isEmpty, data.count <= maximumBytes else { return false }
        switch kind {
        case "png": return data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        case "jpg": return data.starts(with: [0xFF, 0xD8, 0xFF])
        case "webp":
            return data.count >= 12
                && String(data: data.prefix(4), encoding: .ascii) == "RIFF"
                && String(data: data.dropFirst(8).prefix(4), encoding: .ascii) == "WEBP"
        case "icns": return String(data: data.prefix(4), encoding: .ascii) == "icns"
        case "svg":
            guard let text = String(data: data, encoding: .utf8)?.lowercased() else { return false }
            return text.contains("<svg")
                && !text.contains("<script")
                && !text.contains("javascript:")
                && !text.contains("href=\"http")
                && !text.contains("href='http")
                && !text.contains("xlink:href=\"http")
        default: return false
        }
    }

    private func dimensions(of data: Data, kind: String) -> (width: Int, height: Int)? {
        if kind == "svg" { return svgDimensions(data) }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber
        else { return nil }
        return (width.intValue, height.intValue)
    }

    private func svgDimensions(_ data: Data) -> (width: Int, height: Int)? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        func number(_ attribute: String) -> Double? {
            let pattern = attribute + #"\s*=\s*[\"']([0-9]+(?:\.[0-9]+)?)"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text)
            else { return nil }
            return Double(text[range])
        }
        if let width = number("width"), let height = number("height") {
            return (Int(width), Int(height))
        }
        let pattern = #"viewBox\s*=\s*[\"'][^\"']*?([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)[\"']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let widthRange = Range(match.range(at: 1), in: text),
              let heightRange = Range(match.range(at: 2), in: text),
              let width = Double(text[widthRange]),
              let height = Double(text[heightRange])
        else { return nil }
        return (Int(width), Int(height))
    }

    private func resolveRemote(_ value: String, repository: String, revision: String) -> URL? {
        let cleaned = decoded(value)
        if let absolute = URL(string: cleaned), absolute.scheme?.lowercased() == "https" { return absolute }
        let components = cleaned.split(separator: "/")
        guard !components.contains("..") else { return nil }
        let path = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "https://raw.githubusercontent.com/\(repository)/\(revision)/\(path)")
    }

    private func resolveLocal(_ value: String, relativeTo readmeURL: URL, boundary: URL) -> URL? {
        let cleaned = decoded(value)
        guard URL(string: cleaned)?.scheme == nil else { return nil }
        let url = readmeURL.deletingLastPathComponent().appending(path: cleaned).standardizedFileURL
            .resolvingSymlinksInPath()
        let root = boundary.standardizedFileURL.resolvingSymlinksInPath()
        guard url.pathComponents.starts(with: root.pathComponents) else { return nil }
        return url
    }

    private func decoded(_ value: String) -> String {
        value.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "./", with: "", options: [.anchored])
    }

    private func customSocialPreviewURL(repository: String) throws -> URL? {
        let parts = repository.split(separator: "/")
        guard parts.count >= 2 else { return nil }
        let query = """
        query($owner:String!, $name:String!) {
          repository(owner:$owner, name:$name) {
            usesCustomOpenGraphImage
            openGraphImageUrl
          }
        }
        """
        let data = try runGH([
            "api", "graphql",
            "-f", "query=\(query)",
            "-F", "owner=\(parts[0])",
            "-F", "name=\(parts[1])"
        ])
        let response = try JSONDecoder().decode(GraphQLResponse.self, from: data)
        guard response.data.repository?.usesCustomOpenGraphImage == true else { return nil }
        return response.data.repository?.openGraphImageURL
    }

    private func repositoryCoordinates(_ url: URL) -> String? {
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .replacingOccurrences(of: ".git", with: "", options: [.anchored, .backwards])
        return path.split(separator: "/").count >= 2 ? path : nil
    }

    private func request(_ url: URL, accept: String) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("Spellbook/1.0", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .returnCacheDataElseLoad
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SourceDiscoveryError.invalidResponse }
        guard http.url?.scheme?.lowercased() == "https" else {
            throw SourceDiscoveryError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SourceDiscoveryError.unavailable("GitHub artwork failed with status \(http.statusCode).")
        }
        return (data, http)
    }

    private func isGitHubAuthenticated() -> Bool {
        if let githubAuthenticated { return githubAuthenticated }
        let value = Self.ghURL != nil && (try? runGH(["auth", "status"])) != nil
        githubAuthenticated = value
        return value
    }

    private func runGH(_ arguments: [String]) throws -> Data {
        guard let ghURL = Self.ghURL else { throw SourceDiscoveryError.unavailable("GitHub CLI is not installed.") }
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = ghURL
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            throw SourceDiscoveryError.unavailable(message ?? "GitHub CLI failed.")
        }
        return data
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static var ghURL: URL? {
        ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
            .first(where: FileManager.default.isExecutableFile(atPath:))
            .map { URL(filePath: $0) }
    }
}
