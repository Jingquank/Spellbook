public protocol TargetedSkillScanning: SkillScanning {
    func reconcile(
        snapshot: LibrarySnapshot,
        changes: FileChangeBatch
    ) -> AsyncThrowingStream<ScanUpdate, any Error>
}
