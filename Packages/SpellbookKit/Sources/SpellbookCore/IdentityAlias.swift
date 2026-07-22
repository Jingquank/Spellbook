public struct IdentityAlias: Identifiable, Codable, Hashable, Sendable {
    public let previousID: String
    public let survivingID: String
    public let kind: String

    public var id: String { "\(kind)::\(previousID)" }

    public init(previousID: String, survivingID: String, kind: String) {
        self.previousID = previousID
        self.survivingID = survivingID
        self.kind = kind
    }
}
