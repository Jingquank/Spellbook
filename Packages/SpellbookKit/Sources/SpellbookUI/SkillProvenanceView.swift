import SpellbookCore
import SwiftUI

struct SkillProvenanceView: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let skill: SkillRecord

    @State private var showsDeepSearchConsent = false
    @State private var connectionError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Source")
                    .font(.headline)
                Spacer()
                if model.sourceConnection(for: skill) == nil && !model.selectedSkillIsProvisionalCluster {
                    Button {
                        Task { await model.findSource(for: skill) }
                    } label: {
                        ZStack {
                            Text("Find Source")
                                .opacity(model.isFindingSource ? 0 : 1)
                                .accessibilityHidden(model.isFindingSource)
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Finding…")
                            }
                            .opacity(model.isFindingSource ? 1 : 0)
                            .accessibilityHidden(!model.isFindingSource)
                        }
                        .animation(SpellbookMotion.feedback(reduceMotion: reduceMotion), value: model.isFindingSource)
                    }
                    .accessibilityLabel(model.isFindingSource ? "Finding…" : "Find Source")
                    .disabled(model.isFindingSource)
                }
            }

            if model.selectedSkillIsProvisionalCluster {
                Text("These installations are folded provisionally by compatible identity. Verify a source before using remote updates, or split them from the More menu.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if let provenance = model.provenance(for: skill) {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                    sourceRow("Origin", url: provenance.originURL)
                    sourceRow("Updates from", url: provenance.updateURL)
                    valueRow(
                        "Track",
                        value: selectedSourceState?.track
                            ?? provenance.branch
                            ?? "Default branch"
                    )
                    valueRow("Confidence", value: provenance.confidence.label)
                    if let verifiedAt = provenance.lastVerifiedAt {
                        valueRow("Verified", value: verifiedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let revision = selectedSourceState?.installedRevision
                        ?? model.sourceConnection(for: skill)?.lastRevision {
                        valueRow("Revision", value: String(revision.prefix(12)))
                    }
                    if let artwork = skill.artwork ?? model.snapshot.package(id: skill.packageID)?.artwork {
                        valueRow("Artwork", value: artwork.declaredPath)
                    }
                }
                .font(.callout)
            } else {
                Text("No verified source is connected. Spellbook keeps local files independent until you confirm a match.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(model.candidates(for: skill)) { candidate in
                candidateRow(candidate)
                    .transition(sourceCandidateTransition)
            }
            .animation(
                SpellbookMotion.sourceCandidateEntrance(reduceMotion: reduceMotion),
                value: candidateIDs
            )

            if !model.evidence(for: skill).isEmpty {
                DisclosureGroup("Evidence") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(model.evidence(for: skill)) { evidence in
                            HStack(alignment: .firstTextBaseline) {
                                Text(evidence.confidence.label)
                                    .font(.caption.weight(.medium))
                                    .frame(width: 52, alignment: .leading)
                                Text(evidence.explanation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                .font(.callout)
            }

            if model.sourceConnection(for: skill) == nil && !model.selectedSkillIsProvisionalCluster {
                Button("Search file contents…") {
                    showsDeepSearchConsent = true
                }
                .buttonStyle(.link)
                .font(.callout)
            }

            if let error = model.sourceDiscoveryError ?? connectionError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .alert("Send these terms to GitHub code search?", isPresented: $showsDeepSearchConsent) {
            Button("Cancel", role: .cancel) {}
            Button("Search") {
                Task { await model.findSource(for: skill, deep: true) }
            }
        } message: {
            Text(model.sourceDiscoveryTerms(for: skill).joined(separator: ", "))
        }
    }

    private var selectedSourceState: InstallationSourceState? {
        guard let installation = model.selectedInstallation else { return nil }
        return model.sourceState(for: installation)
    }

    private var candidateIDs: [String] {
        model.candidates(for: skill).map(\.id)
    }

    private var sourceCandidateTransition: AnyTransition {
        let insertion: AnyTransition = reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.98))
        return .asymmetric(
            insertion: insertion.animation(SpellbookMotion.sourceCandidateEntrance(reduceMotion: reduceMotion)),
            removal: AnyTransition.opacity.animation(SpellbookMotion.sourceCandidateExit(reduceMotion: reduceMotion))
        )
    }

    @ViewBuilder
    private func sourceRow(_ label: String, url: URL?) -> some View {
        if let url {
            GridRow {
                Text(label).foregroundStyle(.secondary)
                Link(url.host ?? url.absoluteString, destination: url)
                    .tint(Color(nsColor: .linkColor))
            }
        }
    }

    private func valueRow(_ label: String, value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }

    private func candidateRow(_ candidate: SourceCandidate) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.sourceURL.host.map { "\($0)\(candidate.sourceURL.path)" } ?? candidate.sourceURL.absoluteString)
                    .lineLimit(1)
                Text("\(candidate.confidence.label) · \(candidate.explanation)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Dismiss") {
                Task { await model.rejectSourceCandidate(candidate) }
            }
            Button("Connect") {
                Task {
                    do {
                        try await model.acceptSourceCandidate(candidate, for: skill)
                    } catch {
                        connectionError = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(10)
        .background(.quaternary.opacity(0.55), in: .rect(cornerRadius: 8))
    }
}
