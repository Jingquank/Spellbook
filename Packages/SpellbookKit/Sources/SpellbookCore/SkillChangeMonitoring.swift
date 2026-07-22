public protocol SkillChangeMonitoring: Sendable {
    func changes() -> AsyncStream<FileChangeBatch>
}
