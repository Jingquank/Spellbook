import SpellbookCore
import SwiftUI

private struct InterfaceDensityKey: EnvironmentKey {
    static let defaultValue = InterfaceDensity.compact
}

private struct SystemDynamicTypeSizeKey: EnvironmentKey {
    static let defaultValue = DynamicTypeSize.large
}

extension EnvironmentValues {
    var interfaceDensity: InterfaceDensity {
        get { self[InterfaceDensityKey.self] }
        set { self[InterfaceDensityKey.self] = newValue }
    }

    var systemDynamicTypeSize: DynamicTypeSize {
        get { self[SystemDynamicTypeSizeKey.self] }
        set { self[SystemDynamicTypeSizeKey.self] = newValue }
    }
}

extension InterfaceDensity {
    var controlSize: ControlSize {
        switch self {
        case .compact: .small
        case .comfortable: .regular
        }
    }

    var libraryRowHeight: Double {
        switch self {
        case .compact: SpellbookDesign.Sidebar.compactRowHeight
        case .comfortable: SpellbookDesign.Sidebar.comfortableRowHeight
        }
    }

    var settingsRowHeight: Double {
        switch self {
        case .compact: SpellbookDesign.Settings.compactRowHeight
        case .comfortable: SpellbookDesign.Settings.comfortableRowHeight
        }
    }

    var detailInset: Double {
        switch self {
        case .compact: SpellbookDesign.Detail.compactInset
        case .comfortable: SpellbookDesign.Detail.comfortableInset
        }
    }

    var sectionSpacing: Double {
        switch self {
        case .compact: SpellbookDesign.Detail.compactSectionSpacing
        case .comfortable: SpellbookDesign.Detail.comfortableSectionSpacing
        }
    }
}

extension InterfaceTextScale {
    func resolvedDynamicTypeSize(from systemSize: DynamicTypeSize) -> DynamicTypeSize {
        guard !systemSize.isAccessibilitySize else { return systemSize }
        let sizes: [DynamicTypeSize] = [.xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge]
        let currentIndex = sizes.firstIndex(of: systemSize) ?? 3
        let offset = switch self {
        case .small: -1
        case .standard: 0
        case .large: 1
        }
        return sizes[min(max(currentIndex + offset, 0), sizes.count - 1)]
    }
}

private struct InterfaceAppearanceModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize

    let textScale: InterfaceTextScale
    let density: InterfaceDensity

    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(textScale.resolvedDynamicTypeSize(from: systemDynamicTypeSize))
            .controlSize(density.controlSize)
            .environment(\.interfaceDensity, density)
            .environment(\.systemDynamicTypeSize, systemDynamicTypeSize)
    }
}

public extension View {
    func interfaceAppearance(
        textScale: InterfaceTextScale,
        density: InterfaceDensity
    ) -> some View {
        modifier(InterfaceAppearanceModifier(textScale: textScale, density: density))
    }
}
