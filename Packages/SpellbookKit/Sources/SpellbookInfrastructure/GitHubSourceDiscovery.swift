import Foundation
import SpellbookCore

public actor GitHubSourceDiscovery: SourceDiscovering {
    private struct RepositoryResult: Decodable {
        let nameWithOwner: String
        let url: URL
        let description: String?

        enum CodingKeys: String, CodingKey {
            case nameWithOwner = "fullName"
            case url
            case description
        }
    }

    private struct RESTResponse: Decodable {
        struct Item: Decodable {
            let fullName: String
            let htmlURL: URL
            let description: String?

            enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
                case htmlURL = "html_url"
                case description
            }
        }
        let items: [Item]
    }

    private var responseCache = [String: (expiresAt: Date, candidates: [SourceCandidate])]()

    public init() {}

    public func findCandidates(for query: SourceDiscoveryQuery) async throws -> [SourceCandidate] {
        let search = metadataQuery(query)
        if let cached = responseCache[search], cached.expiresAt > .now {
            return cached.candidates
        }

        let results: [RepositoryResult]
        if Self.ghURL != nil, (try? runGH(["auth", "status"])) != nil {
            results = try runGHRepositorySearch(search)
        } else {
            results = try await runPublicRepositorySearch(search)
        }
        let candidates = results.map { result in
            candidate(from: result, query: query, deepSearch: false)
        }
        responseCache[search] = (.now.addingTimeInterval(300), candidates)
        return candidates
    }

    public func deepSearchCandidates(for query: SourceDiscoveryQuery) async throws -> [SourceCandidate] {
        guard Self.ghURL != nil else {
            throw SourceDiscoveryError.unavailable(
                "Deep code search needs GitHub CLI. Install gh and sign in, then try again."
            )
        }
        _ = try runGH(["auth", "status"])
        let terms = ([query.packageName] + query.skillNames + query.filenames)
            .filter { !$0.isEmpty }
            .prefix(4)
        var repositories = [String: RepositoryResult]()
        for term in terms {
            try Task.checkCancellation()
            let data = try runGH([
                "search", "code", term,
                "--filename", "SKILL.md",
                "--json", "repository,path",
                "--limit", "20"
            ])
            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                continue
            }
            for row in rows {
                guard
                    let repository = row["repository"] as? [String: Any],
                    let nameWithOwner = repository["fullName"] as? String,
                    let url = URL(string: "https://github.com/\(nameWithOwner)")
                else { continue }
                repositories[nameWithOwner] = RepositoryResult(
                    nameWithOwner: nameWithOwner,
                    url: url,
                    description: "Contains a matching SKILL.md result."
                )
            }
        }
        return repositories.values.map { candidate(from: $0, query: query, deepSearch: true) }
            .sorted { $0.confidence > $1.confidence }
    }

    private func metadataQuery(_ query: SourceDiscoveryQuery) -> String {
        var terms = [query.packageName]
        if let author = query.author, !author.isEmpty { terms.append(author) }
        if let skill = query.skillNames.first, skill.caseInsensitiveCompare(query.packageName) != .orderedSame {
            terms.append(skill)
        }
        return terms.map { $0.replacingOccurrences(of: "\"", with: "") }.joined(separator: " ")
    }

    private func candidate(
        from result: RepositoryResult,
        query: SourceDiscoveryQuery,
        deepSearch: Bool
    ) -> SourceCandidate {
        let repositoryName = result.nameWithOwner.split(separator: "/").last.map(String.init) ?? ""
        let normalizedRepo = normalize(repositoryName)
        let normalizedPackage = normalize(query.packageName)
        let exactName = normalizedRepo == normalizedPackage
        let authorMatch = query.author.map { normalize(result.nameWithOwner).contains(normalize($0)) } ?? false
        let confidence: ProvenanceConfidence = exactName && (authorMatch || deepSearch) ? .likely : .possible
        let explanation = if exactName && deepSearch {
            "Repository name matches and GitHub code search found a SKILL.md result."
        } else if exactName {
            "Repository name matches the package. Verify its tree and content before connecting."
        } else if deepSearch {
            "GitHub code search found matching skill metadata. Verify before connecting."
        } else {
            result.description ?? "GitHub metadata resembles this package. Verify before connecting."
        }
        return SourceCandidate(
            id: "github::\(query.packageID.rawValue)::\(result.nameWithOwner.lowercased())",
            packageID: query.packageID,
            sourceURL: result.url,
            confidence: confidence,
            explanation: explanation
        )
    }

    private func runGHRepositorySearch(_ query: String) throws -> [RepositoryResult] {
        let data = try runGH([
            "search", "repos", query,
            "--json", "fullName,url,description",
            "--limit", "12"
        ])
        return try JSONDecoder().decode([RepositoryResult].self, from: data)
    }

    private func runPublicRepositorySearch(_ query: String) async throws -> [RepositoryResult] {
        var components = URLComponents(string: "https://api.github.com/search/repositories")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "per_page", value: "12")
        ]
        guard let url = components?.url else { throw SourceDiscoveryError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Spellbook/1.0", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .returnCacheDataElseLoad
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SourceDiscoveryError.invalidResponse }
        if http.statusCode == 403 || http.statusCode == 429 {
            let reset = http.value(forHTTPHeaderField: "X-RateLimit-Reset")
                .flatMap(TimeInterval.init)
                .map(Date.init(timeIntervalSince1970:))
            throw SourceDiscoveryError.rateLimited(resetAt: reset)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SourceDiscoveryError.unavailable("GitHub search failed with status \(http.statusCode).")
        }
        let decoded = try JSONDecoder().decode(RESTResponse.self, from: data)
        return decoded.items.map {
            RepositoryResult(nameWithOwner: $0.fullName, url: $0.htmlURL, description: $0.description)
        }
    }

    private func runGH(_ arguments: [String]) throws -> Data {
        guard let ghURL = Self.ghURL else {
            throw SourceDiscoveryError.unavailable("GitHub CLI is not installed.")
        }
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
            let message = String(
                data: errors.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw SourceDiscoveryError.unavailable(message?.isEmpty == false ? message! : "GitHub CLI failed.")
        }
        return data
    }

    private func normalize(_ value: String) -> String {
        value.lowercased().filter(\.isLetter)
    }

    private static var ghURL: URL? {
        ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
            .first(where: FileManager.default.isExecutableFile(atPath:))
            .map { URL(filePath: $0) }
    }
}
