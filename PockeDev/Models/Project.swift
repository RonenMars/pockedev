import Foundation

// MARK: - Project (ARCHITECTURE.md: Data Models)

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let rootPath: String        // folder name only — full path is resolved at runtime to survive container UUID changes
    let createdAt: Date

    var rootURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(rootPath, isDirectory: true)
    }

    init(id: UUID = UUID(), name: String, rootURL: URL) {
        self.id = id
        self.name = name
        self.rootPath = rootURL.lastPathComponent
        self.createdAt = Date()
    }
}
