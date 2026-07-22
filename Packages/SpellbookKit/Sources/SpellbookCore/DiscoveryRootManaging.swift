public protocol DiscoveryRootManaging: Sendable {
    func roots() async throws -> [DiscoveryRootRecord]
    func addRoot(_ root: DiscoveryRootRecord) async throws
    func removeRoot(id: String) async throws
}
