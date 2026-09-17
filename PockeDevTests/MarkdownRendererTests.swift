import XCTest
import UIKit
@testable import PockeDev

final class MarkdownRendererTests: XCTestCase {

    func testEmptyInputReturnsEmptyString() {
        let result = MarkdownRenderer.render("")
        XCTAssertEqual(result.string, "")
        XCTAssertEqual(result.length, 0)
    }

    func testHeadingStripsHashAndUsesLargerBoldFont() {
        let result = MarkdownRenderer.render("# Hello")
        XCTAssertEqual(result.string.trimmingCharacters(in: .whitespacesAndNewlines), "Hello")
        XCTAssertFalse(result.string.contains("#"))

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertGreaterThan(font?.pointSize ?? 0, 16)
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)

        let level = result.attribute(
            NSAttributedString.Key(UIAccessibilitySpeechAttributeHeadingLevel),
            at: 0,
            effectiveRange: nil
        ) as? NSNumber
        XCTAssertEqual(level?.intValue, 1)
    }

    func testStrongEmphasisStripsAsterisksAndBolds() {
        let result = MarkdownRenderer.render("**Bold**")
        XCTAssertEqual(result.string.trimmingCharacters(in: .whitespacesAndNewlines), "Bold")
        XCTAssertFalse(result.string.contains("*"))

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    func testInlineCodeStripsBackticksAndUsesMonospace() {
        let result = MarkdownRenderer.render("`code`")
        XCTAssertEqual(result.string.trimmingCharacters(in: .whitespacesAndNewlines), "code")
        XCTAssertFalse(result.string.contains("`"))

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
    }

    func testLinkAttachesHTTPSURL() {
        let result = MarkdownRenderer.render("[Hi](https://example.com)")
        XCTAssertTrue(result.string.contains("Hi"))
        let link = result.attribute(.link, at: 0, effectiveRange: nil)
        let url = link as? URL ?? (link as? String).flatMap(URL.init(string:))
        XCTAssertEqual(url?.host, "example.com")
    }

    func testJavascriptAndFileLinksAreNotTappable() {
        XCTAssertNil(MarkdownRenderer.sanitizedLink(from: "javascript:alert(1)"))
        XCTAssertNil(MarkdownRenderer.sanitizedLink(from: "file:///etc/passwd"))
        XCTAssertNil(MarkdownRenderer.sanitizedLink(from: "data:text/html,hi"))
        XCTAssertNil(MarkdownRenderer.sanitizedLink(from: "../readme.md"))
        XCTAssertNotNil(MarkdownRenderer.sanitizedLink(from: "https://example.com"))
        XCTAssertNotNil(MarkdownRenderer.sanitizedLink(from: "mailto:a@b.c"))

        let result = MarkdownRenderer.render("[x](javascript:alert(1))")
        XCTAssertTrue(result.string.contains("x"))
        XCTAssertNil(result.attribute(.link, at: 0, effectiveRange: nil))
    }

    func testListItemsAreVisibleWithoutMarkdownDashes() {
        let result = MarkdownRenderer.render("- alpha\n- beta")
        XCTAssertTrue(result.string.contains("alpha"))
        XCTAssertTrue(result.string.contains("beta"))
        XCTAssertFalse(result.string.contains("- alpha"))
        XCTAssertTrue(result.string.contains("•"))
        XCTAssertFalse(result.string.contains("alpha•"))
        XCTAssertTrue(result.string.contains("alpha\n"))
        XCTAssertTrue(result.string.contains("List item 1 of 2."))
        let style = result.attribute(.paragraphStyle, at: (result.string as NSString).range(of: "alpha").location, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertGreaterThan(style?.headIndent ?? 0, 0)
    }

    func testNestedListIncreasesIndent() {
        let result = MarkdownRenderer.render("- outer\n  - inner")
        let ns = result.string as NSString
        let outer = ns.range(of: "outer")
        let inner = ns.range(of: "inner")
        XCTAssertNotEqual(outer.location, NSNotFound)
        XCTAssertNotEqual(inner.location, NSNotFound)
        let outerStyle = result.attribute(.paragraphStyle, at: outer.location, effectiveRange: nil) as? NSParagraphStyle
        let innerStyle = result.attribute(.paragraphStyle, at: inner.location, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertGreaterThan(innerStyle?.headIndent ?? 0, outerStyle?.headIndent ?? 0)
    }

    func testBlockQuoteUsesSecondaryColorAndIndent() {
        let result = MarkdownRenderer.render("> quoted")
        XCTAssertTrue(result.string.contains("quoted"))
        let ns = result.string as NSString
        let range = ns.range(of: "quoted")
        let color = result.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, Tokens.UIColor.textSecondary)
        let style = result.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertGreaterThanOrEqual(style?.headIndent ?? 0, 16)
    }

    func testTableSeparatesCellsAndBoldsHeader() {
        let result = MarkdownRenderer.render("| a | b |\n| - | - |\n| 1 | 2 |")
        XCTAssertTrue(result.string.contains("│"))
        XCTAssertTrue(result.string.contains("a"))
        XCTAssertTrue(result.string.contains("1"))
        let ns = result.string as NSString
        let header = ns.range(of: "a")
        let font = result.attribute(.font, at: header.location, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    func testPlainParagraphKeepsText() {
        let result = MarkdownRenderer.render("Just a sentence.")
        XCTAssertEqual(result.string.trimmingCharacters(in: .whitespacesAndNewlines), "Just a sentence.")
    }

    func testHeadingAndFollowingBlocksAreNotConcatenated() {
        let result = MarkdownRenderer.render("# Coach\n\n## Role\n\nYou are my coach.")
        XCTAssertFalse(result.string.contains("CoachRole"))
        XCTAssertFalse(result.string.contains("RoleYou"))
        XCTAssertTrue(result.string.contains("Coach\n"))
        XCTAssertTrue(result.string.contains("Role\n"))
        XCTAssertTrue(result.string.contains("You are my coach."))
    }

    func testThematicBreakUsesAttachment() {
        let result = MarkdownRenderer.render("before\n\n---\n\nafter")
        XCTAssertTrue(result.string.contains("before"))
        XCTAssertTrue(result.string.contains("after"))
        XCTAssertFalse(result.string.contains("beforeafter"))
        var foundAttachment = false
        result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if value is NSTextAttachment { foundAttachment = true }
        }
        XCTAssertTrue(foundAttachment)
    }

    func testFencedCodeBlockKeepsSourceAndUsesMonospace() {
        let result = MarkdownRenderer.render("Intro\n\n```swift\nlet x = 1\n```\n\nOutro")
        XCTAssertTrue(result.string.contains("let x = 1"))
        XCTAssertFalse(result.string.contains("Introlet"))
        XCTAssertFalse(result.string.contains("```"))

        guard let range = result.string.range(of: "let x = 1") else {
            return XCTFail("code text missing")
        }
        let nsRange = NSRange(range, in: result.string)
        let font = result.attribute(.font, at: nsRange.location, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
    }

    func testFenceInfoStringMapsJavascript() {
        XCTAssertEqual(SyntaxHighlighter.language(forFenceInfo: "javascript"), .javascript)
        XCTAssertEqual(SyntaxHighlighter.language(forFenceInfo: "js"), .javascript)
        XCTAssertEqual(SyntaxHighlighter.language(forFenceInfo: nil), .plain)
    }

    func testOrderedListUsesNumbers() {
        let result = MarkdownRenderer.render("1. first\n2. second")
        XCTAssertTrue(result.string.contains("1. first"))
        XCTAssertTrue(result.string.contains("2. second"))
        XCTAssertTrue(result.string.contains("first\n"))
    }

    func testStrikethroughAndTaskList() {
        let strike = MarkdownRenderer.render("~~gone~~")
        let ns = strike.string as NSString
        let range = ns.range(of: "gone")
        let style = strike.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil) as? Int
        XCTAssertEqual(style, NSUnderlineStyle.single.rawValue)

        let tasks = MarkdownRenderer.render("- [x] done\n- [ ] todo")
        XCTAssertTrue(tasks.string.contains("☑"))
        XCTAssertTrue(tasks.string.contains("☐"))
        XCTAssertTrue(tasks.string.contains("Checked."))
        XCTAssertTrue(tasks.string.contains("Not checked."))
    }

    func testOversizeDocumentIsTruncatedAndStillParsesPrefix() {
        let prefix = "# Title\n\n"
        let filler = String(repeating: "a", count: MarkdownRenderer.maxPreviewUTF16Count)
        let markdown = prefix + filler
        XCTAssertGreaterThan(markdown.utf16.count, MarkdownRenderer.maxPreviewUTF16Count)

        let result = MarkdownRenderer.render(markdown)
        XCTAssertTrue(result.string.contains("Preview truncated"))
        XCTAssertTrue(result.string.contains("Title"))
        XCTAssertFalse(result.string.contains("# Title"))
        XCTAssertLessThan(result.string.utf16.count, markdown.utf16.count)

        let justUnder = String(repeating: "b", count: MarkdownRenderer.maxPreviewUTF16Count)
        let under = MarkdownRenderer.render(justUnder)
        XCTAssertFalse(under.string.contains("Preview truncated"))
        XCTAssertEqual(under.string.trimmingCharacters(in: .whitespacesAndNewlines), justUnder)
    }

    func testTenKilobyteDocumentKeepsStructure() {
        var markdown = ""
        var n = 0
        while markdown.utf8.count < 10_000 {
            markdown += """
            # Personal Engineering Discipline \(n)

            ## Role

            You are my personal **engineering discipline**, operational *awareness*, and self-development coach.

            You help me strengthen:
            - Engineering discipline
            - Operational awareness with `code`

            See [docs](https://example.com/path).

            ```swift
            let value = \(n)
            ```

            ---\n\n
            """
            n += 1
        }

        let result = MarkdownRenderer.render(markdown)
        XCTAssertTrue(result.string.contains("Personal Engineering Discipline 0"))
        XCTAssertTrue(result.string.contains("let value = 0"))
        XCTAssertTrue(result.string.contains("•"))
        XCTAssertFalse(result.string.contains("# Personal"))
        let highlighted = SyntaxHighlighter.highlight(text: markdown, language: .markdown)
        XCTAssertEqual(highlighted.length, (markdown as NSString).length)
    }
}
