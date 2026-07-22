import Foundation

public struct DiscoveryRootRecord: Identifiable, Hashable, Codable, Sendable {
    public let agent: AgentKind
    public let url: URL
    public let isKnown: Bool

    public var id: String {
        "\(agent.rawValue)::\(url.standardizedFileURL.path)"
    }

    public init(agent: AgentKind, url: URL, isKnown: Bool) {
        self.agent = agent
        self.url = url.standardizedFileURL
        self.isKnown = isKnown
    }
}
