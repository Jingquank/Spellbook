import SpellbookMarkdown
import SwiftUI

struct MarkdownListView: View {
    let items: [MarkdownListItem]
    let startIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: SpellbookDesign.Space.medium) {
            ForEach(items.indices, id: \.self) { index in
                MarkdownListItemView(
                    item: items[index],
                    marker: marker(for: index)
                )
            }
        }
        .padding(.leading, SpellbookDesign.Space.xSmall)
    }

    private func marker(for offset: Int) -> String {
        if let startIndex {
            "\(startIndex + offset)."
        } else {
            "•"
        }
    }
}
