import Foundation
import SpellbookCore

struct EvidenceGroup: Identifiable, Equatable {
    let normalizedSource: String
    let sourceURL: URL?
    let strongestConfidence: ProvenanceConfidence
    let kinds: [String]
    let supportingInstallationCount: Int
    let mostRecentObservation: Date
    let records: [SourceEvidence]

    var id: String { normalizedSource }
}

enum EvidenceGrouper {
    static func groups(from evidence: [SourceEvidence]) -> [EvidenceGroup] {
        Dictionary(grouping: evidence, by: { normalizedSource(for: $0.sourceURL) })
            .map { normalizedSource, observations in
                let records = deduplicate(observations)
                    .sorted { $0.observedAt > $1.observedAt }
                return EvidenceGroup(
                    normalizedSource: normalizedSource,
                    sourceURL: records.compactMap(\.sourceURL).first,
                    strongestConfidence: records.map(\.confidence).max() ?? .possible,
                    kinds: Array(Set(records.map(\.kind))).sorted(),
                    supportingInstallationCount: Set(records.compactMap(\.installationID)).count,
                    mostRecentObservation: records.map(\.observedAt).max() ?? .distantPast,
                    records: records
                )
            }
            .sorted {
                if $0.strongestConfidence != $1.strongestConfidence {
                    return $0.strongestConfidence > $1.strongestConfidence
                }
                return $0.mostRecentObservation > $1.mostRecentObservation
            }
    }

    static func normalizedSource(for url: URL?) -> String {
        guard let url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "local-evidence"
        }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased().replacingOccurrences(of: "www.", with: "")
        components.query = nil
        components.fragment = nil
        if components.path.count > 1, components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        return components.string ?? url.absoluteString
    }

    private static func deduplicate(_ evidence: [SourceEvidence]) -> [SourceEvidence] {
        var newestBySignature: [String: SourceEvidence] = [:]
        for observation in evidence {
            let signature = [
                observation.installationID?.rawValue,
                observation.kind,
                observation.packagePath,
                observation.skillPath,
                observation.revision,
                observation.contentHash,
                observation.confidence.rawValue,
                observation.explanation
            ]
            .compactMap { $0 }
            .joined(separator: "|")
            if newestBySignature[signature]?.observedAt ?? .distantPast < observation.observedAt {
                newestBySignature[signature] = observation
            }
        }
        return Array(newestBySignature.values)
    }
}
