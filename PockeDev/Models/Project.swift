import Foundation

// MARK: - Project (ARCHITECTURE.md: Data Models)

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    /// Sandbox projects store the folder name only (resolved under Documents at
    /// runtime so container UUID changes survive). Folders opened via the
    /// document picker store an absolute path.
    let rootPath: String
    let createdAt: Date
    /// Live URL from this session (including security scope from the picker).
    /// Nil after Codable decode — sandbox projects then resolve via Documents.
    let sessionRootURL: URL?

    var rootURL: URL {
        if let sessionRootURL { return sessionRootURL }
        if rootPath.hasPrefix("/") {
            return URL(fileURLWithPath: rootPath, isDirectory: true)
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(rootPath, isDirectory: true)
    }

    init(id: UUID = UUID(), name: String, rootURL: URL) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.sessionRootURL = rootURL
        if Self.isInsideDocuments(rootURL) {
            self.rootPath = rootURL.lastPathComponent
        } else {
            self.rootPath = rootURL.standardizedFileURL.path
        }
    }

    private static func isInsideDocuments(_ url: URL) -> Bool {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let candidate = url.standardizedFileURL.resolvingSymlinksInPath()
        let docsPath = docs.path
        let candidatePath = candidate.path
        return candidatePath == docsPath || candidatePath.hasPrefix(docsPath + "/")
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, rootPath, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        rootPath = try container.decode(String.self, forKey: .rootPath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        sessionRootURL = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(rootPath, forKey: .rootPath)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
