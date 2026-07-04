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
}
