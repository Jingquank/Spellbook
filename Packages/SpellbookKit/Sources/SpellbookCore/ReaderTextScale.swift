import Foundation

public enum ReaderTextScale: String, CaseIterable, Codable, Sendable, Identifiable {
    case small
    case standard
    case large
    case extraLarge

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .small: "Small"
        case .standard: "Default"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }
}
