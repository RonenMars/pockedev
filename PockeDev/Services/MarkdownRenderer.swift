import Foundation
import UIKit

// MARK: - MarkdownRenderer
// Converts Markdown source into a dark-theme NSAttributedString using Foundation's
// Markdown parser (presentation intents). Syntax characters are stripped; headings,
// emphasis, lists, quotes, and code are styled for a read-only preview.

enum MarkdownRenderer {

    private static let maxPreviewUTF16Count = 100_000

    static func render(_ markdown: String) -> NSAttributedString {
        guard !markdown.isEmpty else { return NSAttributedString() }

        if markdown.utf16.count > maxPreviewUTF16Count {
            return plain(markdown)
        }

        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )

        let parsed: AttributedString
        do {
            parsed = try AttributedString(markdown: markdown, options: options)
        } catch {
            return plain(markdown)
        }

        let result = NSMutableAttributedString(parsed)
        guard result.length > 0 else { return result }

        applyBaseAttributes(to: result)
        applyRunStyles(to: result)
        insertListMarkers(into: result)
        return result
    }

    // MARK: - Colors / fonts (match Tokens.swift)

    private enum C {
        static let textPrimary   = UIColor(red: 0.90, green: 0.93, blue: 0.95, alpha: 1) // #E6EDF3
        static let textSecondary = UIColor(red: 0.62, green: 0.65, blue: 0.70, alpha: 1) // #9DA7B3
        static let accent        = UIColor(red: 0.23, green: 0.74, blue: 1.00, alpha: 1) // #3ABEFF
        static let panel         = UIColor(red: 0.10, green: 0.13, blue: 0.18, alpha: 1) // #1A222D
        static let warning       = UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 1) // #F5A623
    }

    private enum Fonts {
        static let bodySize: CGFloat = 16
        static let codeSize: CGFloat = 14

        static func body(weight: UIFont.Weight = .regular, italic: Bool = false) -> UIFont {
            styled(UIFont.systemFont(ofSize: bodySize, weight: weight), italic: italic)
        }

        static func heading(level: Int) -> UIFont {
            let sizes: [CGFloat] = [28, 24, 20, 18, 16, 15]
            let size = sizes[min(max(level, 1), 6) - 1]
            return UIFont.systemFont(ofSize: size, weight: .bold)
        }

        static func code(italic: Bool = false) -> UIFont {
            styled(UIFont.monospacedSystemFont(ofSize: codeSize, weight: .regular), italic: italic)
        }

        private static func styled(_ font: UIFont, italic: Bool) -> UIFont {
            guard italic else { return font }
            let traits = font.fontDescriptor.symbolicTraits.union(.traitItalic)
            guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return font }
            return UIFont(descriptor: descriptor, size: font.pointSize)
        }
    }

    // MARK: - Base

    private static func plain(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: Fonts.body(),
                .foregroundColor: C.textPrimary
            ]
        )
    }

    private static func applyBaseAttributes(to result: NSMutableAttributedString) {
        let full = NSRange(location: 0, length: result.length)
        result.addAttribute(.font, value: Fonts.body(), range: full)
        result.addAttribute(.foregroundColor, value: C.textPrimary, range: full)
    }

    // MARK: - Run styles

    private static func applyRunStyles(to result: NSMutableAttributedString) {
        let full = NSRange(location: 0, length: result.length)
        result.enumerateAttributes(in: full, options: []) { attrs, range, _ in
            var weight: UIFont.Weight = .regular
            var italic = false
            var mono = false
            var color = C.textPrimary
            var sizeOverride: UIFont?
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 3
            paragraph.paragraphSpacing = 8

            if let inline = attrs[.inlinePresentationIntent] as? InlinePresentationIntent {
                if inline.contains(.stronglyEmphasized) { weight = .bold }
                if inline.contains(.emphasized) { italic = true }
                if inline.contains(.code) {
                    mono = true
                    color = C.accent
                    result.addAttribute(.backgroundColor, value: C.panel, range: range)
                }
                if inline.contains(.strikethrough) {
                    result.addAttribute(
                        .strikethroughStyle,
                        value: NSUnderlineStyle.single.rawValue,
                        range: range
                    )
                }
            }

            if let intent = attrs[.presentationIntent] as? PresentationIntent {
                applyBlockIntent(intent, paragraph: paragraph, sizeOverride: &sizeOverride, color: &color, mono: &mono)
                if headerLevel(from: intent) != nil {
                    weight = .bold
                    italic = false
                }
                if hasCodeBlock(intent) {
                    result.addAttribute(.backgroundColor, value: C.panel, range: range)
                }
            }

            if attrs[.link] != nil {
                color = C.accent
                result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }

            let font: UIFont
            if mono {
                font = Fonts.code(italic: italic)
            } else if let sizeOverride {
                font = sizeOverride
            } else {
                font = Fonts.body(weight: weight, italic: italic)
            }

            result.addAttribute(.font, value: font, range: range)
            result.addAttribute(.foregroundColor, value: color, range: range)
            result.addAttribute(.paragraphStyle, value: paragraph, range: range)
        }
    }

    private static func applyBlockIntent(
        _ intent: PresentationIntent,
        paragraph: NSMutableParagraphStyle,
        sizeOverride: inout UIFont?,
        color: inout UIColor,
        mono: inout Bool
    ) {
        if let level = headerLevel(from: intent) {
            sizeOverride = Fonts.heading(level: level)
            paragraph.paragraphSpacingBefore = level == 1 ? 4 : 14
            paragraph.paragraphSpacing = 10
        }

        let listDepth = intent.components.filter { component in
            switch component.kind {
            case .unorderedList, .orderedList: return true
            default: return false
            }
        }.count

        if listDepth > 0 {
            let indent = CGFloat(listDepth) * 20
            paragraph.firstLineHeadIndent = indent
            paragraph.headIndent = indent + 18
            paragraph.paragraphSpacing = 4
        }

        for component in intent.components {
            switch component.kind {
            case .codeBlock:
                mono = true
                color = C.textPrimary
                paragraph.paragraphSpacing = 12
                paragraph.lineSpacing = 2
            case .blockQuote:
                color = C.textSecondary
                paragraph.firstLineHeadIndent = max(paragraph.firstLineHeadIndent, 16)
                paragraph.headIndent = max(paragraph.headIndent, 16)
            case .thematicBreak:
                color = C.textSecondary
            default:
                break
            }
        }
    }

    private static func hasCodeBlock(_ intent: PresentationIntent) -> Bool {
        intent.components.contains { component in
            if case .codeBlock = component.kind { return true }
            return false
        }
    }

    private static func headerLevel(from intent: PresentationIntent) -> Int? {
        for component in intent.components {
            if case .header(let level) = component.kind { return level }
        }
        return nil
    }

    // MARK: - List markers
    // `.full` syntax strips "-", "*", and "1." — reinsert visible bullets/numbers
    // at the start of each list item identity.

    private static func insertListMarkers(into result: NSMutableAttributedString) {
        var firstLocationByIdentity: [Int: (location: Int, prefix: String)] = [:]
        let full = NSRange(location: 0, length: result.length)

        result.enumerateAttribute(.presentationIntent, in: full, options: []) { value, range, _ in
            guard let intent = value as? PresentationIntent,
                  let item = listItemComponent(from: intent) else { return }

            let prefix: String
            if isOrdered(intent), case .listItem(let ordinal) = item.kind {
                prefix = "\(ordinal). "
            } else {
                prefix = "• "
            }

            if let existing = firstLocationByIdentity[item.identity] {
                if range.location < existing.location {
                    firstLocationByIdentity[item.identity] = (range.location, prefix)
                }
            } else {
                firstLocationByIdentity[item.identity] = (range.location, prefix)
            }
        }

        let insertions = firstLocationByIdentity.values.sorted { $0.location > $1.location }
        for insertion in insertions {
            let location = min(insertion.location, result.length)
            let attrs: [NSAttributedString.Key: Any]
            if result.length > 0 {
                attrs = result.attributes(at: min(location, result.length - 1), effectiveRange: nil)
            } else {
                attrs = [:]
            }
            result.insert(NSAttributedString(string: insertion.prefix, attributes: attrs), at: location)
        }
    }

    private static func listItemComponent(from intent: PresentationIntent) -> PresentationIntent.IntentComponent? {
        intent.components.first { component in
            if case .listItem = component.kind { return true }
            return false
        }
    }

    private static func isOrdered(_ intent: PresentationIntent) -> Bool {
        intent.components.contains { component in
            if case .orderedList = component.kind { return true }
            return false
        }
    }
}
