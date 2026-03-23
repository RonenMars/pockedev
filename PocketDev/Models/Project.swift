import Foundation

// MARK: - Project (ARCHITECTURE.md: Data Models)

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let rootPath: String        // stored as path string for Codable simplicity
    let createdAt: Date

    var rootURL: URL { URL(fileURLWithPath: rootPath) }

    init(id: UUID = UUID(), name: String, rootURL: URL) {
        self.id = id
        self.name = name
        self.rootPath = rootURL.path
        self.createdAt = Date()
    }
}
