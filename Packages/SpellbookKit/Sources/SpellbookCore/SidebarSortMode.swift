import Foundation

public enum SidebarSortMode: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case alphabeticalAscending
    case alphabeticalDescending
    case newestInstalled
    case oldestInstalled

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .alphabeticalAscending: "A–Z"
        case .alphabeticalDescending: "Z–A"
        case .newestInstalled: "Newest Installed"
        case .oldestInstalled: "Oldest Installed"
        }
    }
}
