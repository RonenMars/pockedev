import XCTest
@testable import PockeDev

final class DocumentSessionStoreTests: XCTestCase {

    func testMarkdownPreviewIsPerSessionAndClearedForOtherLanguages() {
        let store = DocumentSessionStore()
        let md = URL(fileURLWithPath: "/tmp/readme.md")
        let py = URL(fileURLWithPath: "/tmp/main.py")
        store.openFile(at: md)
        store.openFile(at: py)

        let mdID = store.sessions.first { $0.fileURL == md }!.id
        let pyID = store.sessions.first { $0.fileURL == py }!.id

        store.setMarkdownPreview(true, sessionID: mdID)
        XCTAssertEqual(store.sessions.first { $0.id == mdID }?.isMarkdownPreview, true)
        XCTAssertEqual(store.sessions.first { $0.id == pyID }?.isMarkdownPreview, false)

        store.setMarkdownPreview(true, sessionID: pyID)
        XCTAssertEqual(store.sessions.first { $0.id == pyID }?.isMarkdownPreview, false)

        store.setLanguage(.swift, sessionID: mdID)
        XCTAssertEqual(store.sessions.first { $0.id == mdID }?.isMarkdownPreview, false)
    }
}
