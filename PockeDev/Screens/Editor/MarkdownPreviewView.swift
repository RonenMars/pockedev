import SwiftUI
import UIKit

// MARK: - MarkdownPreviewView
// Read-only rich-text preview of Markdown. UIKit-backed so long documents
// scroll as smoothly as CodeEditorView (DESIGN.md §8.2).

struct MarkdownPreviewView: UIViewRepresentable {
    let markdown: String

    private static let renderQueue = DispatchQueue(
        label: "com.pockedev.markdown-preview",
        qos: .userInitiated
    )

    func makeUIView(context: Context) -> UITextView {
        let textView = TextKit1TextView.make(
            background: Tokens.UIColor.background,
            tint: Tokens.UIColor.accent
        )
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.linkTextAttributes = [
            .foregroundColor: Tokens.UIColor.accent,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.adjustsFontForContentSizeCategory = true
        textView.accessibilityCustomRotors = [context.coordinator.makeHeadingsRotor(for: textView)]
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let c = context.coordinator
        guard c.lastMarkdown != markdown else { return }
        c.lastMarkdown = markdown
        c.generation += 1
        let generation = c.generation

        if textView.textStorage.length == 0 {
            TextKit1TextView.setAttributedString(
                MarkdownRenderer.render(MarkdownRenderer.utf16Prefix(markdown, limit: 2_000)),
                on: textView,
                restoreSelection: false
            )
        }

        Self.renderQueue.async { [weak c] in
            guard let c, generation == c.generation else { return }
            let rendered = MarkdownRenderer.render(markdown)
            DispatchQueue.main.async { [weak c] in
                guard let c, generation == c.generation else { return }
                TextKit1TextView.setAttributedString(rendered, on: textView, restoreSelection: false)
                c.refreshHeadingRanges(in: rendered)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var lastMarkdown: String?
        var generation = 0
        private var headingRanges: [(NSRange, Int)] = []

        func textView(
            _ textView: UITextView,
            shouldInteractWith URL: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            MarkdownRenderer.isAllowedLink(URL) && interaction == .invokeDefaultAction
        }

        func refreshHeadingRanges(in rendered: NSAttributedString) {
            var ranges: [(NSRange, Int)] = []
            let key = NSAttributedString.Key.accessibilityTextHeadingLevel
            let full = NSRange(location: 0, length: rendered.length)
            rendered.enumerateAttribute(key, in: full) { value, range, _ in
                guard let level = (value as? NSNumber)?.intValue ?? value as? Int else { return }
                ranges.append((range, level))
            }
            headingRanges = ranges
        }

        func makeHeadingsRotor(for textView: UITextView) -> UIAccessibilityCustomRotor {
            UIAccessibilityCustomRotor(name: "Headings") { [weak self, weak textView] predicate in
                guard let self, let textView, !self.headingRanges.isEmpty else { return nil }
                let current = textView.selectedRange.location
                let next: (NSRange, Int)?
                if predicate.searchDirection == .previous {
                    next = self.headingRanges.last { $0.0.location < current }
                } else {
                    next = self.headingRanges.first { $0.0.location > current }
                }
                guard let hit = next,
                      let start = textView.position(from: textView.beginningOfDocument, offset: hit.0.location),
                      let end = textView.position(from: start, offset: max(hit.0.length, 1)),
                      let uiRange = textView.textRange(from: start, to: end)
                else { return nil }
                textView.selectedRange = NSRange(location: hit.0.location, length: 0)
                return UIAccessibilityCustomRotorItemResult(targetElement: textView, targetRange: uiRange)
            }
        }
    }
}
