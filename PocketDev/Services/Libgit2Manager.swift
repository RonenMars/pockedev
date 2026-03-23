import Foundation
import libgit2

// MARK: - Libgit2Manager
// Manages one-time global initialization of the libgit2 library.
// Call initialize() once at app startup — never per-clone.

enum Libgit2Manager {
    private static var initialized = false

    static func initialize() {
        guard !initialized else { return }
        initialized = true
        git_libgit2_init()
    }
}
