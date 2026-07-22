import AppKit
import SwiftUI

struct LibrarySearchField: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = "Search skills"
        searchField.font = SpellbookDesign.Typography.controlNSFont
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = context.coordinator
        searchField.setAccessibilityIdentifier("Search skills")
        return searchField
    }

    func updateNSView(_ searchField: NSSearchField, context: Context) {
        if searchField.stringValue != text {
            searchField.stringValue = text
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NSSearchField,
        context: Context
    ) -> CGSize? {
        CGSize(
            width: proposal.width ?? nsView.intrinsicContentSize.width,
            height: proposal.height ?? nsView.intrinsicContentSize.height
        )
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else { return }
            text = searchField.stringValue
        }
    }
}
