public enum ProvenanceConfidence: String, Codable, CaseIterable, Comparable, Hashable, Sendable {
    case possible
    case likely
    case verified

    public static func < (lhs: ProvenanceConfidence, rhs: ProvenanceConfidence) -> Bool {
        lhs.rank < rhs.rank
    }

    public var label: String {
        rawValue.capitalized
    }

    private var rank: Int {
        switch self {
        case .possible: 0
        case .likely: 1
        case .verified: 2
        }
    }
}
