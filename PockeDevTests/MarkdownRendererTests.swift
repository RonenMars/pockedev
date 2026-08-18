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

    func testLinkAttachesURL() {
        let result = MarkdownRenderer.render("[Hi](https://example.com)")
        XCTAssertTrue(result.string.contains("Hi"))
        let link = result.attribute(.link, at: 0, effectiveRange: nil)
        let url = link as? URL ?? (link as? String).flatMap(URL.init(string:))
        XCTAssertEqual(url?.host, "example.com")
    }

    func testListItemsAreVisibleWithoutMarkdownDashes() {
        let result = MarkdownRenderer.render("- alpha\n- beta")
        XCTAssertTrue(result.string.contains("alpha"))
        XCTAssertTrue(result.string.contains("beta"))
        XCTAssertFalse(result.string.contains("- alpha"))
        XCTAssertTrue(result.string.contains("•"))
        XCTAssertFalse(result.string.contains("alpha•"))
        XCTAssertTrue(result.string.contains("alpha\n"))
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

    func testThematicBreakSeparatesParagraphs() {
        let result = MarkdownRenderer.render("before\n\n---\n\nafter")
        XCTAssertTrue(result.string.contains("before"))
        XCTAssertTrue(result.string.contains("after"))
        XCTAssertFalse(result.string.contains("beforeafter"))
        XCTAssertFalse(result.string.contains("before⸻after"))
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

    func testOrderedListUsesNumbers() {
        let result = MarkdownRenderer.render("1. first\n2. second")
        XCTAssertTrue(result.string.contains("1. first"))
        XCTAssertTrue(result.string.contains("2. second"))
        XCTAssertTrue(result.string.contains("first\n"))
    }

    func testTenKilobyteDocumentRendersInUnder250ms() {
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

        let start = CFAbsoluteTimeGetCurrent()
        let result = MarkdownRenderer.render(markdown)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertGreaterThan(result.length, 0)
        XCTAssertLessThan(elapsed, 0.25, "10KB markdown preview took \(elapsed)s")

        let highlightStart = CFAbsoluteTimeGetCurrent()
        _ = SyntaxHighlighter.highlight(text: markdown, language: .markdown)
        let highlightElapsed = CFAbsoluteTimeGetCurrent() - highlightStart
        XCTAssertLessThan(highlightElapsed, 0.05, "10KB markdown highlight took \(highlightElapsed)s")
    }
}
