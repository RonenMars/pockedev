import Foundation

// MARK: - DocumentSession (ARCHITECTURE.md: Data Models)
// Represents one open file tab.
// Explicit states: loading, dirty, error (DESIGN.md §10.2)

struct DocumentSession: Identifiable {
    let id: UUID
    let fileURL: URL
    var content: String
    var isDirty: Bool
    var isLoading: Bool
    var error: String?

    var fileName: String { fileURL.lastPathComponent }

    init(fileURL: URL) {
        self.id = UUID()
        self.fileURL = fileURL
        self.content = ""
        self.isDirty = false
        self.isLoading = true
        self.error = nil
    }
}
