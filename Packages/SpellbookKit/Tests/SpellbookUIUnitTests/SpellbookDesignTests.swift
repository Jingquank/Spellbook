import AppKit
import SpellbookCore
import Testing
@testable import SpellbookUI

@Suite("Spellbook design foundation")
struct SpellbookDesignTests {
    @Test("Primitive scales stay intentional")
    func primitiveScales() {
        #expect([
            SpellbookDesign.Space.micro,
            SpellbookDesign.Space.xSmall,
            SpellbookDesign.Space.small,
            SpellbookDesign.Space.medium,
            SpellbookDesign.Space.large,
            SpellbookDesign.Space.xLarge,
            SpellbookDesign.Space.xxLarge,
            SpellbookDesign.Space.xxxLarge,
            SpellbookDesign.Space.section,
            SpellbookDesign.Space.page
        ] == [2, 4, 6, 8, 12, 16, 20, 24, 32, 48])
        #expect(SpellbookDesign.Sidebar.minimumWidth < SpellbookDesign.Sidebar.idealWidth)
        #expect(SpellbookDesign.Sidebar.idealWidth < SpellbookDesign.Sidebar.maximumWidth)
        #expect(SpellbookDesign.Detail.focusedReaderWidth < SpellbookDesign.Detail.wideReaderWidth)
    }

    @Test("Bundled fonts register through Core Text")
    @MainActor
    func bundledFontsRegister() {
        SpellbookUIBootstrap.prepareDesignSystem()
        #expect(NSFont(name: "SchibstedGrotesk-Regular", size: 14) != nil)
        #expect(NSFont(name: "SchibstedGrotesk-Italic", size: 14) != nil)
        #expect(NSFont(name: "CommitMono-Regular", size: 13) != nil)
        #expect(NSFont(name: "CommitMono-Bold", size: 13) != nil)
    }

    @Test("Reader scale retains four monotonic sizes")
    func readerScaleIsMonotonic() {
        let sizes = ReaderTextScale.allCases.map { SpellbookDesign.Typography.editorPointSize(for: $0) }
        #expect(sizes == [12, 13, 16, 19])
    }

    @Test("Text and focus roles meet WCAG AA in every appearance")
    func paletteContrast() {
        let backgrounds = SpellbookDesign.Palette.canvasSeed
        let roles = [
            SpellbookDesign.Palette.primaryTextSeed,
            SpellbookDesign.Palette.secondaryTextSeed,
            SpellbookDesign.Palette.tertiaryTextSeed,
            SpellbookDesign.Palette.blueSeed,
            SpellbookDesign.Palette.successSeed,
            SpellbookDesign.Palette.warningSeed,
            SpellbookDesign.Palette.errorSeed
        ]
        for role in roles {
            #expect(contrast(role.light, backgrounds.light) >= 4.5)
            #expect(contrast(role.dark, backgrounds.dark) >= 4.5)
            #expect(contrast(role.highLight, backgrounds.highLight) >= 4.5)
            #expect(contrast(role.highDark, backgrounds.highDark) >= 4.5)
        }
    }

    private func contrast(_ first: UInt32, _ second: UInt32) -> Double {
        let light = max(luminance(first), luminance(second))
        let dark = min(luminance(first), luminance(second))
        return (light + 0.05) / (dark + 0.05)
    }

    private func luminance(_ value: UInt32) -> Double {
        let components = [16, 8, 0].map { shift -> Double in
            let channel = Double((value >> UInt32(shift)) & 0xFF) / 255
            return channel <= 0.04045
                ? channel / 12.92
                : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * components[0] + 0.7152 * components[1] + 0.0722 * components[2]
    }
}
