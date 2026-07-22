import Foundation

public protocol SkillManaging: Sendable {
    func read(at url: URL) async throws -> ManagedFileContent

    func plan(
        _ requests: [MutationRequest],
        kind: ManagedOperationKind
    ) async throws -> ManagedMutationPlan

    func execute(_ plan: ManagedMutationPlan) async throws -> ManagedMutationReceipt

    func recoverInterruptedOperations() async throws -> [ManagedOperationRecord]

    func restore(
        recoveryURL: URL,
        to destinationURL: URL,
        expectedHash: String?
    ) async throws -> FileMutationReceipt

    func write(
        _ text: String,
        to url: URL,
        expectedHash: String?,
        kind: ManagedOperationKind
    ) async throws -> FileMutationReceipt

    func remove(
        at url: URL,
        expectedHash: String
    ) async throws -> FileMutationReceipt

    func suggestedEntryURL(for agent: AgentKind, skillName: String) async -> URL
}
