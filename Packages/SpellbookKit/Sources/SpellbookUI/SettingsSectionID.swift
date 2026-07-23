import Foundation

enum SettingsSectionID: String, CaseIterable, Identifiable {
    case general
    case appearance
    case agents
    case sources

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var icon: SpellbookIcon {
        switch self {
        case .general: .settings
        case .appearance: .palette
        case .agents: .cpu
        case .sources: .network
        }
    }
}
