import SpellbookCore
import SwiftUI
import UniformTypeIdentifiers

struct ArtworkManagerSheet: View {
    @Environment(SpellbookModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let package: SkillPackageRecord

    @State private var importsArtwork = false
    @State private var confirmsRemoval = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SpellbookDesign.Space.xxLarge) {
            HStack {
                Text("Thumbnail for \(package.name)")
                    .font(SpellbookDesign.Typography.sheetTitle)
                    .bold()
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            HStack(spacing: SpellbookDesign.Space.large) {
                SkillIconView(thumbnail: thumbnail, size: 64)
                VStack(alignment: .leading, spacing: SpellbookDesign.Space.xSmall) {
                    Text(thumbnail.sourceKind.displayName)
                        .font(SpellbookDesign.Typography.sectionTitle)
                    Text(sourceDescription)
                        .font(SpellbookDesign.Typography.body)
                        .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                }
                Spacer()
            }

            Divider()

            HStack {
                Button(upload == nil ? "Upload…" : "Replace…", systemImage: "square.and.arrow.down") {
                    importsArtwork = true
                }
                .buttonStyle(.borderedProminent)

                if upload != nil {
                    Button("Remove Upload", systemImage: "trash", role: .destructive) {
                        confirmsRemoval = true
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
        }
        .padding(SpellbookDesign.Space.xxxLarge)
        .frame(minWidth: SpellbookDesign.Sheet.standardWidth, idealWidth: SpellbookDesign.Sheet.wideWidth)
        .fileImporter(isPresented: $importsArtwork, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url): importArtwork(url)
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog("Remove this uploaded thumbnail?", isPresented: $confirmsRemoval) {
            Button("Remove", role: .destructive) {
                Task { await model.removeArtworkUpload(for: package.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Spellbook will return to the best automatically discovered thumbnail.")
        }
        .alert("Couldn’t update thumbnail", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var upload: PackageArtworkUpload? { model.artworkUpload(for: package.id) }
    private var thumbnail: SkillThumbnail { model.thumbnail(for: package) }

    private var sourceDescription: String {
        switch thumbnail.sourceKind {
        case .userUpload: "Your upload overrides package and repository artwork."
        case .packageIcon: "Provided by the installed package."
        case .skillIcon: "Provided by the installed skill."
        case .githubSocialPreview: "Custom social preview from the verified GitHub repository."
        case .githubOrganizationAvatar: "Avatar for the organization that owns the repository."
        case .readmeImage: "First qualifying image near the top of the README."
        case .githubOwnerAvatar: "Avatar for the person who owns the repository."
        case .generatedFallback: "A stable abstract composition generated from the package palette."
        }
    }

    private func importArtwork(_ url: URL) {
        Task {
            do {
                try await model.importArtwork(from: url, for: package.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
