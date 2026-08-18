import SwiftUI
import UIKit

// MARK: - MarkdownPreviewView
// Read-only rich-text preview of Markdown. UIKit-backed so long documents
// scroll as smoothly as CodeEditorView (DESIGN.md §8.2).

struct MarkdownPreviewView: UIViewRepresentable {
    let markdown: String

    func makeUIView(context: Context) -> UITextView {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        let container = NSTextContainer(size: .zero)
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)

        let textView = UITextView(frame: .zero, textContainer: container)
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.showsVerticalScrollIndicator = true
        textView.backgroundColor = UIColor(red: 0.04, green: 0.06, blue: 0.08, alpha: 1) // background
        textView.tintColor = UIColor(red: 0.23, green: 0.74, blue: 1.00, alpha: 1)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.linkTextAttributes = [
            .foregroundColor: UIColor(red: 0.23, green: 0.74, blue: 1.00, alpha: 1),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.adjustsFontForContentSizeCategory = false
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let c = context.coordinator
        guard c.lastMarkdown != markdown else { return }
        c.lastMarkdown = markdown
        c.generation += 1
        let generation = c.generation
        DispatchQueue.global(qos: .userInitiated).async {
            let rendered = MarkdownRenderer.render(markdown)
            DispatchQueue.main.async {
                guard generation == c.generation else { return }
                textView.attributedText = rendered
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var lastMarkdown: String?
        var generation = 0
    }
}
