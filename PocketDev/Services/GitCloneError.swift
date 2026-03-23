import Foundation

// MARK: - GitCloneError
// Stable Swift-native error surface for the clone flow.
// libgit2 error codes are mapped here — nothing outside GitService should import libgit2.

enum GitCloneError: LocalizedError {
    case invalidURL
    case authenticationFailed
    case repositoryNotFound
    case networkError(String)
    case destinationAlreadyExists
    case cloneFailed(message: String)

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
        case .cloneFailed(let message):
            return "Clone failed: \(message)"
        }
    }
}
