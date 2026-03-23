import Foundation

// MARK: - ProjectService (ARCHITECTURE.md: Modules)
// Manages project lifecycle: create, list, persist.

final class ProjectService: ObservableObject {
    @Published private(set) var projects: [Project] = []

    private let storageKey = "pocketdev.projects"
    private let fileManager = FileManager.default

    init() { load() }

    // MARK: - Create

    func createProject(named name: String) throws -> Project {
        let docs = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let projectURL = docs.appendingPathComponent(name, isDirectory: true)

        guard !fileManager.fileExists(atPath: projectURL.path) else {
            throw ProjectError.nameAlreadyExists
        }

        try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: true)

        // Seed with a starter file so explorer is never empty
        let readmeURL = projectURL.appendingPathComponent("README.md")
        try "# \(name)\n\nWelcome to \(name).\n".write(to: readmeURL, atomically: true, encoding: .utf8)

        let project = Project(name: name, rootURL: projectURL)
        projects.insert(project, at: 0)
        save()
        return project
    }

    // MARK: - Persistence

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Project].self, from: data)
        else { return }

        // Only include projects whose directory still exists on disk
        projects = decoded.filter { fileManager.fileExists(atPath: $0.rootPath) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

// MARK: - Errors

enum ProjectError: LocalizedError {
    case nameAlreadyExists

    var errorDescription: String? {
        switch self {
        case .nameAlreadyExists: return "A project with that name already exists."
        }
    }
}
