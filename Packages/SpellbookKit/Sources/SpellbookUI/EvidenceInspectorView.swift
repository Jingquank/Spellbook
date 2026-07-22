import SpellbookCore
import SwiftUI

struct EvidenceInspectorView: View {
    let evidence: [SourceEvidence]

    var body: some View {
        VStack(alignment: .leading, spacing: SpellbookDesign.Space.large) {
            Text("Evidence")
                .font(SpellbookDesign.Typography.sectionTitle)
            if groups.isEmpty {
                Text("No source evidence has been observed.")
                    .font(SpellbookDesign.Typography.metadata)
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
            } else {
                ForEach(groups) { group in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: SpellbookDesign.Space.large) {
                            ForEach(group.records) { record in
                                evidenceRecord(record)
                                if record.id != group.records.last?.id { Divider() }
                            }
                        }
                        .padding(.top, SpellbookDesign.Space.medium)
                    } label: {
                        VStack(alignment: .leading, spacing: SpellbookDesign.Space.xSmall) {
                            Text(group.sourceURL?.host ?? "Local evidence")
                                .font(SpellbookDesign.Typography.rowLabel.weight(.semibold))
                            Text(summary(for: group))
                                .font(SpellbookDesign.Typography.metadata)
                                .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                        }
                    }
                    .accessibilityIdentifier("Evidence Group \(group.id)")
                }
            }
        }
    }

    private var groups: [EvidenceGroup] {
        EvidenceGrouper.groups(from: evidence)
    }

    private func summary(for group: EvidenceGroup) -> String {
        let installations = "\(group.supportingInstallationCount) installation\(group.supportingInstallationCount == 1 ? "" : "s")"
        return "\(group.strongestConfidence.label) · \(group.kinds.joined(separator: ", ")) · \(installations) · \(group.mostRecentObservation.formatted(date: .abbreviated, time: .omitted))"
    }

    private func evidenceRecord(_ record: SourceEvidence) -> some View {
        VStack(alignment: .leading, spacing: SpellbookDesign.Space.small) {
            Text(record.explanation)
                .font(SpellbookDesign.Typography.metadata)
            evidenceValue("Kind", record.kind)
            evidenceValue("Installation", record.installationID?.rawValue)
            evidenceValue("Package path", record.packagePath)
            evidenceValue("Skill path", record.skillPath)
            evidenceValue("Revision", record.revision)
            evidenceValue("Hash", record.contentHash)
            evidenceValue("Observed", record.observedAt.formatted(date: .abbreviated, time: .shortened))
        }
    }

    @ViewBuilder
    private func evidenceValue(_ label: String, _ value: String?) -> some View {
        if let value {
            HStack(alignment: .firstTextBaseline, spacing: SpellbookDesign.Space.medium) {
                Text(label)
                    .foregroundStyle(SpellbookDesign.Palette.textTertiary)
                    .frame(width: SpellbookDesign.Evidence.labelWidth, alignment: .leading)
                Text(value)
                    .font(SpellbookDesign.Typography.codeMetadata)
                    .textSelection(.enabled)
            }
            .font(SpellbookDesign.Typography.metadata)
        }
    }
}
