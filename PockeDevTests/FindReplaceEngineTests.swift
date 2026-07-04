import XCTest
@testable import PockeDev

final class FindReplaceEngineTests: XCTestCase {

    // MARK: - Literal matching

    func testLiteralCaseInsensitiveMatches() {
        let r = FindReplaceEngine.matches(
            in: "Foo foo FOO", query: "foo", isRegex: false, caseSensitive: false
        )
        XCTAssertFalse(r.isInvalidRegex)
        XCTAssertEqual(r.ranges.count, 3)
        XCTAssertEqual(r.ranges[0], NSRange(location: 0, length: 3))
    }

    func testLiteralCaseSensitiveMatches() {
        let r = FindReplaceEngine.matches(
            in: "Foo foo FOO", query: "foo", isRegex: false, caseSensitive: true
        )
        XCTAssertEqual(r.ranges.count, 1)
        XCTAssertEqual(r.ranges[0], NSRange(location: 4, length: 3))
    }

    func testEmptyQueryReturnsNoMatches() {
        let r = FindReplaceEngine.matches(
            in: "anything", query: "", isRegex: false, caseSensitive: false
        )
        XCTAssertTrue(r.ranges.isEmpty)
        XCTAssertFalse(r.isInvalidRegex)
    }

    // MARK: - Regex matching

    func testRegexMatches() {
        let r = FindReplaceEngine.matches(
            in: "func alpha( func beta(", query: #"func (\w+)\("#,
            isRegex: true, caseSensitive: false
        )
        XCTAssertFalse(r.isInvalidRegex)
        XCTAssertEqual(r.ranges.count, 2)
    }

    func testInvalidRegexFlagged() {
        let r = FindReplaceEngine.matches(
            in: "func (", query: "func (", isRegex: true, caseSensitive: false
        )
        XCTAssertTrue(r.isInvalidRegex)
        XCTAssertTrue(r.ranges.isEmpty)
    }

    func testZeroWidthRegexMatchesExcluded() {
        // "a*" would match empty positions; those must not appear as ranges.
        let r = FindReplaceEngine.matches(
            in: "bbb", query: "a*", isRegex: true, caseSensitive: false
        )
        XCTAssertTrue(r.ranges.isEmpty)
    }

    // MARK: - Replace all

    func testReplaceAllLiteral() {
        let out = FindReplaceEngine.replaceAll(
            in: "foo foo", query: "foo", replacement: "bar",
            isRegex: false, caseSensitive: false
        )
        XCTAssertEqual(out, "bar bar")
    }

    func testReplaceAllRegexCaptureTemplate() {
        let out = FindReplaceEngine.replaceAll(
            in: "func alpha(", query: #"func (\w+)\("#, replacement: "func $1_impl(",
            isRegex: true, caseSensitive: false
        )
        XCTAssertEqual(out, "func alpha_impl(")
    }

    func testReplaceAllEmptyDeletes() {
        let out = FindReplaceEngine.replaceAll(
            in: "a-b-c", query: "-", replacement: "",
            isRegex: false, caseSensitive: false
        )
        XCTAssertEqual(out, "abc")
    }

    func testReplaceAllInvalidRegexReturnsUnchanged() {
        let out = FindReplaceEngine.replaceAll(
            in: "func (", query: "func (", replacement: "x",
            isRegex: true, caseSensitive: false
        )
        XCTAssertEqual(out, "func (")
    }

    // MARK: - Replace one

    func testReplaceOneLiteralAtRange() {
        let text = "foo foo"
        let secondFoo = NSRange(location: 4, length: 3)
        let out = FindReplaceEngine.replaceOne(
            in: text, matchRange: secondFoo, query: "foo", replacement: "bar", isRegex: false,
            caseSensitive: true
        )
        XCTAssertEqual(out, "foo bar")
    }

    func testReplaceOneRegexTemplateAtRange() {
        let text = "func alpha("
        let range = NSRange(location: 0, length: (text as NSString).length)
        let out = FindReplaceEngine.replaceOne(
            in: text, matchRange: range, query: #"func (\w+)\("#,
            replacement: "func $1_impl(", isRegex: true, caseSensitive: true
        )
        XCTAssertEqual(out, "func alpha_impl(")
    }

    func testReplaceOneRegexCaseInsensitive() {
        let text = "FUNC foo("
        let range = NSRange(location: 0, length: (text as NSString).length)
        let out = FindReplaceEngine.replaceOne(
            in: text, matchRange: range, query: #"func (\w+)\("#,
            replacement: "func $1_impl(", isRegex: true, caseSensitive: false
        )
        XCTAssertEqual(out, "func foo_impl(")
    }
}
