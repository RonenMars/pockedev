import XCTest
@testable import PockeDev

final class FileServiceTests: XCTestCase {

    private let fileManager = FileManager.default
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("FileServiceTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: tempDir)
    }

    func testListItemsReturnsFoldersThenFiles() throws {
        try fileManager.createDirectory(
            at: tempDir.appendingPathComponent("src", isDirectory: true),
            withIntermediateDirectories: false
        )
        fileManager.createFile(
            atPath: tempDir.appendingPathComponent("README.md").path,
            contents: Data("# hi\n".utf8)
        )

        let items = try FileService().listItems(in: tempDir)

        XCTAssertEqual(items.map(\.name), ["src", "README.md"])
        XCTAssertTrue(items[0].isDirectory)
        XCTAssertFalse(items[1].isDirectory)
    }

    func testListItemsThrowsWhenDirectoryDoesNotExist() {
        let missing = tempDir.appendingPathComponent("no-such-folder", isDirectory: true)

        XCTAssertThrowsError(try FileService().listItems(in: missing)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
            XCTAssertEqual(nsError.code, NSFileReadNoSuchFileError)
        }
    }
}
