import Foundation

// MARK: - GitCommitViewModel

@MainActor
final class GitCommitViewModel: ObservableObject {
    @Published private(set) var changedFiles: [GitStatusFile] = []
    @Published var selectedPaths: Set<String> = []
    @Published var commitMessage = ""
    @Published var authorName = ""
    @Published var authorEmail = ""
    @Published var token = ""
    @Published private(set) var isLoading = false
    @Published private(set) var successMessage: String?
    @Published private(set) var errorMessage: String?

    private let gitService: GitRepositoryService

    private let authorNameKey  = "git.authorName"
    private let authorEmailKey = "git.authorEmail"

    init(repoURL: URL) {
        self.gitService = GitRepositoryService(repoURL: repoURL)
        authorName  = UserDefaults.standard.string(forKey: authorNameKey)  ?? ""
        authorEmail = UserDefaults.standard.string(forKey: authorEmailKey) ?? ""
        token       = KeychainService.loadToken() ?? ""
    }

    // MARK: - Load status

    func loadStatus() {
        isLoading = true
        errorMessage = nil
        let service = gitService
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try service.changedFiles() }
            }.value
            switch result {
            case .success(let files):
                changedFiles = files
                selectedPaths = Set(files.map { $0.path })
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Selection

    func toggleFile(_ path: String) {
        if selectedPaths.contains(path) {
            selectedPaths.remove(path)
        } else {
            selectedPaths.insert(path)
        }
    }

    // MARK: - Commit

    func commit() async {
        guard validate(requireToken: false) else { return }
        isLoading = true
        errorMessage = nil
        saveAuthor()

        let service = gitService
        let paths   = Array(selectedPaths)
        let msg     = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let name    = authorName
        let email   = authorEmail

        let result = await Task.detached(priority: .userInitiated) {
            Result { try service.commit(paths: paths, message: msg, authorName: name, authorEmail: email) }
        }.value

        switch result {
        case .success:
            commitMessage  = ""
            successMessage = "Committed successfully."
            await refreshStatus()
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Commit & Push

    func commitAndPush() async {
        guard validate(requireToken: true) else { return }
        isLoading = true
        errorMessage = nil
        saveAuthor()

        let service = gitService
        let paths   = Array(selectedPaths)
        let msg     = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let name    = authorName
        let email   = authorEmail
        let tok     = token.trimmingCharacters(in: .whitespacesAndNewlines)

        KeychainService.saveToken(tok)

        let result: Result<Void, Error> = await Task.detached(priority: .userInitiated) {
            do {
                try service.commit(paths: paths, message: msg, authorName: name, authorEmail: email)
                try await service.push(token: tok)
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success:
            commitMessage  = ""
            successMessage = "Committed and pushed successfully."
            await refreshStatus()
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Pull

    func pull() async {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = GitOperationError.emptyToken.localizedDescription
            return
        }
        isLoading = true
        errorMessage = nil
        let service = gitService
        let tok = token.trimmingCharacters(in: .whitespacesAndNewlines)

        let result: Result<Void, Error> = await Task.detached(priority: .userInitiated) {
            do {
                try await service.pull(token: tok)
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success:
            successMessage = "Pulled successfully."
            await refreshStatus()
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Helpers

    func clearError() { errorMessage = nil }
    func clearSuccess() { successMessage = nil }

    private func validate(requireToken: Bool) -> Bool {
        if selectedPaths.isEmpty {
            errorMessage = GitOperationError.noChangesToCommit.localizedDescription
            return false
        }
        if commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = GitOperationError.emptyCommitMessage.localizedDescription
            return false
        }
        if requireToken && token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = GitOperationError.emptyToken.localizedDescription
            return false
        }
        return true
    }

    private func saveAuthor() {
        UserDefaults.standard.set(authorName,  forKey: authorNameKey)
        UserDefaults.standard.set(authorEmail, forKey: authorEmailKey)
    }

    private func refreshStatus() async {
        let service = gitService
        let result = await Task.detached(priority: .userInitiated) {
            Result { try service.changedFiles() }
        }.value
        if case .success(let files) = result {
            changedFiles  = files
            selectedPaths = Set(files.map { $0.path })
        }
    }
}
