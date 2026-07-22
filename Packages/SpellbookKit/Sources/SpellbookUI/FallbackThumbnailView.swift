import SpellbookCore
import SwiftUI

struct FallbackThumbnailView: View {
    let category: PackageArtworkCategory
    let paletteIndex: Int
    let styleIndex: Int
    let size: Double

    var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: false) { context, canvasSize in
            let bounds = CGRect(origin: .zero, size: canvasSize)
            renderer.draw(context: &context, bounds: bounds)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var renderer: FallbackThumbnailRenderer {
        FallbackThumbnailRenderer(
            composition: FallbackThumbnailComposition(index: styleIndex),
            palette: FallbackThumbnailPalette(index: paletteIndex),
            seed: paletteIndex &* 31 &+ styleIndex &* 7 &+ categoryIndex
        )
    }

    private var categoryIndex: Int {
        PackageArtworkCategory.allCases.firstIndex(of: category) ?? 0
    }
}
