public struct ManagedMutationReceipt: Hashable, Sendable {
    public let operationID: String
    public let outcomes: [MutationTargetOutcome]

    public init(operationID: String, outcomes: [MutationTargetOutcome]) {
        self.operationID = operationID
        self.outcomes = outcomes
    }
}
