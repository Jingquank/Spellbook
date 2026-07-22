import AppKit
import ImageIO
import SpellbookCore
import UniformTypeIdentifiers
import XCTest
@testable import SpellbookUI

final class ArtworkDataCacheTests: XCTestCase {
    func testEvictsLeastRecentlyUsedMemoryEntry() async throws {
        let cacheRoot = FileManager.default.temporaryDirectory
            .appending(path: "spellbook-artwork-cache-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: cacheRoot) }

        let firstURL = cacheRoot.appending(path: "first.png")
        let secondURL = cacheRoot.appending(path: "second.png")
        let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let firstData = Data(pngHeader + [0x01])
        let secondData = Data(pngHeader + [0x02])
        try firstData.write(to: firstURL)
        try secondData.write(to: secondURL)

        let cache = ArtworkDataCache(
            maximumEntryBytes: 1_024,
            maximumMemoryBytes: 1_024,
            maximumMemoryEntries: 1,
            cacheRoot: cacheRoot.appending(path: "memory-test", directoryHint: .isDirectory)
        )
        let firstReference = ArtworkReference(
            scope: .package,
            declaredPath: firstURL.lastPathComponent,
            localURL: firstURL,
            confidence: .verified
        )
        let secondReference = ArtworkReference(
            scope: .package,
            declaredPath: secondURL.lastPathComponent,
            localURL: secondURL,
            confidence: .verified
        )

        let firstLoad = await cache.data(for: firstReference)
        XCTAssertEqual(firstLoad, firstData)
        try FileManager.default.removeItem(at: firstURL)

        let secondLoad = await cache.data(for: secondReference)
        XCTAssertEqual(secondLoad, secondData)
        try FileManager.default.removeItem(at: secondURL)

        let evictedReload = await cache.data(for: firstReference)
        let retainedReload = await cache.data(for: secondReference)
        XCTAssertNil(evictedReload)
        XCTAssertEqual(retainedReload, secondData)
    }

    func testAcceptsHEICUploadByNormalizingItToPNG() async throws {
        let data = try makeHEICFixture()

        let stored = try await ArtworkDataCache.shared.storeUploadData(
            data,
            suggestedExtension: "heic"
        )

        XCTAssertEqual(stored.url.pathExtension, "png")
        XCTAssertTrue(try Data(contentsOf: stored.url).starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    private func makeHEICFixture() throws -> Data {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 2,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let green = NSColor(deviceRed: 0.2, green: 0.8, blue: 0.5, alpha: 1)
        for x in 0..<2 { for y in 0..<2 { bitmap.setColor(green, atX: x, y: y) } }
        guard let image = bitmap.cgImage else { throw FixtureError.couldNotCreateImage }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else { throw FixtureError.couldNotCreateDestination }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw FixtureError.couldNotEncode }
        return output as Data
    }

    private enum FixtureError: Error {
        case couldNotCreateImage
        case couldNotCreateDestination
        case couldNotEncode
    }
}
