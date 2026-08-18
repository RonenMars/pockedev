import XCTest
@testable import PockeDev

final class ProjectTests: XCTestCase {

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func testSandboxProjectResolvesUnderDocuments() {
        let url = documentsURL.appendingPathComponent("MyApp", isDirectory: true)
        let project = Project(name: "MyApp", rootURL: url)

        XCTAssertEqual(project.rootPath, "MyApp")
        XCTAssertEqual(
            project.rootURL.standardizedFileURL.path,
            url.standardizedFileURL.path
        )
    }

    func testExternalFolderURLIsPreserved() {
        let external = URL(fileURLWithPath: "/tmp/tech-design-skills-bundle", isDirectory: true)
        let project = Project(name: "tech-design-skills-bundle", rootURL: external)

        XCTAssertEqual(project.rootURL, external)
        XCTAssertNotEqual(
            project.rootURL.deletingLastPathComponent().standardizedFileURL.path,
            documentsURL.standardizedFileURL.path
        )
    }

    func testSandboxProjectSurvivesCodableRoundTrip() throws {
        let url = documentsURL.appendingPathComponent("KeepMe", isDirectory: true)
        let original = Project(name: "KeepMe", rootURL: url)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(decoded.rootPath, "KeepMe")
        XCTAssertEqual(
            decoded.rootURL.standardizedFileURL.path,
            url.standardizedFileURL.path
        )
    }
}
