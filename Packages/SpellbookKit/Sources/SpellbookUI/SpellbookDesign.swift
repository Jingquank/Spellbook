import AppKit
import CoreText
import SpellbookCore
import SwiftUI

enum SpellbookDesign {
    enum Space {
        static let micro = 2.0
        static let xSmall = 4.0
        static let small = 6.0
        static let medium = 8.0
        static let large = 12.0
        static let xLarge = 16.0
        static let xxLarge = 20.0
        static let xxxLarge = 24.0
        static let section = 32.0
        static let page = 48.0
    }

    enum Radius {
        static let xSmall = 4.0
        static let small = 6.0
        static let medium = 8.0
        static let large = 10.0
        static let xLarge = 12.0
    }

    enum Stroke {
        static let hairline = 0.5
        static let standard = 1.0
    }

    enum Size {
        static let compactIcon = 12.0
        static let icon = 16.0
        static let sidebarArtwork = 18.0
        static let emphasizedArtwork = 20.0
        static let largeArtwork = 22.0
        static let detailArtwork = 42.0
    }

    enum Typography {
        static let interfaceFamily = "Schibsted Grotesk"
        static let codeFamily = "CommitMono"

        static let micro = interface(11, relativeTo: .caption2)
        static let metadata = interface(12, relativeTo: .caption)
        static let control = interface(14, relativeTo: .callout)
        static let rowLabel = interface(14, relativeTo: .callout)
        static let body = interface(14, relativeTo: .body)
        static let sectionTitle = interface(15, relativeTo: .headline, weight: .semibold)
        static let sheetTitle = interface(22, relativeTo: .title2, weight: .bold)
        static let detailTitle = interface(24, relativeTo: .title2, weight: .bold)
        static let codeMetadata = code(12, relativeTo: .caption)
        static let codeBody = code(13, relativeTo: .callout)

        static var controlNSFont: NSFont {
            NSFont(name: "SchibstedGrotesk-Regular", size: 14)
                ?? NSFont.systemFont(ofSize: 14)
        }

        static func readerBody(for scale: ReaderTextScale) -> Font {
            switch scale {
            case .small: interface(13, relativeTo: .callout)
            case .standard: interface(15, relativeTo: .body)
            case .large: interface(17, relativeTo: .title3)
            case .extraLarge: interface(20, relativeTo: .title2)
            }
        }

        static func readerTable(for scale: ReaderTextScale) -> Font {
            switch scale {
            case .small: interface(12, relativeTo: .caption)
            case .standard: interface(13, relativeTo: .callout)
            case .large: interface(15, relativeTo: .body)
            case .extraLarge: interface(17, relativeTo: .title3)
            }
        }

        static func readerCode(for scale: ReaderTextScale) -> Font {
            switch scale {
            case .small: code(12, relativeTo: .caption)
            case .standard: code(13, relativeTo: .callout)
            case .large: code(15, relativeTo: .body)
            case .extraLarge: code(17, relativeTo: .title3)
            }
        }

        static func readerHeading(level: Int, scale: ReaderTextScale) -> Font {
            let base: Double
            switch level {
            case 1: base = 24
            case 2: base = 20
            case 3: base = 17
            default: base = 15
            }
            let offset: Double = switch scale {
            case .small: -2
            case .standard: 0
            case .large: 3
            case .extraLarge: 6
            }
            return interface(base + offset, relativeTo: level == 1 ? .title2 : .headline, weight: .bold)
        }

        static func editorPointSize(for scale: ReaderTextScale) -> Double {
            switch scale {
            case .small: 12
            case .standard: 13
            case .large: 16
            case .extraLarge: 19
            }
        }

        static func editorFont(size: Double, bold: Bool = false) -> NSFont {
            let name = bold ? "CommitMono-Bold" : "CommitMono-Regular"
            return NSFont(name: name, size: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
        }

        private static func interface(
            _ size: Double,
            relativeTo style: Font.TextStyle,
            weight: Font.Weight = .regular
        ) -> Font {
            .custom(interfaceFamily, size: size, relativeTo: style).weight(weight)
        }

        private static func code(
            _ size: Double,
            relativeTo style: Font.TextStyle,
            weight: Font.Weight = .regular
        ) -> Font {
            .custom(codeFamily, size: size, relativeTo: style).weight(weight)
        }
    }

    enum Palette {
        struct Seed {
            let light: UInt32
            let dark: UInt32
            let highLight: UInt32
            let highDark: UInt32
        }

        static let canvasSeed = Seed(light: 0xFBFAF8, dark: 0x222326, highLight: 0xFFFEFC, highDark: 0x191A1D)
        static let sidebarSeed = Seed(light: 0xF4F3F1, dark: 0x292A2E, highLight: 0xEFEEEB, highDark: 0x242529)
        static let raisedSeed = Seed(light: 0xFEFDFB, dark: 0x313238, highLight: 0xFFFFFF, highDark: 0x37383E)
        static let groupedSeed = Seed(light: 0xF0EFEC, dark: 0x2B2C30, highLight: 0xEAE9E5, highDark: 0x313238)
        static let hoverSeed = Seed(light: 0xEDECE9, dark: 0x34353A, highLight: 0xE5E4E0, highDark: 0x3D3E44)
        static let selectionSeed = Seed(light: 0xE4E3DF, dark: 0x3C3D43, highLight: 0xD8D7D2, highDark: 0x484A51)
        static let primaryTextSeed = Seed(light: 0x242529, dark: 0xE9E8E5, highLight: 0x17181B, highDark: 0xF7F6F2)
        static let secondaryTextSeed = Seed(light: 0x686A70, dark: 0xB7B6B2, highLight: 0x54565B, highDark: 0xCDCCC8)
        static let tertiaryTextSeed = Seed(light: 0x717378, dark: 0x8F908E, highLight: 0x64666B, highDark: 0xA7A8A5)
        static let separatorSeed = Seed(light: 0xDAD9D5, dark: 0x47484D, highLight: 0xC7C6C1, highDark: 0x5B5C62)
        static let disabledSeed = Seed(light: 0xA5A6A4, dark: 0x747579, highLight: 0x8D8E8C, highDark: 0x8A8B90)
        static let blueSeed = Seed(light: 0x356CA8, dark: 0x78A7D8, highLight: 0x245C98, highDark: 0x91BCE7)
        static let successSeed = Seed(light: 0x2F7651, dark: 0x69B88B, highLight: 0x236440, highDark: 0x82CCA2)
        static let warningSeed = Seed(light: 0x9A5A12, dark: 0xE2A052, highLight: 0x814704, highDark: 0xF2B66D)
        static let errorSeed = Seed(light: 0xAB4138, dark: 0xE17A72, highLight: 0x922E28, highDark: 0xF0948D)
        static let diffAddedSeed = Seed(light: 0xEAF4EE, dark: 0x26352D, highLight: 0xDCEEE3, highDark: 0x2D4437)
        static let diffRemovedSeed = Seed(light: 0xF7ECEA, dark: 0x382A2B, highLight: 0xF1DEDA, highDark: 0x4A3031)

        static let canvas = dynamic(canvasSeed)
        static let sidebar = dynamic(sidebarSeed)
        static let raised = dynamic(raisedSeed)
        static let grouped = dynamic(groupedSeed)
        static let hover = dynamic(hoverSeed)
        static let selection = dynamic(selectionSeed)
        static let textPrimary = dynamic(primaryTextSeed)
        static let textSecondary = dynamic(secondaryTextSeed)
        static let textTertiary = dynamic(tertiaryTextSeed)
        static let separator = dynamic(separatorSeed)
        static let disabled = dynamic(disabledSeed)
        static let focus = dynamic(blueSeed)
        static let link = dynamic(blueSeed)
        static let update = dynamic(blueSeed)
        static let success = dynamic(successSeed)
        static let warning = dynamic(warningSeed)
        static let error = dynamic(errorSeed)
        static let diffAdded = dynamic(diffAddedSeed)
        static let diffRemoved = dynamic(diffRemovedSeed)
        static let primaryAction = textPrimary
        static let onPrimaryAction = canvas

        private static func dynamic(_ seed: Seed) -> Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [.accessibilityHighContrastDarkAqua, .darkAqua, .accessibilityHighContrastAqua, .aqua])
                switch match {
                case .accessibilityHighContrastDarkAqua: return nsColor(seed.highDark)
                case .darkAqua: return nsColor(seed.dark)
                case .accessibilityHighContrastAqua: return nsColor(seed.highLight)
                default: return nsColor(seed.light)
                }
            })
        }

        private static func nsColor(_ rgb: UInt32) -> NSColor {
            NSColor(
                srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        }
    }

    enum Sidebar {
        static let minimumWidth = 240.0
        static let idealWidth = 260.0
        static let maximumWidth = 300.0
        static let rowSpacing = 1.0
        static let rowRadius = Radius.small
        static let horizontalInset = Space.small
        static let verticalInset = Space.xSmall
        static let headerTopInset = 11.0
        static let headerBottomInset = Space.medium
        static let compactRowHeight = 31.0
        static let comfortableRowHeight = 39.0
        static let artworkSize = Size.largeArtwork
        static let searchFieldHeight = 28.0
        static let headerHorizontalInset = Space.large
        static let headerVerticalInset = Space.medium
    }

    enum Detail {
        static let compactInset = 30.0
        static let comfortableInset = 36.0
        static let compactSectionSpacing = 22.0
        static let comfortableSectionSpacing = 28.0
        static let focusedReaderWidth = 760.0
        static let wideReaderWidth = 980.0
        static let artworkSize = Size.detailArtwork
        static let inspectorMinimumWidth = 280.0
        static let inspectorIdealWidth = 340.0
        static let inspectorMaximumWidth = 420.0
        static let summaryCollapsedLines = 3
    }

    enum Settings {
        static let compactRowHeight = 44.0
        static let comfortableRowHeight = 52.0
    }

    enum Installation {
        static let dividerIndent = 38.0
        static let horizontalInset = 11.0
    }

    enum Evidence {
        static let labelWidth = 76.0
        static let confidenceWidth = 52.0
    }

    enum Sheet {
        static let contentPadding = Space.xxLarge
        static let sectionPadding = Space.large
        static let dividerIndent = 54.0
        static let compactWidth = 420.0
        static let standardWidth = 460.0
        static let sourceIdealWidth = 500.0
        static let wideWidth = 520.0
        static let xWideWidth = 560.0
        static let reviewWidth = 620.0
        static let updateMinimumWidth = 480.0
        static let editorWidth = 760.0
        static let comparisonWidth = 780.0
        static let compactHeight = 280.0
        static let shortHeight = 300.0
        static let destinationIdealHeight = 320.0
        static let standardHeight = 360.0
        static let sourceIdealHeight = 420.0
        static let reviewHeight = 440.0
        static let tallHeight = 460.0
        static let editorHeight = 480.0
        static let xTallHeight = 520.0
        static let comparisonIdealHeight = 560.0
        static let maximumHeight = 600.0
        static let updateContentMinimumHeight = 260.0
        static let editorMinimumHeight = 160.0
    }

    enum Reader {
        static let listMarkerWidth = 18.0
        static let tableColumnMinimumWidth = 120.0
        static let imageMaximumHeight = 520.0
        static let codeHeaderHeight = 34.0
        static let diffMinimumHeight = 150.0
        static let diffIdealHeight = 190.0
        static let diffMaximumHeight = 220.0
    }

    static func registerFonts() {
        FontRegistrar.registerIfNeeded()
    }
}

/// The public startup seam keeps the token namespace internal to SpellbookUI.
public enum SpellbookUIBootstrap {
    public static func prepareDesignSystem() {
        SpellbookDesign.registerFonts()
    }
}

private enum FontRegistrar {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var hasRegistered = false

    static func registerIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !hasRegistered else { return }

        let fontNames = [
            "SchibstedGrotesk[wght]",
            "SchibstedGrotesk-Italic[wght]",
            "CommitMono-400-Regular",
            "CommitMono-400-Italic",
            "CommitMono-700-Regular",
            "CommitMono-700-Italic"
        ]

        for name in fontNames {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.module.url(forResource: name, withExtension: "ttf") else {
                assertionFailure("Missing bundled font resource: \(name).ttf")
                continue
            }
            var registrationError: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &registrationError),
               let error = registrationError?.takeRetainedValue(),
               CFErrorGetCode(error) != CTFontManagerError.alreadyRegistered.rawValue {
                assertionFailure("Could not register \(name): \(error)")
            }
        }
        hasRegistered = true
    }
}
