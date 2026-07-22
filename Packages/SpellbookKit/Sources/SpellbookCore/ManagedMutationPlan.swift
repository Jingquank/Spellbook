import Foundation

public struct ManagedMutationPlan: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let kind: ManagedOperationKind
    public let createdAt: Date
    public let targets: [MutationTargetPlan]

    public init(
        id: String,
        kind: ManagedOperationKind,
        createdAt: Date,
        targets: [MutationTargetPlan]
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.targets = targets
    }
}
