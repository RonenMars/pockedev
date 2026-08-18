import Foundation
import Markdown
import UIKit

// MARK: - MarkdownRenderer
// Converts Markdown source into a dark-theme NSAttributedString using swift-markdown
// (cmark-gfm). The parser yields a Markup tree; this renderer walks it and applies
// GitHub-like preview styles for a read-only editor preview.

enum MarkdownRenderer {

    private static let maxPreviewUTF16Count = 100_000

    static func render(_ markdown: String) -> NSAttributedString {
        guard !markdown.isEmpty else { return NSAttributedString() }

        if markdown.utf16.count > maxPreviewUTF16Count {
            return plain(markdown)
        }

        var visitor = PreviewVisitor()
        return visitor.visit(Document(parsing: markdown))
    }

    // MARK: - Colors / fonts (match Tokens.swift)

    fileprivate enum C {
        static let textPrimary   = UIColor(red: 0.90, green: 0.93, blue: 0.95, alpha: 1) // #E6EDF3
        static let textSecondary = UIColor(red: 0.62, green: 0.65, blue: 0.70, alpha: 1) // #9DA7B3
        static let accent        = UIColor(red: 0.23, green: 0.74, blue: 1.00, alpha: 1) // #3ABEFF
        static let panel         = UIColor(red: 0.10, green: 0.13, blue: 0.18, alpha: 1) // #1A222D
        static let rule          = UIColor(red: 0.30, green: 0.35, blue: 0.42, alpha: 1)
    }

    fileprivate enum Fonts {
        static let bodySize: CGFloat = 16
        static let codeSize: CGFloat = 14

        static func body(weight: UIFont.Weight = .regular, italic: Bool = false) -> UIFont {
            styled(UIFont.systemFont(ofSize: bodySize, weight: weight), italic: italic)
        }

        static func heading(level: Int) -> UIFont {
            let sizes: [CGFloat] = [32, 24, 20, 16, 14, 13]
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

    fileprivate static func plain(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: Fonts.body(),
                .foregroundColor: C.textPrimary
            ]
        )
    }

    fileprivate static func highlightedCode(
        _ text: String,
        languageHint: String?,
        paragraphStyle: NSParagraphStyle
    ) -> NSAttributedString {
        let language = SyntaxHighlighter.language(for: languageHint ?? "")
        let highlighted = SyntaxHighlighter.highlight(text: text, language: language)
        let full = NSRange(location: 0, length: highlighted.length)
        highlighted.addAttribute(.paragraphStyle, value: paragraphStyle, range: full)
        highlighted.addAttribute(.backgroundColor, value: C.panel, range: full)
        return highlighted
    }

    fileprivate static func horizontalRule(paragraphStyle: NSParagraphStyle) -> NSAttributedString {
        let attachment = HorizontalRuleAttachment()
        attachment.image = ruleImage
        let result = NSMutableAttributedString(attachment: attachment)
        result.addAttributes(
            [
                .foregroundColor: C.rule,
                .paragraphStyle: paragraphStyle
            ],
            range: NSRange(location: 0, length: result.length)
        )
        return result
    }

    private static let ruleImage: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { ctx in
            C.rule.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }()

    fileprivate final class HorizontalRuleAttachment: NSTextAttachment {
        override func attachmentBounds(
            for textContainer: NSTextContainer?,
            proposedLineFragment lineFrag: CGRect,
            glyphPosition position: CGPoint,
            characterIndex charIndex: Int
        ) -> CGRect {
            CGRect(x: 0, y: -2, width: max(lineFrag.width, 1), height: 1)
        }
    }
}

// MARK: - PreviewVisitor

private struct PreviewVisitor: MarkupVisitor {
    typealias Result = NSAttributedString

    private struct Style {
        var headingLevel: Int?
        var listDepth = 0
        var ordered = false
        var quoteDepth = 0
        var inTableHeader = false
        var weight: UIFont.Weight = .regular
        var italic = false
        var mono = false
        var strikethrough = false
        var link: URL?
        var isFirstBlock = true
    }

    private var style = Style()

    mutating func defaultVisit(_ markup: Markup) -> NSAttributedString {
        visitChildren(markup)
    }

    mutating func visitDocument(_ document: Document) -> NSAttributedString {
        joinBlocks(document, marksFirst: true)
    }

    mutating func visitHeading(_ heading: Heading) -> NSAttributedString {
        let previous = style.headingLevel
        style.headingLevel = heading.level
        defer { style.headingLevel = previous }
        return styledBlock(visitChildren(heading))
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
        styledBlock(visitChildren(paragraph))
    }

    mutating func visitText(_ text: Text) -> NSAttributedString {
        NSAttributedString(string: text.string, attributes: attributes())
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> NSAttributedString {
        NSAttributedString(string: " ", attributes: attributes())
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> NSAttributedString {
        NSAttributedString(string: "\n", attributes: attributes())
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> NSAttributedString {
        let previous = (style.mono, style.weight)
        style.mono = true
        style.weight = .regular
        defer {
            style.mono = previous.0
            style.weight = previous.1
        }
        return NSAttributedString(string: inlineCode.code, attributes: attributes())
    }

    mutating func visitStrong(_ strong: Strong) -> NSAttributedString {
        let previous = style.weight
        style.weight = .bold
        defer { style.weight = previous }
        return visitChildren(strong)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> NSAttributedString {
        let previous = style.italic
        style.italic = true
        defer { style.italic = previous }
        return visitChildren(emphasis)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> NSAttributedString {
        let previous = style.strikethrough
        style.strikethrough = true
        defer { style.strikethrough = previous }
        return visitChildren(strikethrough)
    }

    mutating func visitLink(_ link: Link) -> NSAttributedString {
        let previous = style.link
        style.link = link.destination.flatMap(URL.init(string:))
        defer { style.link = previous }
        return visitChildren(link)
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> NSAttributedString {
        NSAttributedString(string: inlineHTML.rawHTML, attributes: attributes())
    }

    mutating func visitImage(_ image: Image) -> NSAttributedString {
        let alt = visitChildren(image)
        if alt.length > 0 { return alt }
        return NSAttributedString(string: image.source ?? "", attributes: attributes())
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> NSAttributedString {
        visitList(unorderedList, ordered: false)
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> NSAttributedString {
        visitList(orderedList, ordered: true)
    }

    mutating func visitListItem(_ listItem: ListItem) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var isFirstChild = true
        for child in listItem.children {
            let piece = visit(child)
            guard piece.length > 0 else { continue }
            if result.length > 0 {
                result.append(newline(matching: result))
            }
            let mutable = NSMutableAttributedString(attributedString: piece)
            if isFirstChild {
                let prefix = listPrefix(for: listItem)
                let prefixAttrs = mutable.length > 0
                    ? mutable.attributes(at: 0, effectiveRange: nil)
                    : attributes()
                mutable.insert(NSAttributedString(string: prefix, attributes: prefixAttrs), at: 0)
                isFirstChild = false
            }
            result.append(mutable)
        }
        return result
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        let text = codeBlock.code.trimmingCharacters(in: .newlines)
        return MarkdownRenderer.highlightedCode(
            text,
            languageHint: codeBlock.language,
            paragraphStyle: paragraphStyle(codeBlock: true)
        )
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSAttributedString {
        MarkdownRenderer.horizontalRule(paragraphStyle: paragraphStyle(thematicBreak: true))
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSAttributedString {
        style.quoteDepth += 1
        defer { style.quoteDepth -= 1 }
        return joinBlocks(blockQuote)
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> NSAttributedString {
        let previous = style.mono
        style.mono = true
        defer { style.mono = previous }
        return styledBlock(NSMutableAttributedString(string: html.rawHTML.trimmingCharacters(in: .newlines), attributes: attributes()))
    }

    mutating func visitTable(_ table: Table) -> NSAttributedString {
        joinBlocks(table)
    }

    mutating func visitTableHead(_ tableHead: Table.Head) -> NSAttributedString {
        style.inTableHeader = true
        defer { style.inTableHeader = false }
        return visitTableRowCells(tableHead)
    }

    mutating func visitTableBody(_ tableBody: Table.Body) -> NSAttributedString {
        joinBlocks(tableBody)
    }

    mutating func visitTableRow(_ tableRow: Table.Row) -> NSAttributedString {
        visitTableRowCells(tableRow)
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) -> NSAttributedString {
        visitChildren(tableCell)
    }

    // MARK: - Helpers

    private mutating func visitList(_ markup: Markup, ordered: Bool) -> NSAttributedString {
        let previous = (style.listDepth, style.ordered)
        style.listDepth += 1
        style.ordered = ordered
        defer {
            style.listDepth = previous.0
            style.ordered = previous.1
        }
        return joinBlocks(markup)
    }

    private mutating func visitChildren(_ markup: Markup) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            result.append(visit(child))
        }
        return result
    }

    private mutating func joinBlocks(_ markup: Markup, marksFirst: Bool = false) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            let piece = visit(child)
            if marksFirst { style.isFirstBlock = false }
            guard piece.length > 0 else { continue }
            if result.length > 0 {
                result.append(newline(matching: result))
            }
            result.append(piece)
        }
        return result
    }

    private mutating func visitTableRowCells(_ markup: Markup) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            if result.length > 0 {
                result.append(NSAttributedString(string: "  │  ", attributes: attributes()))
            }
            result.append(visit(child))
        }
        return styledBlock(NSMutableAttributedString(attributedString: result))
    }

    private func listPrefix(for item: ListItem) -> String {
        if let checkbox = item.checkbox {
            return checkbox == .checked ? "☑ " : "☐ "
        }
        if style.ordered, let parent = item.parent as? OrderedList {
            return "\(parent.startIndex + UInt(item.indexInParent)). "
        }
        return "• "
    }

    private func styledBlock(_ content: NSMutableAttributedString) -> NSAttributedString {
        guard content.length > 0 else { return content }
        content.addAttribute(
            .paragraphStyle,
            value: paragraphStyle(),
            range: NSRange(location: 0, length: content.length)
        )
        return content
    }

    private func newline(matching result: NSAttributedString) -> NSAttributedString {
        let attrs = result.length > 0
            ? result.attributes(at: result.length - 1, effectiveRange: nil)
            : attributes()
        return NSAttributedString(string: "\n", attributes: attrs)
    }

    private func attributes() -> [NSAttributedString.Key: Any] {
        var color = MarkdownRenderer.C.textPrimary
        if style.quoteDepth > 0 { color = MarkdownRenderer.C.textSecondary }
        if style.link != nil { color = MarkdownRenderer.C.accent }

        let weight: UIFont.Weight = style.inTableHeader ? .semibold : style.weight
        let font: UIFont
        if style.mono {
            font = MarkdownRenderer.Fonts.code(italic: style.italic)
        } else if let level = style.headingLevel {
            font = MarkdownRenderer.Fonts.heading(level: level)
        } else {
            font = MarkdownRenderer.Fonts.body(weight: weight, italic: style.italic)
        }

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle()
        ]
        if style.mono {
            attrs[.backgroundColor] = MarkdownRenderer.C.panel
        }
        if let link = style.link {
            attrs[.link] = link
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if style.strikethrough {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        return attrs
    }

    private func paragraphStyle(codeBlock: Bool = false, thematicBreak: Bool = false) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = codeBlock ? 2 : 3
        paragraph.paragraphSpacing = 10

        if let level = style.headingLevel {
            paragraph.paragraphSpacingBefore = style.isFirstBlock ? 0 : (level <= 2 ? 18 : 14)
            paragraph.paragraphSpacing = 10
        }

        if style.listDepth > 0 {
            let nest = CGFloat(max(style.listDepth - 1, 0)) * 22
            let markerWidth: CGFloat = style.ordered ? 28 : 18
            paragraph.firstLineHeadIndent = nest
            paragraph.headIndent = nest + markerWidth
            paragraph.paragraphSpacing = 4
            paragraph.paragraphSpacingBefore = 0
        }

        if style.quoteDepth > 0 {
            let quoteIndent = CGFloat(style.quoteDepth) * 16
            paragraph.firstLineHeadIndent = max(paragraph.firstLineHeadIndent, quoteIndent)
            paragraph.headIndent = max(paragraph.headIndent, quoteIndent)
        }

        if codeBlock {
            paragraph.paragraphSpacing = 12
            paragraph.paragraphSpacingBefore = style.isFirstBlock ? 0 : 8
        }

        if thematicBreak {
            paragraph.paragraphSpacingBefore = style.isFirstBlock ? 0 : 12
            paragraph.paragraphSpacing = 12
        }

        return paragraph
    }
}
