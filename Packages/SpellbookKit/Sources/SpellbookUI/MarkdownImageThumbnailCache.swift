import Foundation
import ImageIO
import UniformTypeIdentifiers

actor MarkdownImageThumbnailCache {
    static let shared = MarkdownImageThumbnailCache()

    private let maximumBytes = 16 * 1_024 * 1_024
    private let maximumEntries = 32
    private var entries = [String: Data]()
    private var recency = [String]()
    private var totalBytes = 0

    func data(for key: String) -> Data? {
        guard let data = entries[key] else { return nil }
        recency.removeAll { $0 == key }
        recency.append(key)
        return data
    }

    func insert(_ data: Data, for key: String) {
        guard data.count <= maximumBytes else { return }
        if let old = entries.updateValue(data, forKey: key) {
            totalBytes -= old.count
        }
        totalBytes += data.count
        recency.removeAll { $0 == key }
        recency.append(key)
        while entries.count > maximumEntries || totalBytes > maximumBytes {
            guard let oldest = recency.first else { break }
            recency.removeFirst()
            if let removed = entries.removeValue(forKey: oldest) {
                totalBytes -= removed.count
            }
        }
    }
}

enum MarkdownImageThumbnailDecoder {
    static let maximumSourceBytes = 25_000_000
    static let maximumPixelSize = 1_040

    nonisolated static func thumbnailData(at url: URL) -> Data? {
        guard
            let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
            (values.fileSize ?? 0) <= maximumSourceBytes,
            let source = CGImageSourceCreateWithURL(url as CFURL, [
                kCGImageSourceShouldCache: false
            ] as CFDictionary)
        else { return nil }
        return thumbnailData(from: source)
    }

    nonisolated static func thumbnailData(from data: Data) -> Data? {
        guard data.count <= maximumSourceBytes,
              let source = CGImageSourceCreateWithData(data as CFData, [
                  kCGImageSourceShouldCache: false
              ] as CFDictionary)
        else { return nil }
        return thumbnailData(from: source)
    }

    private nonisolated static func thumbnailData(from source: CGImageSource) -> Data? {
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary)
        else { return nil }

        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

enum MarkdownRemoteImageLoader {
    nonisolated static func data(from url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                return nil
            }
            guard response.expectedContentLength <= Int64(MarkdownImageThumbnailDecoder.maximumSourceBytes)
                    || response.expectedContentLength == NSURLSessionTransferSizeUnknown
            else { return nil }
            var data = Data()
            if response.expectedContentLength > 0 {
                data.reserveCapacity(Int(response.expectedContentLength))
            }
            for try await byte in bytes {
                guard data.count < MarkdownImageThumbnailDecoder.maximumSourceBytes else { return nil }
                data.append(byte)
            }
            return data.isEmpty ? nil : data
        } catch {
            return nil
        }
    }
}
