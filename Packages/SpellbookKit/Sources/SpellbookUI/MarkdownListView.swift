import SpellbookMarkdown
import SwiftUI

struct MarkdownListView: View {
    let items: [MarkdownListItem]
    let startIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items.indices, id: \.self) { index in
                MarkdownListItemView(
                    item: items[index],
                    marker: marker(for: index)
                )
            }
        }
        .padding(.leading, 4)
    }

    private func marker(for offset: Int) -> String {
        if let startIndex {
            "\(startIndex + offset)."
        } else {
            "•"
        }
    }
}
