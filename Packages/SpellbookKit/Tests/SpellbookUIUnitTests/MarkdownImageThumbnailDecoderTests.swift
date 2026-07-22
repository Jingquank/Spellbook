import AppKit
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import SpellbookUI

@Suite("Markdown image thumbnails")
struct MarkdownImageThumbnailDecoderTests {
    @Test("Large local images are decoded to the reader display budget")
    func downsamplesLargeImage() throws {
        let sourceURL = FileManager.default.temporaryDirectory
            .appending(path: "spellbook-markdown-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        try makeFixture(width: 1_600, height: 1_200).write(to: sourceURL)

        let data = try #require(MarkdownImageThumbnailDecoder.thumbnailData(at: sourceURL))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)

        #expect(max(width, height) <= MarkdownImageThumbnailDecoder.maximumPixelSize)
    }

    private func makeFixture(width: Int, height: Int) throws -> Data {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(NSColor.systemIndigo.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }
}
