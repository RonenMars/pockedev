# PocketDev — Continuation Instructions

## Context

PocketDev is an iOS SwiftUI git client (Xcode project at this directory).
Gitty is a local Swift package at `/Users/ronenmars/Desktop/dev/Gitty` — a libgit2 wrapper we built to replace direct raw libgit2 C API usage.

### What is already implemented

- File CRUD: create file/folder, delete, rename via context menus
- Multi-select with bulk delete / move / copy
- `GitCommitView` + `GitCommitViewModel` — full UI for commit and commit+push
- `GitService.swift` — clone (with 60s timeout + progress), status, commit, push — all working but using raw libgit2 C API directly
- `GitCloneError` + `GitOperationError` error types in `GitCloneError.swift`
- `Libgit2Manager.swift` — calls `git_libgit2_init()` on app launch (will be removed)
- Git panel button in `ExplorerView` showing changed file count badge

### What needs to be done

1. Swap raw libgit2 for the local Gitty package
2. Rewrite `GitService.swift` using Gitty's Swift API
3. Add Pull support to the git panel
4. (Stretch) Branch switcher UI
5. (Stretch) Diff viewer

---

## Step 1 — Add Gitty as a local SPM dependency

Do this through Xcode UI to avoid manual pbxproj editing:

1. Open `PocketDev.xcodeproj` in Xcode.
2. **File → Add Package Dependencies → Add Local** → select `/Users/ronenmars/Desktop/dev/Gitty`.
3. In **Target → Frameworks, Libraries and Embedded Content**: add `Gitty`.
4. Go to **Project → Package Dependencies**, find `ibrahimcetin/libgit2`, and remove it.
5. In **Target → Frameworks, Libraries**: remove `libgit2`.

---

## Step 2 — Delete `Libgit2Manager.swift`

Gitty calls `git_libgit2_init()` internally. `Libgit2Manager.swift` is now redundant.

- Delete the file from the project (Move to Trash).
- Remove any call to `Libgit2Manager.shared.initialize()` from the app entry point (check `PocketDevApp.swift`).

---

## Step 3 — Rewrite `GitService.swift`

Replace the entire contents of `PocketDev/Services/GitService.swift` with the following:

```swift
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
        case .modified:   self = .modified
        case .added:      self = .added
        case .deleted:    self = .deleted
        case .untracked:  self = .untracked
        case .renamed:    self = .renamed
        case .typeChanged: self = .modified
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
```

---

## Step 4 — Update `GitCloneError.swift`

Remove `import libgit2` and the `from(status:message:)` factory method — they were only needed for raw libgit2 error codes. Keep everything else (`GitCloneError`, `GitOperationError`).

The file should start with just `import Foundation`.

---

## Step 5 — Update `GitCommitViewModel.swift`

`push` is now `async` in `GitRepositoryService`. Update `commitAndPush()` to `await` it directly:

```swift
// Replace this:
try service.push(token: tok)

// With this:
try await service.push(token: tok)
```

The surrounding `Task.detached` block must use `Result<Void, Error>` and be `async`:

```swift
let result = await Task.detached(priority: .userInitiated) {
    await Result {
        try service.commit(paths: paths, message: msg, authorName: name, authorEmail: email)
        try await service.push(token: tok)
    }
}.value
```

Also update error display to use `GittyError.message` where applicable — the `localizedDescription` on `GittyError` already returns the message so no special handling is needed.

---

## Step 6 — Add Pull to `GitCommitViewModel`

Add this method:

```swift
func pull() async {
    guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        errorMessage = GitOperationError.emptyToken.localizedDescription
        return
    }
    isLoading = true
    errorMessage = nil
    let service = gitService
    let tok = token.trimmingCharacters(in: .whitespacesAndNewlines)

    let result = await Task.detached(priority: .userInitiated) {
        await Result { try await service.pull(token: tok) }
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
```

---

## Step 7 — Add Pull button to `GitCommitView`

In the **Actions** section of the `Form`, add a Pull button alongside Commit and Commit & Push:

```swift
actionButton(title: "Pull", color: Tokens.Color.textSecondary) {
    Task { await viewModel.pull() }
}
```

---

## Step 8 (Stretch) — Branch Switcher

**New file:** `PocketDev/Screens/Explorer/BranchPickerView.swift`

```swift
import SwiftUI
import Gitty

struct BranchPickerView: View {
    let repoURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var branches: [Branch] = []
    @State private var current: String?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List(branches) { branch in
                Button {
                    checkout(branch)
                } label: {
                    HStack {
                        Text(branch.name)
                            .foregroundColor(Tokens.Color.textPrimary)
                        Spacer()
                        if branch.name == current {
                            Image(systemName: "checkmark")
                                .foregroundColor(Tokens.Color.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Branches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { loadBranches() }
    }

    private func loadBranches() {
        guard let repo = try? Repository.open(at: repoURL) else { return }
        current = repo.currentBranch
        branches = (try? repo.branches.list()) ?? []
    }

    private func checkout(_ branch: Branch) {
        guard let repo = try? Repository.open(at: repoURL) else { return }
        try? repo.branches.checkout(branch)
        dismiss()
    }
}
```

In `ExplorerView`, present this sheet when the branch button is tapped (the button that currently opens `GitCommitView`). You can use a separate state variable `showBranchPicker` or add it as a second sheet option.

---

## Step 9 (Stretch) — Diff Viewer

**New file:** `PocketDev/Screens/Explorer/DiffView.swift`

Show it when tapping a file row inside `GitCommitView`.

```swift
import SwiftUI
import Gitty

struct DiffView: View {
    let repoURL: URL
    let filePath: String

    @State private var diff: FileDiff?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if let diff {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(diff.hunks) { hunk in
                            Text(hunk.header)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Tokens.Color.textSecondary)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                            ForEach(hunk.lines.indices, id: \.self) { i in
                                let line = hunk.lines[i]
                                Text("\(line.origin) \(line.content)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(lineColor(line.origin))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(lineBg(line.origin))
                            }
                        }
                    }
                } else {
                    ProgressView().padding()
                }
            }
            .background(Tokens.Color.background)
            .navigationTitle(filePath)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { loadDiff() }
    }

    private func loadDiff() {
        guard let repo = try? Repository.open(at: repoURL) else { return }
        diff = (try? repo.diff(from: "HEAD"))?.first { $0.newPath == filePath || $0.oldPath == filePath }
    }

    private func lineColor(_ origin: Character) -> Color {
        switch origin {
        case "+": return Tokens.Color.success
        case "-": return Tokens.Color.error
        default:  return Tokens.Color.textPrimary
        }
    }

    private func lineBg(_ origin: Character) -> Color {
        switch origin {
        case "+": return Tokens.Color.success.opacity(0.08)
        case "-": return Tokens.Color.error.opacity(0.08)
        default:  return Color.clear
        }
    }
}
```

---

## Files to touch — summary

| File | Action |
|---|---|
| `PocketDev.xcodeproj` | Add Gitty local package, remove libgit2 (via Xcode UI) |
| `PocketDev/Services/GitService.swift` | Full rewrite (Step 3) |
| `PocketDev/Services/GitCloneError.swift` | Remove `import libgit2`, remove `from(status:message:)` |
| `PocketDev/Services/Libgit2Manager.swift` | Delete |
| `PocketDev/Services/GitCommitViewModel.swift` | Update push to `async`, add `pull()` method |
| `PocketDev/Screens/Explorer/GitCommitView.swift` | Add Pull button |
| `PocketDev/Screens/Explorer/BranchPickerView.swift` | Create new (stretch) |
| `PocketDev/Screens/Explorer/DiffView.swift` | Create new (stretch) |

---

## Build validation checklist

- [ ] Project resolves Gitty package and no longer references libgit2
- [ ] App compiles with zero errors
- [ ] Clone a public repo → progress bar shows → repo appears in file tree
- [ ] Clone a private repo with a PAT token → succeeds
- [ ] Open git panel → changed files listed
- [ ] Commit → success message, file list clears
- [ ] Commit & Push → pushes to remote, no auth errors
- [ ] Pull → fetches and merges remote changes
- [ ] (Stretch) Branch picker shows current branch with checkmark, checkout works
- [ ] (Stretch) Tapping a file in git panel shows diff with coloured lines
