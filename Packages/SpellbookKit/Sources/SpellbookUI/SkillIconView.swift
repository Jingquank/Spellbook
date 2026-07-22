import SpellbookCore
import SwiftUI

struct SkillIconView: View {
    let thumbnail: SkillThumbnail
    let size: Double

    init(
        thumbnail: SkillThumbnail,
        size: Double
    ) {
        self.thumbnail = thumbnail
        self.size = size
    }

    var body: some View {
        RepositoryArtworkView(
            artwork: thumbnail.artwork,
            size: size,
            contentMode: thumbnail.contentMode
        ) {
            FallbackThumbnailView(
                category: thumbnail.fallbackCategory,
                paletteIndex: thumbnail.paletteIndex,
                styleIndex: thumbnail.fallbackStyleIndex,
                size: size
            )
        }
    }
}
