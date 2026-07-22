import Foundation

public enum InterfaceDensity: String, CaseIterable, Codable, Sendable, Identifiable {
    case compact
    case comfortable

    public var id: String { rawValue }

    public var label: String { rawValue.capitalized }
}

