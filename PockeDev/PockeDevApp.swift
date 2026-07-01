import SwiftUI

// MARK: - App Entry Point

@main
struct PockeDevApp: App {
    @StateObject private var projectService = ProjectService()
    @StateObject private var sessionStore = DocumentSessionStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(projectService)
                .environmentObject(sessionStore)
                .preferredColorScheme(.dark)
        }
    }
}
