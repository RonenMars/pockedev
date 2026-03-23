import SwiftUI

// MARK: - App Entry Point

@main
struct PocketDevApp: App {
    @StateObject private var projectService = ProjectService()
    @StateObject private var sessionStore = DocumentSessionStore()

    init() {
        Libgit2Manager.initialize()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(projectService)
                .environmentObject(sessionStore)
                .preferredColorScheme(.dark)
        }
    }
}
