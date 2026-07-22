import Foundation
import Testing
@testable import SpellbookCore

@Suite("Actionable status")
struct ActionableStatusTests {
    @Test("Only the highest-priority state is surfaced")
    func prioritizesConflictOverModifiedAndUpdate() {
        let packageID = PackageID(rawValue: "package")
        let skill = SkillRecord(
            id: SkillID(rawValue: "skill"),
            packageID: packageID,
            name: "Skill",
            summary: "",
            markdownSource: "# Skill",
            installations: [
                installation(agent: .claude, state: .clean, updateAvailable: true),
                installation(agent: .cursor, state: .modified),
                installation(agent: .codex, state: .conflict)
            ]
        )

        #expect(skill.actionableStatus == .conflict)
    }

    @Test("Missing and inaccessible installations require action")
    func includesUnavailableStates() {
        let skill = SkillRecord(
            id: SkillID(rawValue: "skill"),
            packageID: PackageID(rawValue: "package"),
            name: "Skill",
            summary: "",
            markdownSource: "# Skill",
            installations: [installation(agent: .claude, state: .accessRequired)]
        )

        #expect(skill.actionableStatus == .actionRequired)
    }

    private func installation(
        agent: AgentKind,
        state: LocalState,
        updateAvailable: Bool = false
    ) -> SkillInstallation {
        let url = URL(filePath: "/tmp/\(agent.rawValue)/SKILL.md")
        return SkillInstallation(
            id: InstallationID(rawValue: agent.rawValue),
            agent: agent,
            entryURL: url,
            rootURL: url.deletingLastPathComponent(),
            contentHash: agent.rawValue,
            localState: state,
            updateAvailable: updateAvailable
        )
    }
}
