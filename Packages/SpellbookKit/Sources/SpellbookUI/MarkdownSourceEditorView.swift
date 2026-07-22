import AppKit
import SwiftUI

struct MarkdownSourceEditorView: NSViewRepresentable {
    @Binding var text: String
    let fontSize: Double

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(
            width: SpellbookDesign.Space.large,
            height: SpellbookDesign.Space.large
        )
        applyTypography(to: textView)
        textView.string = text
        textView.backgroundColor = .textBackgroundColor
        textView.setAccessibilityLabel("Skill Markdown source")
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else {
            if let textView = scrollView.documentView as? NSTextView {
                applyTypography(to: textView)
            }
            return
        }
        textView.string = text
        applyTypography(to: textView)
    }

    private func applyTypography(to textView: NSTextView) {
        textView.font = SpellbookDesign.Typography.editorFont(size: fontSize)
        textView.typingAttributes[.ligature] = 0
        textView.textStorage?.addAttribute(
            .ligature,
            value: 0,
            range: NSRange(location: 0, length: textView.string.utf16.count)
        )
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}
