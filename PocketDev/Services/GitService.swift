import Foundation
import Gitty

// MARK: - Protocol

protocol GitCloning {
    func cloneRepository(
        from remoteURL: URL,
        to localURL: URL,
        token: String,
        progress: @escaping (Double) -> Void
    ) async throws
}

// MARK: - GitCloneService

actor GitCloneService: GitCloning {
    func cloneRepository(
        from remoteURL: URL,
        to localURL: URL,
        token: String,
        progress: @escaping (Double) -> Void
    ) async throws {
        let credentials: Credentials = token.isEmpty ? .default : .token(token)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = try await Repository.clone(
                    from: remoteURL,
                    to: localURL,
                    credentials: credentials,
                    progress: { progress($0.fractionCompleted) }
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 60_000_000_000)
                throw GitCloneError.timedOut
            }
            try await group.next()
            group.cancelAll()
        }
    }
}

// MARK: - GitStatusFile

struct GitStatusFile: Sendable, Identifiable {
    var id: String { path }
    let path: String
    let statusType: StatusType

    enum StatusType: String, Sendable {
        case modified  = "M"
        case added     = "A"
        case deleted   = "D"
        case untracked = "?"
        case renamed   = "R"
    }
}

extension GitStatusFile.StatusType {
    init(_ status: StatusEntry.Status) {
        switch status {
        case .modified:       self = .modified
        case .added:          self = .added
        case .deleted:        self = .deleted
        case .untracked:      self = .untracked
        case .renamed(_):     self = .renamed
        case .typeChanged:    self = .modified
        }
    }
}

// MARK: - GitRepositoryService

struct GitRepositoryService: Sendable {
    let repoURL: URL

    func isGitRepository() -> Bool {
        Repository.exists(at: repoURL)
    }

    func changedFiles() throws -> [GitStatusFile] {
        let repo = try Repository.open(at: repoURL)
        return try repo.status().map { entry in
            GitStatusFile(path: entry.path, statusType: .init(entry.status))
        }
    }

    func commit(paths: [String], message: String, authorName: String, authorEmail: String) throws {
        let repo   = try Repository.open(at: repoURL)
        let author = Signature(name: authorName, email: authorEmail)
        try repo.stage(paths: paths)
        try repo.commit(message: message, author: author)
    }

    func push(token: String) async throws {
        let repo = try Repository.open(at: repoURL)
        try await repo.remotes.push(to: "origin", credentials: .token(token))
    }

    func currentBranch() -> String? {
        (try? Repository.open(at: repoURL))?.currentBranch
    }

    func pull(token: String) async throws {
        let repo = try Repository.open(at: repoURL)
        try await repo.remotes.fetch(named: "origin", credentials: .token(token))
        let branches = try repo.branches.list(type: .remote)
        guard let tracking = branches.first(where: { $0.name.hasSuffix("/\(repo.currentBranch ?? "main")") }) else {
            return
        }
        let result = try repo.merge(branch: tracking)
        switch result {
        case .conflict(let files):
            throw GitOperationError.commitFailed("Merge conflict in: \(files.map(\.path).joined(separator: ", "))")
        default:
            break
        }
    }
}
