import SwiftUI
import UIKit

// MARK: - MarkdownPreviewView
// Read-only rich-text preview of Markdown. UIKit-backed so long documents
// scroll as smoothly as CodeEditorView (DESIGN.md §8.2).

struct MarkdownPreviewView: UIViewRepresentable {
    let markdown: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.showsVerticalScrollIndicator = true
        textView.backgroundColor = UIColor(red: 0.04, green: 0.06, blue: 0.08, alpha: 1) // background
        textView.tintColor = UIColor(red: 0.23, green: 0.74, blue: 1.00, alpha: 1)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.textContainer.lineFragmentPadding = 0
        textView.linkTextAttributes = [
            .foregroundColor: UIColor(red: 0.23, green: 0.74, blue: 1.00, alpha: 1),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.adjustsFontForContentSizeCategory = true
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        guard context.coordinator.lastMarkdown != markdown else { return }
        context.coordinator.lastMarkdown = markdown
        textView.attributedText = MarkdownRenderer.render(markdown)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var lastMarkdown: String?
    }
}
