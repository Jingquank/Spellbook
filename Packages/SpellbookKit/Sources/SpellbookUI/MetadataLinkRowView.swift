import SwiftUI

struct MetadataLinkRowView: View {
    let label: String
    let title: String
    let url: URL

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Link(title, destination: url)
                .lineLimit(1)
                .tint(Color(nsColor: .linkColor))
                .accessibilityLabel("Open \(label.lowercased()): \(title)")
        }
    }
}
