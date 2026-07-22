import Foundation

public struct AppearancePreferences: Equatable, Codable, Sendable {
    public var appearance: AppearanceMode
    public var density: InterfaceDensity
    public var textScale: InterfaceTextScale
    public var readerWidth: ReaderWidth
    public var readerTextScale: ReaderTextScale
    public var wrapsCode: Bool
    public var alwaysShowsPackageGroups: Bool

    public static let standard = AppearancePreferences(
        appearance: .system,
        density: .compact,
        textScale: .standard,
        readerWidth: .focused,
        readerTextScale: .standard,
        wrapsCode: false,
        alwaysShowsPackageGroups: false
    )

    public init(
        appearance: AppearanceMode,
        density: InterfaceDensity,
        textScale: InterfaceTextScale,
        readerWidth: ReaderWidth,
        readerTextScale: ReaderTextScale,
        wrapsCode: Bool,
        alwaysShowsPackageGroups: Bool
    ) {
        self.appearance = appearance
        self.density = density
        self.textScale = textScale
        self.readerWidth = readerWidth
        self.readerTextScale = readerTextScale
        self.wrapsCode = wrapsCode
        self.alwaysShowsPackageGroups = alwaysShowsPackageGroups
    }
}
