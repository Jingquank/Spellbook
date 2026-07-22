public enum PackageUpdateStrategy: String, Hashable, Sendable {
    case localGit
    case connectedGit
    case directFile
}
