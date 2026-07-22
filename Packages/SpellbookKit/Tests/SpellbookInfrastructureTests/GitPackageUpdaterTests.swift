import Foundation
import SpellbookCore
import XCTest
@testable import SpellbookInfrastructure

final class GitPackageUpdaterTests: XCTestCase {
    func testDetectsTrackedModificationAndAppliesReviewedFastForwardUpdate() async throws {
        let fixture = try TemporarySkillLibrary()
        let repository = fixture.url.appending(path: "installed", directoryHint: .isDirectory)
        let remote = fixture.url.appending(path: "remote.git", directoryHint: .isDirectory)
        let publisher = fixture.url.appending(path: "publisher", directoryHint: .isDirectory)

        try runGit(["init", "--bare", remote.path], in: fixture.url)
        try runGit(["init", "-b", "main", repository.path], in: fixture.url)
        try configureIdentity(in: repository)
        let entry = repository.appending(path: "example/SKILL.md")
        try FileManager.default.createDirectory(
            at: entry.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("# Version 1\n".utf8).write(to: entry)
        try runGit(["add", "."], in: repository)
        try runGit(["commit", "-m", "Initial"], in: repository)
        try runGit(["remote", "add", "origin", remote.path], in: repository)
        try runGit(["push", "-u", "origin", "main"], in: repository)
        try runGit(["symbolic-ref", "HEAD", "refs/heads/main"], in: remote)

        var snapshot = try await scan(root: repository)
        XCTAssertEqual(snapshot.skills.first?.installations.first?.localState, .clean)

        try Data("# Local edit\n".utf8).write(to: entry)
        snapshot = try await scan(root: repository)
        XCTAssertEqual(snapshot.skills.first?.installations.first?.localState, .modified)
        try Data("# Version 1\n".utf8).write(to: entry)

        try runGit(["clone", remote.path, publisher.path], in: fixture.url)
        try configureIdentity(in: publisher)
        let publishedEntry = publisher.appending(path: "example/SKILL.md")
        try Data("# Version 2\n".utf8).write(to: publishedEntry)
        try runGit(["add", "."], in: publisher)
        try runGit(["commit", "-m", "Update"], in: publisher)
        try runGit(["push", "origin", "main"], in: publisher)

        snapshot = try await scan(root: repository)
        let updater = GitPackageUpdater()
        let updates = try await updater.check(snapshot: snapshot)
        let update = try XCTUnwrap(updates.first)
        XCTAssertEqual(updates.count, 1)
        XCTAssertTrue(update.canApply)

        let receipt = try await updater.apply(update)

        XCTAssertNotEqual(receipt.previousRevision, receipt.resultingRevision)
        XCTAssertEqual(try String(contentsOf: entry, encoding: .utf8), "# Version 2\n")
    }

    private func scan(root: URL) async throws -> LibrarySnapshot {
        let scanner = FileSystemSkillScanner(roots: [
            SkillDiscoveryRoot(agent: .codex, url: root)
        ])
        var latest = LibrarySnapshot.empty
        for try await update in scanner.scan() {
            switch update {
            case .progress(let snapshot, _), .finished(let snapshot, _):
                latest = snapshot
            }
        }
        return latest
    }

    private func configureIdentity(in repository: URL) throws {
        try runGit(["config", "user.email", "spellbook@example.com"], in: repository)
        try runGit(["config", "user.name", "Spellbook Tests"], in: repository)
    }

    private func runGit(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.currentDirectoryURL = directory
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe
        try process.run()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? "Git command failed"
            throw NSError(domain: "GitPackageUpdaterTests", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: message
            ])
        }
    }
}
