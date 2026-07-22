import Foundation

public enum ReaderWidth: String, CaseIterable, Codable, Sendable, Identifiable {
    case focused
    case wide

    public var id: String { rawValue }

    public var label: String { rawValue.capitalized }
}

