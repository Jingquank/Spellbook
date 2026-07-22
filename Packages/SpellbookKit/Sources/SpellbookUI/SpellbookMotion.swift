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
}
