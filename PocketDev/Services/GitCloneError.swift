import Foundation

// MARK: - GitOperationError

enum GitOperationError: LocalizedError {
    case notAGitRepository
    case noChangesToCommit
    case emptyCommitMessage
    case emptyToken
    case commitFailed(String)
    case pushFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAGitRepository:  return "This project is not a Git repository."
        case .noChangesToCommit:  return "No files selected to commit."
        case .emptyCommitMessage: return "Please enter a commit message."
        case .emptyToken:         return "Please enter a token to push."
        case .commitFailed(let m): return "Commit failed: \(m)"
        case .pushFailed(let m):   return "Push failed: \(m)"
        }
    }
}

// MARK: - GitCloneError

enum GitCloneError: LocalizedError {
    case invalidURL
    case authenticationFailed
    case repositoryNotFound
    case networkError(String)
    case destinationAlreadyExists
    case timedOut
    case cloneFailed(message: String)

    static func from(nsError: NSError) -> GitCloneError {
        let msg = nsError.localizedDescription
        let lower = msg.lowercased()
        if lower.contains("authentication") || lower.contains("credential") || lower.contains("401") || lower.contains("403") {
            return .authenticationFailed
        }
        if lower.contains("not found") || lower.contains("404") {
            return .repositoryNotFound
        }
        if lower.contains("network") || lower.contains("connection") || lower.contains("resolve host") || lower.contains("timed out") {
            return .networkError(msg)
        }
        if lower.contains("config value") || lower.contains("followredirects") {
            return .repositoryNotFound
        }
        return .cloneFailed(message: msg)
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The repository URL is invalid."
        case .authenticationFailed:
            return "Authentication failed. Check your access token."
        case .repositoryNotFound:
            return "Repository not found. Check the URL and your permissions."
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .destinationAlreadyExists:
            return "A project with that name already exists."
        case .timedOut:
            return "Clone timed out. Check your connection and try again."
        case .cloneFailed(let message):
            return "Clone failed: \(message)"
        }
    }
}
