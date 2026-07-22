import Foundation
import SpellbookCore
import XCTest
@testable import SpellbookInfrastructure

final class FSEventsSkillChangeMonitorTests: XCTestCase {
    func testEmitsWhenSkillTreeChanges() async throws {
        let fixture = try TemporarySkillLibrary()
        let registry = DiscoveryRootRegistry(
            knownRoots: [SkillDiscoveryRoot(agent: .codex, url: fixture.url)],
            catalog: nil
        )
        let monitor = FSEventsSkillChangeMonitor(
            registry: registry,
            rootRefreshInterval: .milliseconds(50)
        )
        let event = expectation(description: "FSEvents emitted an invalidation")
        let observation = Task {
            for await _ in monitor.changes() {
                event.fulfill()
                break
            }
        }

        try await Task.sleep(for: .milliseconds(250))
        _ = try fixture.write("# Changed", at: "new-skill/SKILL.md")
        await fulfillment(of: [event], timeout: 4)
        observation.cancel()
    }
}
