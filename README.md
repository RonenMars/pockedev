# PocketDev

A native iOS code editor and Git client built with SwiftUI. Edit files, manage projects, and commit/push to GitHub — all from your iPhone.

---

## Features

### Project Management
- Create new projects (auto-seeded with a `README.md`)
- Clone repositories from GitHub with real-time progress and PAT authentication
- Open any local file or folder via the system file picker
- Import existing directories into the project list

### File Explorer
- Depth-indented tree view with inline folder expand/collapse
- Expansion state persisted per project across sessions
- Create, rename, delete, move, and copy files and folders
- Multi-select mode with bulk move/copy/delete operations
- Git status badge showing count of changed files

### Code Editor
- Multi-tab interface with horizontal tab scroll
- Syntax highlighting for 8 languages: Swift, JavaScript, Python, JSON, Markdown, CSS, HTML, YAML
- Dirty-state indicator per tab (orange dot = unsaved changes)
- In-file search with previous/next navigation and dual-color match highlights
- UITextView backend for smooth typing at any file size (files >100 KB skip highlighting)
- Cursor position preserved across content updates

### Git / Source Control
- View changed, added, deleted, and untracked files with color-coded status labels
- Stage individual files via checkbox selection
- Commit with author name, email, and message
- Commit & Push with GitHub Personal Access Token
- Pull (fetch + merge) from remote
- Swipe a changed file to view its diff with syntax-colored additions and deletions
- Branch switcher — list local branches, see current branch, and checkout
- Token stored securely in the system Keychain (optional auto-save on clone)

---

## Architecture

**Pattern:** SwiftUI + MVVM

```
PocketDev/
├── DesignSystem/           # Design tokens and shared UI components
│   ├── Tokens.swift        # Colors, spacing, radius, motion constants
│   └── Components/         # PDButton, PDInput, PDTopBar, PDEmptyState, PDSurface
├── Models/
│   ├── Project.swift       # Project metadata (id, name, rootPath, createdAt)
│   └── DocumentSession.swift  # Open tab state (URL, content, isDirty)
├── Screens/
│   ├── Home/               # Project list, clone sheet, new project sheet
│   ├── Explorer/           # File tree, Git commit modal
│   └── Editor/             # Multi-tab code editor, search overlay
├── Services/
│   ├── ProjectService.swift       # CRUD + persistence for projects
│   ├── FileService.swift          # File system operations
│   ├── GitService.swift           # Gitty-backed clone, status, commit, push, pull
│   ├── KeychainService.swift      # Secure GitHub PAT storage
│   └── SyntaxHighlighter.swift    # Regex-based syntax highlighting
└── Stores/
    └── DocumentSessionStore.swift  # Global tab/session state (@MainActor)
```

### Key Technical Decisions

| Concern | Approach |
|---|---|
| Editor performance | `UITextView` via `UIViewRepresentable` — no SwiftUI text lag |
| File picker | `UIDocumentPickerViewController` for security-scoped access |
| Git operations | `Gitty` (local Swift package, libgit2 wrapper) for full local Git support |
| Clone thread safety | `actor`-based `GitCloneService` with async progress callbacks |
| Token security | System Keychain (`Security` framework) |
| Syntax highlighting | Regex multi-pass, compiled & cached in UITextView coordinator |
| Search highlights | Applied to cached attributed string — never mutates the syntax cache |
| Tab state | `@MainActor` `DocumentSessionStore` with `@Published` arrays |
| Folder expansion | Static dictionary cache survives SwiftUI view recreation |

---

## Design System

All visual constants are defined in `DesignSystem/Tokens.swift`:

```swift
// Colors
Colors.background, .surface, .panel
Colors.textPrimary, .textSecondary
Colors.accent, .success, .warning, .error

// Spacing (pt)
Spacing.xs(4), .sm(8), .md(12), .lg(16), .xl(20), .xxl(24)

// Radius
Radius.small(6), .medium(10)

// Animation durations
Motion.micro(0.12s), .normal(0.22s), .modal(0.28s)
```

**Components:**
- `PDButton` — primary / secondary / ghost, with loading spinner and optional icon
- `PDInput` — labeled text field with focus border
- `PDTopBar` — 52pt header with title, subtitle, leading icon, trailing views
- `PDEmptyState` — icon + title + message + action button
- `PDSurface` — configurable container with color, corner radius, and padding

---

## Screen Flow

```
HomeView
├── NewProjectView (sheet)
├── DocumentPickerView (sheet — file or folder mode)
├── CloneRepoView (sheet)
│   └── Progress bar + status message during clone
└── ExplorerView (push navigation)
    ├── FileRow (depth-indented, expandable)
    │   └── EditorContainerView (push navigation)
    │       ├── TabsBar (horizontal scroll)
    │       ├── CodeEditorView (UITextView)
    │       └── SearchOverlay (slides in from top)
    ├── GitCommitView (sheet)
    │   ├── File selection + author fields + commit/push/pull buttons
    │   └── DiffView (sheet — swipe file row)
    └── BranchPickerView (sheet)
```

---

## Requirements

- **iOS 16.0+**
- **Xcode 15+**
- **Swift 5.9+**
- Device: arm64 (iPhone 8 or later)
- Orientations: Portrait and Landscape

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| Gitty | local package (`/Desktop/dev/Gitty`) | Git clone, status, commit, push, pull, branch, diff |

All other functionality uses Apple frameworks: `SwiftUI`, `UIKit`, `Foundation`, `Security`, `Combine`.

---

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/pocket-dev.git
   cd pocket-dev
   ```

2. Open `PocketDev.xcodeproj` in Xcode.

3. Set a development team in **Signing & Capabilities** (required for Keychain access).

4. Build and run on a physical device or simulator (iOS 16.0+).

> **Note:** A GitHub Personal Access Token (PAT) with `repo` scope is required for cloning private repositories and pushing commits.

---

## Data Storage

| Data | Storage |
|---|---|
| Project list | `UserDefaults` (JSON encoded) |
| Open tabs | In-memory only (not persisted across app launches) |
| Git author name/email | `UserDefaults` |
| GitHub PAT | System Keychain (`com.pocketdev.app / github.token`) |
| File contents | App sandbox `Documents/` directory or user-selected security-scoped URL |

---

## License

MIT
