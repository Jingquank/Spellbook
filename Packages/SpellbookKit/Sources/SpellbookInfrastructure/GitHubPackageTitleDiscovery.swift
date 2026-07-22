import Foundation
import SpellbookCore

public actor GitHubPackageTitleDiscovery: PackageTitleDiscovering {
    private struct RepositoryMetadata: Decodable {
        let description: String?
        let defaultBranch: String

        enum CodingKeys: String, CodingKey {
            case description
            case defaultBranch = "default_branch"
        }
    }

    public init() {}

    public func discoverTitle(for query: PackageTitleQuery) async throws -> PackageNameEvidence {
        if query.sourceURL.isFileURL {
            return try localTitle(for: query)
        }
        guard
            query.sourceURL.host?.lowercased() == "github.com",
            let repository = repositoryCoordinates(query.sourceURL)
        else { throw SourceDiscoveryError.unavailable("Repository title discovery currently supports GitHub and local Git repositories.") }

        if Self.ghURL != nil, (try? runGH(["auth", "status"])) != nil {
            return try titleUsingGH(for: query, repository: repository)
        }
        return try await titleUsingPublicAPI(for: query, repository: repository)
    }

    private func titleUsingGH(
        for query: PackageTitleQuery,
        repository: String
    ) throws -> PackageNameEvidence {
        let metadataData = try runGH(["api", "repos/\(repository)"])
        let metadata = try JSONDecoder().decode(RepositoryMetadata.self, from: metadataData)
        let revision = query.revision ?? metadata.defaultBranch
        let readmeData = try? runGH([
            "api", "repos/\(repository)/readme",
            "-X", "GET",
            "-H", "Accept: application/vnd.github.raw+json",
            "-f", "ref=\(revision)"
        ])
        return makeEvidence(
            query: query,
            repository: repository,
            revision: revision,
            readme: readmeData.flatMap { String(data: $0, encoding: .utf8) },
            description: metadata.description
        )
    }

    private func titleUsingPublicAPI(
        for query: PackageTitleQuery,
        repository: String
    ) async throws -> PackageNameEvidence {
        let metadataURL = URL(string: "https://api.github.com/repos/\(repository)")!
        let (metadataData, _) = try await request(metadataURL, accept: "application/vnd.github+json")
        let metadata = try JSONDecoder().decode(RepositoryMetadata.self, from: metadataData)
        let revision = query.revision ?? metadata.defaultBranch
        var components = URLComponents(string: "https://api.github.com/repos/\(repository)/readme")!
        components.queryItems = [URLQueryItem(name: "ref", value: revision)]
        let readme = try? await request(
            components.url!,
            accept: "application/vnd.github.raw+json"
        ).0
        return makeEvidence(
            query: query,
            repository: repository,
            revision: revision,
            readme: readme.flatMap { String(data: $0, encoding: .utf8) },
            description: metadata.description
        )
    }

    private func localTitle(for query: PackageTitleQuery) throws -> PackageNameEvidence {
        let root = query.sourceURL.standardizedFileURL
        let readmeURL = ["README.md", "Readme.md", "readme.md"]
            .map { root.appending(path: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
        let readme = readmeURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        let title = meaningfulH1(in: readme) ?? humanized(root.lastPathComponent)
        return PackageNameEvidence(
            id: "repository-title::\(query.packageID.rawValue)::\(query.revision ?? "working-tree")",
            packageID: query.packageID,
            title: title,
            kind: readme == nil ? "repository-slug" : "readme-h1",
            repositoryURL: query.sourceURL,
            revision: query.revision,
            confidence: .verified
        )
    }

    private func makeEvidence(
        query: PackageTitleQuery,
        repository: String,
        revision: String,
        readme: String?,
        description: String?
    ) -> PackageNameEvidence {
        let readmeTitle = meaningfulH1(in: readme)
        let descriptionTitle = meaningfulDescription(description)
        let slug = repository.split(separator: "/").last.map(String.init) ?? repository
        let title = readmeTitle ?? descriptionTitle ?? humanized(slug)
        let kind = readmeTitle == nil ? (descriptionTitle == nil ? "repository-slug" : "repository-description") : "readme-h1"
        return PackageNameEvidence(
            id: "repository-title::\(query.packageID.rawValue)::\(revision)",
            packageID: query.packageID,
            title: title,
            kind: kind,
            repositoryURL: query.sourceURL,
            revision: revision,
            confidence: .verified
        )
    }

    private func meaningfulH1(in markdown: String?) -> String? {
        guard let markdown else { return nil }
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let value = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.hasPrefix("# ") else { continue }
            let title = sanitized(String(value.dropFirst(2)))
            if !title.isEmpty, !["skills", "plugin", "package", "tools"].contains(title.lowercased()) {
                return title
            }
        }
        return nil
    }

    private func meaningfulDescription(_ value: String?) -> String? {
        guard let value else { return nil }
        let first = value.split(whereSeparator: { ".!?".contains($0) }).first.map(String.init) ?? value
        let title = sanitized(first)
        return title.isEmpty ? nil : title
    }

    private func sanitized(_ value: String) -> String {
        let plain = value
            .replacingOccurrences(of: #"!\[[^\]]*\]\([^\)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\[[^\]]+\]\([^\)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(plain.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func humanized(_ value: String) -> String {
        value.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
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
        guard (200..<300).contains(http.statusCode) else {
            throw SourceDiscoveryError.unavailable("GitHub metadata failed with status \(http.statusCode).")
        }
        return (data, http)
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

    private static var ghURL: URL? {
        ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
            .first(where: FileManager.default.isExecutableFile(atPath:))
            .map { URL(filePath: $0) }
    }
}
