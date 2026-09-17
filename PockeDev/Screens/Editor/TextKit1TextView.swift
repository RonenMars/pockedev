import UIKit

// MARK: - TextKit 1 UITextView
// UITextView() on iOS 16+ uses TextKit 2, which can stall laying out a full
// document. Assign attributedText can also replace the TK1 stack — always
// write through textStorage instead.

enum TextKit1TextView {
    static func make(
        background: UIColor,
        tint: UIColor,
        insets: UIEdgeInsets = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
    ) -> UITextView {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        let container = NSTextContainer(size: .zero)
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)

        let textView = UITextView(frame: .zero, textContainer: container)
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.showsVerticalScrollIndicator = true
        textView.backgroundColor = background
        textView.tintColor = tint
        textView.textContainerInset = insets
        return textView
    }

    static func setAttributedString(_ result: NSAttributedString, on textView: UITextView, restoreSelection: Bool) {
        let savedRange = textView.selectedRange
        textView.textStorage.setAttributedString(result)
        guard restoreSelection else { return }
        let maxLoc = result.length
        let loc = min(savedRange.location, maxLoc)
        let len = min(savedRange.length, max(0, maxLoc - loc))
        textView.selectedRange = NSRange(location: loc, length: len)
    }
}
