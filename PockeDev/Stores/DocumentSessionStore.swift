import Foundation
import Combine

// MARK: - DocumentSessionStore (ARCHITECTURE.md: Modules)
// Single source of truth for all open file sessions.
// Manages: open, activate, edit, save, close.

final class DocumentSessionStore: ObservableObject, @unchecked Sendable {
    @Published private(set) var sessions: [DocumentSession] = []
    @Published private(set) var activeSessionID: UUID?

    private let fileService = FileService()

    var activeSession: DocumentSession? {
        guard let id = activeSessionID else { return nil }
        return sessions.first { $0.id == id }
    }

    // MARK: - Open

    /// Open a file. If already open, just activates it.
    func openFile(at url: URL) {
        if let existing = sessions.first(where: { $0.fileURL == url }) {
            activeSessionID = existing.id
            return
        }

        let session = DocumentSession(fileURL: url)
        sessions.append(session)
        activeSessionID = session.id

        let id = session.id
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let content = try self.fileService.readFile(at: url)
                DispatchQueue.main.async {
                    self.mutate(id: id) {
                        $0.content = content
                        $0.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.mutate(id: id) {
                        $0.error = error.localizedDescription
                        $0.isLoading = false
                    }
                }
            }
        }
    }

    // MARK: - Activate

    func activate(id: UUID) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        activeSessionID = id
    }

    // MARK: - Edit

    func updateContent(_ content: String, sessionID: UUID) {
        mutate(id: sessionID) {
            $0.content = content
            $0.isDirty = true
        }
    }

    // MARK: - Save
    // Runs the file write on a background thread.
    // Clears isDirty only if content hasn't changed since save was initiated
    // (guards against marking clean when the user typed more during the write).

    func save(sessionID: UUID) async -> Result<Void, Error> {
        guard let session = sessions.first(where: { $0.id == sessionID }) else {
            return .failure(SessionError.notFound)
        }
        let url = session.fileURL
        let content = session.content
        let service = fileService
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try service.writeFile(at: url, content: content)
                    DispatchQueue.main.async { [weak self] in
                        self?.mutate(id: sessionID) {
                            if $0.content == content { $0.isDirty = false }
                        }
                        continuation.resume(returning: .success(()))
                    }
                } catch {
                    DispatchQueue.main.async {
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
        }
    }

    // MARK: - Close

    func close(id: UUID) {
        sessions.removeAll { $0.id == id }
        if activeSessionID == id {
            activeSessionID = sessions.last?.id
        }
    }

    // MARK: - Private

    private func mutate(id: UUID, transform: (inout DocumentSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        transform(&sessions[index])
    }
}

// MARK: - Errors

enum SessionError: LocalizedError {
    case notFound
    var errorDescription: String? { "Session not found." }
}
