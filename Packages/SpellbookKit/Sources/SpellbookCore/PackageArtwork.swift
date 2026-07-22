import Foundation

public enum PackageArtworkCategory: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case designUI
    case frontend
    case appleDevelopment
    case backendAPI
    case testingQA
    case debugging
    case codeReview
    case refactoringArchitecture
    case gitDevOps
    case securityPrivacy
    case dataSpreadsheets
    case documents
    case researchAnalysis
    case writingEditing
    case productPlanning
    case projectManagement
    case automationAgents
    case browserWeb
    case imagesGraphics
    case videoMotion
    case communication
    case knowledgeNotes
    case learningTeaching
    case generalUtility

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .designUI: "Design & UI"
        case .frontend: "Frontend"
        case .appleDevelopment: "Apple Development"
        case .backendAPI: "Backend & APIs"
        case .testingQA: "Testing & QA"
        case .debugging: "Debugging"
        case .codeReview: "Code Review"
        case .refactoringArchitecture: "Refactoring & Architecture"
        case .gitDevOps: "Git & DevOps"
        case .securityPrivacy: "Security & Privacy"
        case .dataSpreadsheets: "Data & Spreadsheets"
        case .documents: "Documents"
        case .researchAnalysis: "Research & Analysis"
        case .writingEditing: "Writing & Editing"
        case .productPlanning: "Product & Planning"
        case .projectManagement: "Project Management"
        case .automationAgents: "Automation & Agents"
        case .browserWeb: "Browser & Web"
        case .imagesGraphics: "Images & Graphics"
        case .videoMotion: "Video & Motion"
        case .communication: "Communication"
        case .knowledgeNotes: "Knowledge & Notes"
        case .learningTeaching: "Learning & Teaching"
        case .generalUtility: "General Utility"
        }
    }

    public static func infer(
        package: SkillPackageRecord,
        skills: [SkillRecord]
    ) -> PackageArtworkCategory {
        let title = package.name.lowercased()
        let names = skills.map(\.name).joined(separator: " ").lowercased()
        let prose = skills.map { "\($0.summary) \($0.markdownSource.prefix(800))" }
            .joined(separator: " ").lowercased()
        var scores = [PackageArtworkCategory: Int]()
        for (category, keywords) in keywordMap {
            for keyword in keywords {
                if title.contains(keyword) { scores[category, default: 0] += 5 }
                if names.contains(keyword) { scores[category, default: 0] += 3 }
                if prose.contains(keyword) { scores[category, default: 0] += 1 }
            }
        }
        let ranked = scores.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key.rawValue < $1.key.rawValue
        }
        guard let first = ranked.first, first.value >= 3 else { return .generalUtility }
        if ranked.count > 1, first.value - ranked[1].value < 2 { return .generalUtility }
        return first.key
    }

    private static let keywordMap: [PackageArtworkCategory: [String]] = [
        .designUI: ["design", "interface", "ui", "ux", "layout", "typography", "color"],
        .frontend: ["frontend", "react", "css", "html", "web component", "responsive"],
        .appleDevelopment: ["swift", "swiftui", "xcode", "ios", "macos", "apple"],
        .backendAPI: ["backend", "api", "server", "database", "endpoint", "graphql"],
        .testingQA: ["test", "qa", "tdd", "spec", "coverage", "assert"],
        .debugging: ["debug", "diagnos", "trace", "xray", "inspect", "failure"],
        .codeReview: ["code review", "review code", "pull request", "lint", "quality"],
        .refactoringArchitecture: ["refactor", "architecture", "module", "migration", "codebase"],
        .gitDevOps: ["git", "github", "deploy", "devops", "commit", "merge", "ci"],
        .securityPrivacy: ["security", "privacy", "password", "credential", "permission", "auth"],
        .dataSpreadsheets: ["data", "spreadsheet", "excel", "xlsx", "csv", "sheets"],
        .documents: ["document", "docx", "pdf", "pptx", "slides", "presentation"],
        .researchAnalysis: ["research", "analysis", "investigate", "evidence", "study"],
        .writingEditing: ["writing", "writer", "edit", "article", "prose", "copy"],
        .productPlanning: ["product", "plan", "roadmap", "scope", "strategy", "requirements"],
        .projectManagement: ["project", "ticket", "triage", "handoff", "task", "workflow"],
        .automationAgents: ["agent", "automation", "mcp", "routine", "workflow", "skill"],
        .browserWeb: ["browser", "chrome", "website", "web search", "playwright", "aside"],
        .imagesGraphics: ["image", "graphic", "artwork", "figma", "visual", "illustration"],
        .videoMotion: ["video", "motion", "animation", "remotion", "timeline"],
        .communication: ["communication", "slack", "gmail", "email", "message", "notification"],
        .knowledgeNotes: ["knowledge", "notes", "notion", "obsidian", "memory", "vault"],
        .learningTeaching: ["learn", "teach", "tutorial", "exercise", "explain", "onboard"],
        .generalUtility: []
    ]
}

public enum PackageArtworkSourceKind: String, Codable, CaseIterable, Hashable, Sendable {
    case userUpload
    case packageIcon
    case skillIcon
    case githubSocialPreview
    case githubOrganizationAvatar
    case readmeImage
    case githubOwnerAvatar
    case generatedFallback

    public var displayName: String {
        switch self {
        case .userUpload: "User upload"
        case .packageIcon: "Package icon"
        case .skillIcon: "Skill icon"
        case .githubSocialPreview: "GitHub social preview"
        case .githubOrganizationAvatar: "GitHub organization"
        case .readmeImage: "README image"
        case .githubOwnerAvatar: "GitHub owner"
        case .generatedFallback: "Generated artwork"
        }
    }
}

public enum ArtworkContentMode: String, Codable, Hashable, Sendable {
    case fit
    case fill
}

public struct PackageArtworkEvidence: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let packageID: PackageID
    public let sourceKind: PackageArtworkSourceKind
    public let artwork: ArtworkReference
    public let contentMode: ArtworkContentMode
    public let repositoryURL: URL?
    public let revision: String?
    public let observedAt: Date

    public init(
        id: String? = nil,
        packageID: PackageID,
        sourceKind: PackageArtworkSourceKind,
        artwork: ArtworkReference,
        contentMode: ArtworkContentMode = .fill,
        repositoryURL: URL? = nil,
        revision: String? = nil,
        observedAt: Date = .now
    ) {
        self.id = id ?? "\(packageID.rawValue)::\(sourceKind.rawValue)::\(revision ?? "working-tree")"
        self.packageID = packageID
        self.sourceKind = sourceKind
        self.artwork = artwork
        self.contentMode = contentMode
        self.repositoryURL = repositoryURL
        self.revision = revision
        self.observedAt = observedAt
    }
}

public struct PackageArtworkUpload: Identifiable, Hashable, Codable, Sendable {
    public var id: String { packageID.rawValue }
    public let packageID: PackageID
    public let localURL: URL
    public let contentHash: String
    public let createdAt: Date

    public init(
        packageID: PackageID,
        localURL: URL,
        contentHash: String,
        createdAt: Date = .now
    ) {
        self.packageID = packageID
        self.localURL = localURL
        self.contentHash = contentHash
        self.createdAt = createdAt
    }

    public var artworkReference: ArtworkReference {
        ArtworkReference(
            scope: .package,
            declaredPath: localURL.lastPathComponent,
            localURL: localURL,
            contentHash: contentHash,
            confidence: .verified
        )
    }
}

public struct SkillThumbnail: Hashable, Sendable {
    public let artwork: ArtworkReference?
    public let sourceKind: PackageArtworkSourceKind
    public let contentMode: ArtworkContentMode
    public let fallbackCategory: PackageArtworkCategory
    public let paletteIndex: Int
    public let fallbackStyleIndex: Int

    public init(
        artwork: ArtworkReference?,
        sourceKind: PackageArtworkSourceKind,
        contentMode: ArtworkContentMode,
        fallbackCategory: PackageArtworkCategory,
        paletteIndex: Int,
        fallbackStyleIndex: Int
    ) {
        self.artwork = artwork
        self.sourceKind = sourceKind
        self.contentMode = contentMode
        self.fallbackCategory = fallbackCategory
        self.paletteIndex = paletteIndex
        self.fallbackStyleIndex = fallbackStyleIndex
    }

    public static func fallback(
        packageID: PackageID,
        category: PackageArtworkCategory
    ) -> SkillThumbnail {
        SkillThumbnail(
            artwork: nil,
            sourceKind: .generatedFallback,
            contentMode: .fill,
            fallbackCategory: category,
            paletteIndex: stablePaletteIndex(for: packageID),
            fallbackStyleIndex: stableFallbackStyleIndex(for: packageID)
        )
    }

    public static func stablePaletteIndex(for packageID: PackageID) -> Int {
        Int(packageID.rawValue.utf8.reduce(UInt(0)) { ($0 &* 31) &+ UInt($1) } % 7)
    }

    public static func stableFallbackStyleIndex(for packageID: PackageID) -> Int {
        stableFallbackStyleIndex(for: packageID.rawValue)
    }

    public static func stableFallbackStyleIndex(for skillID: SkillID) -> Int {
        stableFallbackStyleIndex(for: skillID.rawValue)
    }

    private static func stableFallbackStyleIndex(for identifier: String) -> Int {
        let hash = identifier.utf8.reduce(UInt(2_166_136_261)) { hash, byte in
            (hash ^ UInt(byte)) &* 16_777_619
        }
        return Int(hash % 5)
    }
}

public enum SkillThumbnailResolver {
    public static func resolveSkill(
        package: SkillPackageRecord?,
        skill: SkillRecord,
        upload: PackageArtworkUpload?,
        evidence: [PackageArtworkEvidence],
        category: PackageArtworkCategory
    ) -> SkillThumbnail {
        let fallbackStyleIndex = SkillThumbnail.stableFallbackStyleIndex(for: skill.id)
        if let upload { return thumbnail(for: upload, category: category, fallbackStyleIndex: fallbackStyleIndex) }
        if let artwork = package?.artwork {
            return thumbnail(
                artwork,
                source: .packageIcon,
                mode: .fit,
                packageID: skill.packageID,
                category: category,
                fallbackStyleIndex: fallbackStyleIndex
            )
        }
        if let artwork = skill.artwork {
            return thumbnail(
                artwork,
                source: .skillIcon,
                mode: .fit,
                packageID: skill.packageID,
                category: category,
                fallbackStyleIndex: fallbackStyleIndex
            )
        }
        return evidenceThumbnail(
            evidence,
            packageID: skill.packageID,
            category: category,
            fallbackStyleIndex: fallbackStyleIndex
        )
    }

    public static func resolvePackage(
        package: SkillPackageRecord,
        upload: PackageArtworkUpload?,
        evidence: [PackageArtworkEvidence],
        category: PackageArtworkCategory
    ) -> SkillThumbnail {
        let fallbackStyleIndex = SkillThumbnail.stableFallbackStyleIndex(for: package.id)
        if let upload { return thumbnail(for: upload, category: category, fallbackStyleIndex: fallbackStyleIndex) }
        if let artwork = package.artwork {
            return thumbnail(
                artwork,
                source: .packageIcon,
                mode: .fit,
                packageID: package.id,
                category: category,
                fallbackStyleIndex: fallbackStyleIndex
            )
        }
        return evidenceThumbnail(
            evidence,
            packageID: package.id,
            category: category,
            fallbackStyleIndex: fallbackStyleIndex
        )
    }

    private static func evidenceThumbnail(
        _ evidence: [PackageArtworkEvidence],
        packageID: PackageID,
        category: PackageArtworkCategory,
        fallbackStyleIndex: Int
    ) -> SkillThumbnail {
        let ranks: [PackageArtworkSourceKind: Int] = [
            .githubSocialPreview: 0,
            .githubOrganizationAvatar: 1,
            .readmeImage: 2,
            .githubOwnerAvatar: 3
        ]
        let ordered = evidence
            .filter { ranks[$0.sourceKind] != nil }
            .sorted {
                let lhs = ranks[$0.sourceKind] ?? .max
                let rhs = ranks[$1.sourceKind] ?? .max
                if lhs != rhs { return lhs < rhs }
                return $0.id < $1.id
            }
        guard let first = ordered.first else {
            return SkillThumbnail(
                artwork: nil,
                sourceKind: .generatedFallback,
                contentMode: .fill,
                fallbackCategory: category,
                paletteIndex: SkillThumbnail.stablePaletteIndex(for: packageID),
                fallbackStyleIndex: fallbackStyleIndex
            )
        }
        return thumbnail(
            first.artwork,
            source: first.sourceKind,
            mode: first.contentMode,
            packageID: packageID,
            category: category,
            fallbackStyleIndex: fallbackStyleIndex
        )
    }

    private static func thumbnail(
        for upload: PackageArtworkUpload,
        category: PackageArtworkCategory,
        fallbackStyleIndex: Int
    ) -> SkillThumbnail {
        thumbnail(
            upload.artworkReference,
            source: .userUpload,
            mode: .fill,
            packageID: upload.packageID,
            category: category,
            fallbackStyleIndex: fallbackStyleIndex
        )
    }

    private static func thumbnail(
        _ artwork: ArtworkReference,
        source: PackageArtworkSourceKind,
        mode: ArtworkContentMode,
        packageID: PackageID,
        category: PackageArtworkCategory,
        fallbackStyleIndex: Int
    ) -> SkillThumbnail {
        SkillThumbnail(
            artwork: artwork,
            sourceKind: source,
            contentMode: mode,
            fallbackCategory: category,
            paletteIndex: SkillThumbnail.stablePaletteIndex(for: packageID),
            fallbackStyleIndex: fallbackStyleIndex
        )
    }
}
