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
}

// MARK: - FileItem

struct FileItem: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let isDirectory: Bool

    var name: String { url.lastPathComponent }
    var ext: String { url.pathExtension }
}
