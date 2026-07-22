import AppKit
import SpellbookMarkdown
import SwiftUI

struct MarkdownImageView: View {
    @Environment(\.markdownAssetRootURL) private var assetRootURL

    let source: String?
    let altText: String
    let title: String?

    @State private var image: NSImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image {
                rendered(Image(nsImage: image))
            } else if loadFailed || source == nil {
                placeholder
            } else {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Loading \(accessibleName)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: imageTaskID) {
            await loadImage()
        }
    }

    private func rendered(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 520)
            .accessibilityLabel(accessibleName)
            .help(title ?? accessibleName)
    }

    private var placeholder: some View {
        Label("\(accessibleName) unavailable", systemImage: "photo.badge.exclamationmark")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(10)
            .background(.quaternary, in: .rect(cornerRadius: 8))
            .accessibilityLabel("Image unavailable: \(accessibleName)")
    }

    private var accessibleName: String {
        let trimmed = altText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (title ?? "Skill image") : trimmed
    }

    private var remoteURL: URL? {
        guard
            let source,
            let url = URL(string: source),
            let scheme = url.scheme?.lowercased(),
            scheme == "https" || scheme == "http"
        else { return nil }
        return url
    }

    private var imageTaskID: String {
        if let remoteURL { return "remote::\(remoteURL.absoluteString)" }
        guard let resolvedLocalURL else {
            return "\(assetRootURL?.path ?? "")::\(source ?? "")"
        }
        let values = try? resolvedLocalURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        return [
            resolvedLocalURL.path,
            values?.contentModificationDate?.timeIntervalSinceReferenceDate.description ?? "unknown-date",
            values?.fileSize?.description ?? "unknown-size"
        ].joined(separator: "::")
    }

    private func loadImage() async {
        image = nil
        loadFailed = false
        if let remoteURL {
            await loadRemoteImage(from: remoteURL)
            return
        }
        guard let localURL = resolvedLocalURL else {
            loadFailed = true
            return
        }
        let cacheKey = imageTaskID
        if let data = await MarkdownImageThumbnailCache.shared.data(for: cacheKey),
           let cachedImage = NSImage(data: data) {
            image = cachedImage
            return
        }
        let data = await Task.detached(priority: .utility) {
            MarkdownImageThumbnailDecoder.thumbnailData(at: localURL)
        }.value
        guard let data, let decodedImage = NSImage(data: data) else {
            loadFailed = true
            return
        }
        await MarkdownImageThumbnailCache.shared.insert(data, for: cacheKey)
        image = decodedImage
    }

    private func loadRemoteImage(from url: URL) async {
        let cacheKey = imageTaskID
        if let data = await MarkdownImageThumbnailCache.shared.data(for: cacheKey),
           let cachedImage = NSImage(data: data) {
            image = cachedImage
            return
        }
        guard let sourceData = await MarkdownRemoteImageLoader.data(from: url) else {
            loadFailed = true
            return
        }
        let data = await Task.detached(priority: .utility) {
            MarkdownImageThumbnailDecoder.thumbnailData(from: sourceData)
        }.value
        guard let data, let decodedImage = NSImage(data: data) else {
            loadFailed = true
            return
        }
        await MarkdownImageThumbnailCache.shared.insert(data, for: cacheKey)
        image = decodedImage
    }

    private var resolvedLocalURL: URL? {
        guard
            let source,
            !source.isEmpty,
            URL(string: source)?.scheme == nil,
            let assetRootURL
        else { return nil }
        return MarkdownAssetResolver.localAssetURL(
            source: source,
            packageRootURL: assetRootURL
        )
    }
}
