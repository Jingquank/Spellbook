import SpellbookCore
import SwiftUI

extension ReaderTextScale {
    var bodyFont: Font {
        switch self {
        case .small: .callout
        case .standard: .body
        case .large: .title3
        case .extraLarge: .title2
        }
    }

    var tableFont: Font {
        switch self {
        case .small: .caption
        case .standard: .callout
        case .large: .body
        case .extraLarge: .title3
        }
    }

    var codeFont: Font {
        switch self {
        case .small: .system(.caption, design: .monospaced)
        case .standard: .system(.callout, design: .monospaced)
        case .large: .system(.body, design: .monospaced)
        case .extraLarge: .system(.title3, design: .monospaced)
        }
    }

    var editorPointSize: Double {
        switch self {
        case .small: 12
        case .standard: 13
        case .large: 16
        case .extraLarge: 19
        }
    }

    func headingFont(level: Int) -> Font {
        switch (self, level) {
        case (.small, 1): .title3
        case (.small, 2): .headline
        case (.small, _): .subheadline
        case (.standard, 1): .title2
        case (.standard, 2): .title3
        case (.standard, 3): .headline
        case (.standard, _): .subheadline
        case (.large, 1): .title
        case (.large, 2): .title2
        case (.large, _): .title3
        case (.extraLarge, 1): .largeTitle
        case (.extraLarge, 2): .title
        case (.extraLarge, _): .title2
        }
    }
}

private struct ReaderTextScaleKey: EnvironmentKey {
    static let defaultValue = ReaderTextScale.standard
}

extension EnvironmentValues {
    var readerTextScale: ReaderTextScale {
        get { self[ReaderTextScaleKey.self] }
        set { self[ReaderTextScaleKey.self] = newValue }
    }
}
