import Foundation

enum SettingsSectionID: String, CaseIterable, Identifiable {
    case general
    case appearance
    case agents
    case sources

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        case .agents: "cpu"
        case .sources: "point.3.connected.trianglepath.dotted"
        }
    }
}
