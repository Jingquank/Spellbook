import SpellbookCore
import SwiftUI

extension ReaderTextScale {
    var bodyFont: Font {
        SpellbookDesign.Typography.readerBody(for: self)
    }

    var tableFont: Font {
        SpellbookDesign.Typography.readerTable(for: self)
    }

    var codeFont: Font {
        SpellbookDesign.Typography.readerCode(for: self)
    }

    var editorPointSize: Double {
        SpellbookDesign.Typography.editorPointSize(for: self)
    }

    func headingFont(level: Int) -> Font {
        SpellbookDesign.Typography.readerHeading(level: level, scale: self)
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
