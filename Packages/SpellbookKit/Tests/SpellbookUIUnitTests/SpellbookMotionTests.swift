import XCTest
@testable import SpellbookUI

final class SpellbookMotionTests: XCTestCase {
    func testMotionDurationsMatchTheQuietInteractionBudget() {
        XCTAssertEqual(SpellbookMotion.feedbackDuration, 0.16)
        XCTAssertEqual(SpellbookMotion.reducedFeedbackDuration, 0.09)

        XCTAssertEqual(SpellbookMotion.sourceCandidateEntranceDuration, 0.18)
        XCTAssertEqual(SpellbookMotion.sourceCandidateExitDuration, 0.14)
        XCTAssertEqual(SpellbookMotion.reducedSourceCandidateDuration, 0.10)
    }

    func testFirstLibraryRevealStaysWithinItsTotalBudgets() {
        XCTAssertEqual(
            SpellbookMotion.firstRevealExitDuration + SpellbookMotion.firstRevealEntranceDuration,
            0.28,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            SpellbookMotion.reducedFirstRevealExitDuration + SpellbookMotion.reducedFirstRevealEntranceDuration,
            0.18,
            accuracy: 0.000_001
        )
    }

    func testSidebarMotionMatchesTheApprovedQuietBudgets() {
        XCTAssertEqual(SpellbookMotion.sidebarHoverDuration, 0.10)
        XCTAssertEqual(SpellbookMotion.reducedSidebarHoverDuration, 0.06)
        XCTAssertEqual(SpellbookMotion.sidebarDisclosureDuration, 0.18)
        XCTAssertEqual(SpellbookMotion.reducedSidebarDisclosureDuration, 0.10)
        XCTAssertEqual(SpellbookMotion.scrollEdgeDuration, 0.12)
        XCTAssertEqual(SpellbookMotion.reducedScrollEdgeDuration, 0.08)
    }
}
