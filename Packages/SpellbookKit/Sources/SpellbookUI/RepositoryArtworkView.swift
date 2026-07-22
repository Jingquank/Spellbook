import SpellbookCore
import SwiftUI
import ImageIO

struct RepositoryArtworkView<Fallback: View>: View {
    let artwork: ArtworkReference?
    let size: Double
    let contentMode: ArtworkContentMode
    let fallback: Fallback

    @State private var image: NSImage?

    init(
        artwork: ArtworkReference?,
        size: Double,
        contentMode: ArtworkContentMode = .fit,
        @ViewBuilder fallback: () -> Fallback
    ) {
        self.artwork = artwork
        self.size = size
        self.contentMode = contentMode
        self.fallback = fallback()
    }

    var body: some View {
        Group {
            if let image {
                rendered(image)
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: artwork?.id) {
            image = nil
            guard let artwork, let data = await ArtworkDataCache.shared.data(for: artwork) else {
                return
            }
            image = downsampledImage(data)
        }
    }

    @ViewBuilder
    private func rendered(_ image: NSImage) -> some View {
        switch contentMode {
        case .fit:
            Image(nsImage: image)
                .resizable()
                .antialiased(true)
                .scaledToFit()
                .padding(size * 0.08)
                .background(.background.secondary, in: .rect(cornerRadius: size * 0.24))
        case .fill:
            Image(nsImage: image)
                .resizable()
                .antialiased(true)
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.rect(cornerRadius: size * 0.22))
        }
    }

    private func downsampledImage(_ data: Data) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return NSImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: max(48, Int(size * 2)),
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return NSImage(data: data)
        }
        return NSImage(cgImage: image, size: .zero)
    }
}
