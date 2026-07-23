import SwiftUI

enum SpellbookMotion {
    static let feedbackDuration = 0.16
    static let reducedFeedbackDuration = 0.09

    static let sourceCandidateEntranceDuration = 0.18
    static let sourceCandidateExitDuration = 0.14
    static let reducedSourceCandidateDuration = 0.10

    static let firstRevealExitDuration = 0.10
    static let firstRevealEntranceDuration = 0.18
    static let reducedFirstRevealExitDuration = 0.08
    static let reducedFirstRevealEntranceDuration = 0.10
    static let sidebarHoverDuration = 0.10
    static let reducedSidebarHoverDuration = 0.06
    static let sidebarDisclosureDuration = 0.18
    static let reducedSidebarDisclosureDuration = 0.10
    static let scrollEdgeDuration = 0.12
    static let reducedScrollEdgeDuration = 0.08

    static func feedback(reduceMotion: Bool) -> Animation {
        .easeOut(duration: reduceMotion ? reducedFeedbackDuration : feedbackDuration)
    }

    static func sourceCandidateEntrance(reduceMotion: Bool) -> Animation {
        .easeOut(duration: reduceMotion ? reducedSourceCandidateDuration : sourceCandidateEntranceDuration)
    }

    static func sourceCandidateExit(reduceMotion: Bool) -> Animation {
        .easeOut(duration: reduceMotion ? reducedSourceCandidateDuration : sourceCandidateExitDuration)
    }

    static func firstRevealExit(reduceMotion: Bool) -> Animation {
        .easeOut(duration: reduceMotion ? reducedFirstRevealExitDuration : firstRevealExitDuration)
    }

    static func firstRevealEntrance(reduceMotion: Bool) -> Animation {
        .easeOut(duration: reduceMotion ? reducedFirstRevealEntranceDuration : firstRevealEntranceDuration)
    }

    static func sidebarHover(reduceMotion: Bool) -> Animation {
        strongEaseOut(duration: reduceMotion ? reducedSidebarHoverDuration : sidebarHoverDuration)
    }

    static func sidebarDisclosure(reduceMotion: Bool) -> Animation {
        strongEaseOut(duration: reduceMotion ? reducedSidebarDisclosureDuration : sidebarDisclosureDuration)
    }

    static func scrollEdge(reduceMotion: Bool) -> Animation {
        strongEaseOut(duration: reduceMotion ? reducedScrollEdgeDuration : scrollEdgeDuration)
    }

    private static func strongEaseOut(duration: Double) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: duration)
    }
}
