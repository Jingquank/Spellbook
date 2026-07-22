import Foundation

public enum InterfaceTextScale: String, CaseIterable, Codable, Sendable, Identifiable {
    case small
    case standard
    case large

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .small: "Small"
        case .standard: "Default"
        case .large: "Large"
        }
    }
}

