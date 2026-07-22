public struct MutationDiffSummary: Codable, Hashable, Sendable {
    public let addedLineCount: Int
    public let removedLineCount: Int

    public init(addedLineCount: Int, removedLineCount: Int) {
        self.addedLineCount = addedLineCount
        self.removedLineCount = removedLineCount
    }
}
