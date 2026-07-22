import Foundation
import SpellbookCore
import XCTest
@testable import SpellbookInfrastructure

final class LargeLibraryPerformanceTests: XCTestCase {
    func testScansOneThousandSkillsAndFiveThousandFilesWithinBudget() async throws {
        let fixture = try TemporarySkillLibrary()
        let root = try fixture.makeDirectory(at: "large-library")
        for index in 0..<1_000 {
            let directory = "large-library/skill-\(index)"
            _ = try fixture.write("# Skill \(index)\n\nSearchable content.", at: "\(directory)/SKILL.md")
            for supportIndex in 0..<4 {
                _ = try fixture.write("support", at: "\(directory)/support-\(supportIndex).txt")
            }
        }
        let scanner = FileSystemSkillScanner(
            roots: [SkillDiscoveryRoot(agent: .codex, url: root)]
        )
        let clock = ContinuousClock()

        let elapsed = try await clock.measure {
            var finalCount = 0
            for try await update in scanner.scan() {
                if case .finished(let snapshot, _) = update {
                    finalCount = snapshot.skills.count
                }
            }
            XCTAssertEqual(finalCount, 1_000)
        }

        print("Spellbook large-library scan: \(elapsed)")
        XCTAssertLessThan(elapsed, .seconds(3))
    }
}
