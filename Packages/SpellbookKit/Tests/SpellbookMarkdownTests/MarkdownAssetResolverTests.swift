import Foundation
import XCTest
@testable import SpellbookMarkdown

final class MarkdownAssetResolverTests: XCTestCase {
    func testAllowsRelativeAssetsButRejectsTraversalAndEscapingSymlinks() throws {
        let fixtureRoot = FileManager.default.temporaryDirectory
            .appending(path: "SpellbookAssetTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let packageRoot = fixtureRoot.appending(path: "package", directoryHint: .isDirectory)
        let imageURL = packageRoot.appending(path: "images/cover.png")
        let outsideURL = fixtureRoot.appending(path: "private.png")
        try FileManager.default.createDirectory(
            at: imageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([0]).write(to: imageURL)
        try Data([1]).write(to: outsideURL)
        let symlinkURL = packageRoot.appending(path: "images/escape.png")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: outsideURL)
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        XCTAssertEqual(
            MarkdownAssetResolver.localAssetURL(
                source: "images/cover.png",
                packageRootURL: packageRoot
            ),
            imageURL.standardizedFileURL.resolvingSymlinksInPath()
        )
        XCTAssertNil(MarkdownAssetResolver.localAssetURL(
            source: "../private.png",
            packageRootURL: packageRoot
        ))
        XCTAssertNil(MarkdownAssetResolver.localAssetURL(
            source: "images/escape.png",
            packageRootURL: packageRoot
        ))
        XCTAssertNil(MarkdownAssetResolver.localAssetURL(
            source: "file:///tmp/private.png",
            packageRootURL: packageRoot
        ))
    }
}
