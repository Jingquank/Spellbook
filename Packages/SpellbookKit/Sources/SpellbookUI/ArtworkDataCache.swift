import Foundation
import SpellbookCore
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

actor ArtworkDataCache {
    static let shared = ArtworkDataCache()

    private let maximumEntryBytes: Int
    private let maximumMemoryBytes: Int
    private let maximumMemoryEntries: Int
    private var values = [String: Data]()
    private var recency = [String]()
    private var totalMemoryBytes = 0
    private let cacheRoot: URL

    init(
        maximumEntryBytes: Int = 5 * 1_024 * 1_024,
        maximumMemoryBytes: Int = 20 * 1_024 * 1_024,
        maximumMemoryEntries: Int = 64,
        cacheRoot: URL? = nil
    ) {
        self.maximumEntryBytes = max(1, maximumEntryBytes)
        self.maximumMemoryBytes = max(1, maximumMemoryBytes)
        self.maximumMemoryEntries = max(1, maximumMemoryEntries)
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.cacheRoot = cacheRoot
            ?? base.appending(path: "Spellbook/Artwork", directoryHint: .isDirectory)
    }

    func data(for reference: ArtworkReference) async -> Data? {
        if let cached = cachedData(for: reference.id) { return cached }
        if let contentHash = reference.contentHash {
            let diskURL = cacheRoot.appending(path: contentHash, directoryHint: .notDirectory)
            if let diskData = try? Data(contentsOf: diskURL), digest(diskData) == contentHash {
                insert(diskData, for: reference.id)
                return diskData
            }
        } else {
            let referenceKey = digest(Data(reference.id.utf8))
            let indexURL = cacheRoot.appending(path: "References/\(referenceKey)")
            if
                let hash = try? String(contentsOf: indexURL, encoding: .utf8),
                let diskData = try? Data(contentsOf: cacheRoot.appending(path: hash)),
                digest(diskData) == hash
            {
                insert(diskData, for: reference.id)
                return diskData
            }
        }
        let data: Data?
        if let localURL = reference.localURL {
            data = try? Data(contentsOf: localURL, options: .mappedIfSafe)
        } else if let remoteURL = reference.remoteURL {
            data = await remoteData(from: remoteURL)
        } else {
            data = nil
        }
        guard
            let data,
            !data.isEmpty,
            data.count <= maximumEntryBytes,
            isSafe(data, pathExtension: reference.declaredPath.pathExtension)
        else { return nil }
        let computedHash = digest(data)
        if let expectedHash = reference.contentHash, expectedHash != computedHash { return nil }
        insert(data, for: reference.id)
        if reference.remoteURL != nil {
            try? FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
            try? data.write(
                to: cacheRoot.appending(path: computedHash, directoryHint: .notDirectory),
                options: .atomic
            )
            let references = cacheRoot.appending(path: "References", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: references, withIntermediateDirectories: true)
            let referenceKey = digest(Data(reference.id.utf8))
            try? Data(computedHash.utf8).write(
                to: references.appending(path: referenceKey),
                options: .atomic
            )
        }
        return data
    }

    func storeUploadData(_ data: Data, suggestedExtension: String) throws -> (url: URL, hash: String) {
        guard !data.isEmpty, data.count <= maximumEntryBytes else { throw ArtworkUploadError.invalidImage }
        let suggestedExtension = suggestedExtension.lowercased()
        let normalized: (data: Data, ext: String)
        if suggestedExtension == "heic" || suggestedExtension == "heif" {
            normalized = (try normalizeHEICToPNG(data), "png")
        } else {
            normalized = (data, suggestedExtension)
        }
        guard normalized.data.count <= maximumEntryBytes,
              isSafe(normalized.data, pathExtension: normalized.ext)
        else { throw ArtworkUploadError.invalidImage }
        let hash = digest(normalized.data)
        let galleryRoot = cacheRoot.appending(path: "Gallery", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: galleryRoot, withIntermediateDirectories: true)
        let url = galleryRoot.appending(path: "\(hash).\(normalized.ext)", directoryHint: .notDirectory)
        if !FileManager.default.fileExists(atPath: url.path) {
            try normalized.data.write(to: url, options: .atomic)
        }
        return (url, hash)
    }

    func removeStoredUpload(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        values.removeAll()
        recency.removeAll()
        totalMemoryBytes = 0
    }

    private func cachedData(for key: String) -> Data? {
        guard let data = values[key] else { return nil }
        recency.removeAll { $0 == key }
        recency.append(key)
        return data
    }

    private func insert(_ data: Data, for key: String) {
        if let previous = values.updateValue(data, forKey: key) {
            totalMemoryBytes -= previous.count
        }
        totalMemoryBytes += data.count
        recency.removeAll { $0 == key }
        recency.append(key)

        while values.count > maximumMemoryEntries || totalMemoryBytes > maximumMemoryBytes {
            guard let oldest = recency.first else { break }
            recency.removeFirst()
            if let removed = values.removeValue(forKey: oldest) {
                totalMemoryBytes -= removed.count
            }
        }
    }

    private func normalizeHEICToPNG(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1_024,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary)
        else { throw ArtworkUploadError.invalidImage }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { throw ArtworkUploadError.invalidImage }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ArtworkUploadError.invalidImage }
        return output as Data
    }

    private func remoteData(from url: URL) async -> Data? {
        guard url.scheme?.lowercased() == "https" else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        guard let (bytes, response) = try? await URLSession.shared.bytes(for: request) else { return nil }
        guard let http = response as? HTTPURLResponse,
              http.url?.scheme?.lowercased() == "https",
              (200..<300).contains(http.statusCode)
        else { return nil }
        guard response.expectedContentLength <= Int64(maximumEntryBytes)
                || response.expectedContentLength == NSURLSessionTransferSizeUnknown
        else { return nil }

        var data = Data()
        if response.expectedContentLength > 0 {
            data.reserveCapacity(Int(response.expectedContentLength))
        }
        do {
            for try await byte in bytes {
                guard data.count < maximumEntryBytes else { return nil }
                data.append(byte)
            }
            return data.isEmpty ? nil : data
        } catch {
            return nil
        }
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func isSafe(_ data: Data, pathExtension: String) -> Bool {
        let ext = pathExtension.lowercased()
        switch ext {
        case "png": return data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        case "jpg", "jpeg": return data.starts(with: [0xFF, 0xD8, 0xFF])
        case "webp":
            return data.count >= 12
                && String(data: data.prefix(4), encoding: .ascii) == "RIFF"
                && String(data: data.dropFirst(8).prefix(4), encoding: .ascii) == "WEBP"
        case "icns": return String(data: data.prefix(4), encoding: .ascii) == "icns"
        case "svg":
            guard let text = String(data: data, encoding: .utf8) else { return false }
            let lowered = text.lowercased()
            return lowered.contains("<svg")
                && !lowered.contains("<script")
                && !lowered.contains("javascript:")
                && !lowered.contains("href=\"http")
                && !lowered.contains("href='http")
                && !lowered.contains("xlink:href=\"http")
        default: return false
        }
    }
}

enum ArtworkUploadError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        "Choose a valid PNG, JPEG, HEIC, WebP, SVG, or ICNS file under 5 MB."
    }
}

private extension String {
    var pathExtension: String { (self as NSString).pathExtension }
}
