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
    }

    func testPlainParagraphKeepsText() {
        let result = MarkdownRenderer.render("Just a sentence.")
        XCTAssertEqual(result.string.trimmingCharacters(in: .whitespacesAndNewlines), "Just a sentence.")
    }
}
