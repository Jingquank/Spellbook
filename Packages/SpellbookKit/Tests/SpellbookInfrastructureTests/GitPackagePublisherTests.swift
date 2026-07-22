import Foundation
import SpellbookCore
import XCTest
@testable import SpellbookInfrastructure

final class GitPackagePublisherTests: XCTestCase {
    func testPreviewsArtworkRequiresNewFileApprovalAndPublishesManifest() async throws {
        let fixture = try TemporarySkillLibrary()
        let remote = fixture.url.appending(path: "personal.git", directoryHint: .isDirectory)
        let seed = fixture.url.appending(path: "seed", directoryHint: .isDirectory)
        try runGit(["init", "--bare", remote.path])
        try FileManager.default.createDirectory(at: seed, withIntermediateDirectories: true)
        try runGit(["-C", seed.path, "init", "-b", "main"])
        try runGit(["-C", seed.path, "config", "user.name", "Test"])
        try runGit(["-C", seed.path, "config", "user.email", "test@example.com"])
        _ = try fixture.write("# Personal Spellbook\n", at: "seed/README.md")
        try runGit(["-C", seed.path, "add", "README.md"])
        try runGit(["-C", seed.path, "commit", "-m", "Initial"])
        try runGit(["-C", seed.path, "remote", "add", "origin", remote.path])
        try runGit(["-C", seed.path, "push", "origin", "main"])

        let skillRoot = try fixture.makeDirectory(at: "installed/example")
        let entry = try fixture.write("# Example\n", at: "installed/example/SKILL.md")
        _ = try fixture.write(
            Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
            at: "installed/example/logo.png"
        )
        let packageID = PackageID(rawValue: "package-example")
        let skillID = SkillID(rawValue: "skill-example")
        let package = SkillPackageRecord(id: packageID, name: "Example", skillIDs: [skillID])
        let skill = SkillRecord(
            id: skillID,
            packageID: packageID,
            name: "Example",
            summary: "",
            markdownSource: "# Example\n",
            installations: [SkillInstallation(
                id: InstallationID(rawValue: "install-example"),
                agent: .codex,
                entryURL: entry,
                rootURL: skillRoot,
                contentHash: StableHasher.sha256(Data("# Example\n".utf8)),
                localState: .clean
            )]
        )
        let publisher = GitPackagePublisher(cacheRoot: fixture.url.appending(path: "publishing-cache"))
        let target = PublishingTarget(repositoryURL: remote, branch: "main")

        let plan = try await publisher.preview(
            package: package,
            skills: [skill],
            agent: .codex,
            target: target
        )
        XCTAssertTrue(plan.changes.contains { $0.relativePath.hasSuffix("logo.png") && $0.isArtwork })
        XCTAssertTrue(plan.changes.contains { $0.relativePath == ".spellbook/manifest.json" })
        do {
            _ = try await publisher.publish(plan, approveNewFiles: false)
            XCTFail("Expected new-file approval to be required")
        } catch PublishingError.newFilesNeedApproval {
            // Expected.
        }

        let receipt = try await publisher.publish(plan, approveNewFiles: true)
        XCTAssertFalse(receipt.commit.isEmpty)
        let manifest = try gitOutput([
            "--git-dir", remote.path,
            "show", "main:.spellbook/manifest.json"
        ])
        XCTAssertTrue(manifest.contains("package-example"))
    }

    private func runGit(_ arguments: [String]) throws {
        _ = try gitOutput(arguments)
    }

    private func gitOutput(_ arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "GitPackagePublisherTests",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: String(
                    data: errors.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? "Git failed"]
            )
        }
        return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
