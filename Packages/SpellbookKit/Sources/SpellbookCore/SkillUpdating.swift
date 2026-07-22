public protocol SkillUpdating: Sendable {
    func check(snapshot: LibrarySnapshot) async throws -> [PackageUpdate]
    func apply(_ update: PackageUpdate) async throws -> PackageUpdateReceipt
}
