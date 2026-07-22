import SwiftUI

struct FallbackThumbnailPalette {
    let colors: [Color]

    init(index: Int) {
        let remainder = index % Self.all.count
        let wrappedIndex = remainder >= 0 ? remainder : remainder + Self.all.count
        self = Self.all[wrappedIndex]
    }

    // Exact opaque colors from the original fallback palettes. The former
    // transparent gradient endpoints are intentionally omitted.
    private static let all: [FallbackThumbnailPalette] = [
        palette([0x340B05, 0x0358F7, 0x5092C7, 0xE1ECFE, 0xFFD400, 0xFA3D1D, 0xFD02F5]),
        palette([0x05122E, 0x0358F7, 0x19C3D6, 0xA8F0E0, 0x7B61FF]),
        palette([0x2A0A05, 0x7A1F12, 0xFA3D1D, 0xFFD400, 0xFF7AD9]),
        palette([0x021018, 0x0B6E4F, 0x1FD18E, 0x9CF6C8, 0x56D6E8]),
        palette([0xFF7AB6, 0xFFA1D2, 0xC9A8FF, 0xA7D8FF, 0xFFF3B0]),
        palette([0x1A0400, 0x8E1600, 0xFF4D00, 0xFF9E1B, 0xFFE7A3]),
        palette([0x0A1A4A, 0x2B5BFF, 0x6E97FF, 0xBBD0FF])
    ]

    private static func palette(_ rgbValues: [UInt64]) -> FallbackThumbnailPalette {
        FallbackThumbnailPalette(colors: rgbValues.map(Color.init(thumbnailRGB:)))
    }

    private init(colors: [Color]) {
        self.colors = colors
    }
}

private extension Color {
    init(thumbnailRGB: UInt64) {
        self.init(
            red: Double((thumbnailRGB >> 16) & 0xFF) / 255,
            green: Double((thumbnailRGB >> 8) & 0xFF) / 255,
            blue: Double(thumbnailRGB & 0xFF) / 255
        )
    }
}
