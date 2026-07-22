import SwiftUI

struct MetadataLinkRowView: View {
    let label: String
    let title: String
    let url: URL

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(SpellbookDesign.Palette.textSecondary)
            Link(title, destination: url)
                .lineLimit(1)
                .tint(SpellbookDesign.Palette.link)
                .accessibilityLabel("Open \(label.lowercased()): \(title)")
        }
    }
}
