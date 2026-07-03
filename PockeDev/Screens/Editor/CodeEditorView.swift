import SwiftUI
import UIKit

// MARK: - CodeEditorView (COMPONENT_MAP: EditorView)
// UIKit-backed to guarantee: no typing lag, no scroll jank (DESIGN.md §8.2)
//
// Highlighting pipeline (two-pass, cached):
//   Pass 1 — syntax: runs when text or fileExtension changes. Result cached in coordinator.
//   Pass 2 — search overlay: runs when searchMatches or activeMatchIndex changes.
//            Applies background tints on a COPY of the cached syntax attributed string.
//            Never mutates the cache, so pass 1 re-runs only when content changes.
//
// scrollRangeToVisible fires only when activeMatchIndex changes AND the range is off-screen.
// Cursor position is preserved across all attributed-text updates.
// IME composition (markedText) is never interrupted.

struct CodeEditorView: UIViewRepresentable {
    @Binding var text: String
    var language: SyntaxHighlighter.Language = .plain
    var searchMatches: [NSRange] = []
    var activeMatchIndex: Int = 0
    var isEditable: Bool = true
    var onTextChange: ((String) -> Void)?

    // MARK: - Search highlight colors

    private static let inactiveMatchColor = UIColor(
        red: 0.96, green: 0.65, blue: 0.14, alpha: 0.28  // amber #F5A623 at 28%
    )
    private static let activeMatchColor = UIColor(
        red: 0.23, green: 0.74, blue: 1.00, alpha: 0.45  // accent #3ABEFF at 45%
    )

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        textView.delegate = context.coordinator
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.showsVerticalScrollIndicator = true

        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.backgroundColor = UIColor(red: 0.04, green: 0.06, blue: 0.08, alpha: 1) // background
        textView.textColor = UIColor(red: 0.90, green: 0.93, blue: 0.95, alpha: 1)       // textPrimary
        textView.tintColor = UIColor(red: 0.23, green: 0.74, blue: 1.00, alpha: 1)       // accent (cursor)

        // Padding (DESIGN.md §5.3)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.textContainer.lineFragmentPadding = 0

        textView.keyboardAppearance = .dark
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Never interrupt an active IME composition (Chinese, Japanese, Korean, etc.)
        guard textView.markedTextRange == nil else { return }

        let c = context.coordinator
        let textChanged    = c.lastText != text || c.lastLanguage != language
        let searchChanged  = c.lastMatches != searchMatches || c.lastActiveIndex != activeMatchIndex

        guard textChanged || searchChanged else {
            // Only isEditable may have changed
            textView.isEditable = isEditable
            return
        }

        // Pass 1 — rebuild syntax cache only when content or language changed
        if textChanged {
            c.cachedSyntaxAttr = SyntaxHighlighter.highlight(text: text, language: language)
            c.lastText = text
            c.lastLanguage = language
        }

        guard let base = c.cachedSyntaxAttr else { return }

        // Pass 2 — overlay search match backgrounds on a copy of the syntax result
        let result: NSMutableAttributedString
        if searchMatches.isEmpty {
            // No matches: use the cached syntax attributed string directly.
            // UIKit copies attributedText on assignment, so the cache stays clean.
            result = base
        } else {
            result = base.mutableCopy() as! NSMutableAttributedString
            for (i, match) in searchMatches.enumerated() {
                guard NSMaxRange(match) <= result.length else { continue }
                let color = i == activeMatchIndex
                    ? CodeEditorView.activeMatchColor
                    : CodeEditorView.inactiveMatchColor
                result.addAttribute(.backgroundColor, value: color, range: match)
            }
        }

        // Preserve cursor before replacing attributed text
        let savedRange = textView.selectedRange
        textView.attributedText = result
        let maxLoc = result.length
        let loc = min(savedRange.location, maxLoc)
        let len = min(savedRange.length, maxLoc - loc)
        textView.selectedRange = NSRange(location: loc, length: len)

        // Scroll to active match only when the active index changed AND range is off-screen
        let prevActiveIndex = c.lastActiveIndex
        c.lastMatches = searchMatches
        c.lastActiveIndex = activeMatchIndex

        if activeMatchIndex != prevActiveIndex,
           activeMatchIndex >= 0,
           activeMatchIndex < searchMatches.count {
            let activeRange = searchMatches[activeMatchIndex]
            if NSMaxRange(activeRange) <= result.length,
               !isRangeVisible(textView: textView, range: activeRange) {
                textView.scrollRangeToVisible(activeRange)
            }
        }

        textView.isEditable = isEditable
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextChange: onTextChange)
    }

    // MARK: - Visibility check

    /// Returns true if the first line of `range` is within the textView's visible bounds.
    private func isRangeVisible(textView: UITextView, range: NSRange) -> Bool {
        guard range.length > 0, range.location < (textView.text as NSString).length else {
            return true
        }
        let glyphRange = textView.layoutManager.glyphRange(
            forCharacterRange: range, actualCharacterRange: nil
        )
        let lineRect = textView.layoutManager.boundingRect(
            forGlyphRange: glyphRange, in: textView.textContainer
        )
        let inset = textView.textContainerInset
        let contentRect = lineRect.offsetBy(dx: inset.left, dy: inset.top)
        let visibleRect = CGRect(origin: textView.contentOffset, size: textView.bounds.size)
        return visibleRect.intersects(contentRect)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        var onTextChange: ((String) -> Void)?

        // Syntax cache — rebuilt only when text or language changes
        var cachedSyntaxAttr: NSMutableAttributedString? = nil
        var lastText: String? = nil
        var lastLanguage: SyntaxHighlighter.Language? = nil

        // Search state cache — rebuilt when matches or active index changes
        var lastMatches: [NSRange] = []
        var lastActiveIndex: Int = -1  // -1 so first render always triggers scroll check

        init(onTextChange: ((String) -> Void)?) {
            self.onTextChange = onTextChange
        }

        func textViewDidChange(_ textView: UITextView) {
            onTextChange?(textView.text)
        }
    }
}
