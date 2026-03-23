import Foundation

// MARK: - CloneRepoViewModel

@MainActor
final class CloneRepoViewModel: ObservableObject {
    @Published private(set) var isCloning = false
    @Published private(set) var progressMessage = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var completedProject: Project?

    private let cloneService: any GitCloning
    private let projectService: ProjectService

    init(projectService: ProjectService, cloneService: (any GitCloning)? = nil) {
        self.projectService = projectService
        self.cloneService = cloneService ?? GitCloneService()
    }

    func clone(urlString: String, token: String) async {
        errorMessage = nil
        isCloning = true
        progressMessage = "Cloning repository…"

        do {
            var raw = urlString.trimmingCharacters(in: .whitespaces)
            if raw.hasSuffix("/") { raw = String(raw.dropLast()) }

            guard let url = URL(string: raw) else {
                throw GitCloneError.invalidURL
            }

            let name = url.deletingPathExtension().lastPathComponent
            let dest = try projectService.destinationURL(for: name)
            let tok: String? = token.trimmingCharacters(in: .whitespaces).isEmpty ? nil : token

            try await cloneService.cloneRepository(from: raw, token: tok, to: dest)

            let project = projectService.importProject(at: dest, name: name)
            isCloning = false
            completedProject = project
        } catch {
            isCloning = false
            errorMessage = error.localizedDescription
        }
    }
}
