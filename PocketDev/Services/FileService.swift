import Foundation

// MARK: - FileService (ARCHITECTURE.md: Modules)
// Local-only file I/O. No Git / SSH / AI (Phase 1).
// Security-scoped resource access is required for URLs obtained via
// UIDocumentPickerViewController (files/folders outside the app sandbox).
// startAccessingSecurityScopedResource() returns false for in-sandbox URLs
// and is a safe no-op in that case.

final class FileService: @unchecked Sendable {
    private let fileManager = FileManager.default

    // MARK: - Directory listing

    /// Returns the immediate children of `directory`, sorted: folders first, then files.
    func listItems(in directory: URL) throws -> [FileItem] {
        let accessed = directory.startAccessingSecurityScopedResource()
        defer { if accessed { directory.stopAccessingSecurityScopedResource() } }

        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: .skipsHiddenFiles
        )
        return urls
            .map { url in
                var isDir: ObjCBool = false
                fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
                return FileItem(url: url, isDirectory: isDir.boolValue)
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    // MARK: - Read / write

    func readFile(at url: URL) throws -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        return try String(contentsOf: url, encoding: .utf8)
    }

    func writeFile(at url: URL, content: String) throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Create / Delete

    func createFile(at url: URL) throws {
        guard !fileManager.fileExists(atPath: url.path) else {
            throw FileServiceError.alreadyExists
        }
        guard fileManager.createFile(atPath: url.path, contents: nil) else {
            throw FileServiceError.createFailed
        }
    }

    func createDirectory(at url: URL) throws {
        guard !fileManager.fileExists(atPath: url.path) else {
            throw FileServiceError.alreadyExists
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
    }

    func deleteItem(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    func moveItem(from source: URL, to destinationDir: URL) throws {
        let dest = destinationDir.appendingPathComponent(source.lastPathComponent)
        guard !fileManager.fileExists(atPath: dest.path) else {
            throw FileServiceError.alreadyExists
        }
        try fileManager.moveItem(at: source, to: dest)
    }

    func copyItem(from source: URL, to destinationDir: URL) throws {
        let dest = destinationDir.appendingPathComponent(source.lastPathComponent)
        guard !fileManager.fileExists(atPath: dest.path) else {
            throw FileServiceError.alreadyExists
        }
        try fileManager.copyItem(at: source, to: dest)
    }

    func allDirectories(in root: URL, depth: Int = 0) -> [DirectoryItem] {
        let items = (try? listItems(in: root)) ?? []
        var result: [DirectoryItem] = []
        for item in items where item.isDirectory {
            result.append(DirectoryItem(url: item.url, depth: depth))
            result += allDirectories(in: item.url, depth: depth + 1)
        }
        return result
    }
}

// MARK: - FileServiceError

enum FileServiceError: LocalizedError {
    case alreadyExists
    case createFailed

    var errorDescription: String? {
        switch self {
        case .alreadyExists: return "A file or folder with that name already exists."
        case .createFailed:  return "Could not create the file."
        }
    }
}

// MARK: - DirectoryItem

struct DirectoryItem: Identifiable {
    var id: URL { url }
    let url: URL
    let depth: Int
    var name: String { url.lastPathComponent }
}

// MARK: - FileItem

struct FileItem: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let isDirectory: Bool

    var name: String { url.lastPathComponent }
    var ext: String { url.pathExtension }
}
