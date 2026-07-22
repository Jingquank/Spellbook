import SpellbookCore
import SwiftUI
import XCTest
@testable import SpellbookUI

final class FallbackThumbnailTests: XCTestCase {
    func testCompositionIndexesWrapAcrossFiveApprovedStyles() {
        XCTAssertEqual(FallbackThumbnailComposition.allCases.count, 5)
        XCTAssertEqual(FallbackThumbnailComposition(index: 0), .croppedGeometry)
        XCTAssertEqual(FallbackThumbnailComposition(index: 1), .mosaicTiles)
        XCTAssertEqual(FallbackThumbnailComposition(index: 2), .concentricForms)
        XCTAssertEqual(FallbackThumbnailComposition(index: 3), .radialFan)
        XCTAssertEqual(FallbackThumbnailComposition(index: 4), .wovenStrips)
        XCTAssertEqual(FallbackThumbnailComposition(index: 5), .croppedGeometry)
        XCTAssertEqual(FallbackThumbnailComposition(index: -1), .wovenStrips)
    }

    @MainActor
    func testEveryCompositionRendersWithEveryPalette() {
        for composition in FallbackThumbnailComposition.allCases {
            for paletteIndex in 0..<7 {
                let view = FallbackThumbnailView(
                    category: .generalUtility,
                    paletteIndex: paletteIndex,
                    styleIndex: composition.rawValue,
                    size: 64
                )
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2

                XCTAssertNotNil(
                    renderer.nsImage,
                    "Failed to render \(composition) with palette \(paletteIndex)"
                )
            }
        }
    }
}
