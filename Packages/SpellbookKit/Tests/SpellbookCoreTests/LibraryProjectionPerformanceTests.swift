import Foundation
import Testing
@testable import SpellbookCore

@Suite("Library projection performance")
struct LibraryProjectionPerformanceTests {
    @Test("Projects a 1,000-skill search within the interaction budget")
    func projectsLargeSearch() {
        let snapshot = makeSnapshot()
        let clock = ContinuousClock()

        let elapsed = clock.measure {
            _ = LibraryProjection(
                snapshot: snapshot,
                mode: .skillFirst,
                searchText: "needle phrase",
                alwaysShowsPackageGroups: false
            )
        }

        print("Spellbook 1,000-skill projection: \(elapsed)")
        #expect(elapsed < .milliseconds(250))
    }

    private func makeSnapshot() -> LibrarySnapshot {
        let repeatedText = String(repeating: "documentation words ", count: 200)
        let skills = (0..<1_000).map { index in
            let skillID = SkillID(rawValue: "skill-\(index)")
            let packageID = PackageID(rawValue: "package-\(index)")
            return SkillRecord(
                id: skillID,
                packageID: packageID,
                name: "Skill \(index)",
                summary: index == 777 ? "needle phrase" : "summary",
                markdownSource: repeatedText,
                installations: []
            )
        }
        return LibrarySnapshot(
            packages: skills.map { skill in
                SkillPackageRecord(
                    id: skill.packageID,
                    name: skill.name,
                    skillIDs: [skill.id]
                )
            },
            skills: skills,
            scannedAt: .now
        )
    }
}
