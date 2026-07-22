import Foundation
import SpellbookCore

public struct SkillDiscoveryRoot: Hashable, Sendable {
    public let agent: AgentKind
    public let url: URL

    public init(agent: AgentKind, url: URL) {
        self.agent = agent
        self.url = url.standardizedFileURL
    }

    public static var known: [SkillDiscoveryRoot] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            SkillDiscoveryRoot(agent: .claude, url: home.appending(path: ".claude/skills", directoryHint: .isDirectory)),
            SkillDiscoveryRoot(agent: .cursor, url: home.appending(path: ".cursor/skills", directoryHint: .isDirectory)),
            SkillDiscoveryRoot(agent: .codex, url: home.appending(path: ".codex/skills", directoryHint: .isDirectory)),
            SkillDiscoveryRoot(agent: .codex, url: home.appending(path: ".agents/skills", directoryHint: .isDirectory))
        ]
    }
}
