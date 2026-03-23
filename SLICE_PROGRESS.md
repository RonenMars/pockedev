# PocketDev — Slice Progress

## Implemented Slices

---

### Slice 1 — Core Flow ✅
**Home → New Project → Explorer → Open File → Edit → Save**

- `PocketDevApp.swift` — entry point, environment injection
- `DesignSystem/Tokens.swift` — full token system (color, spacing, radius, motion)
- `DesignSystem/Components/` — PDButton, PDInput, PDSurface, PDEmptyState, PDTopBar
- `Models/Project.swift`, `Models/DocumentSession.swift`
- `Services/ProjectService.swift` — create + persist projects to UserDefaults
- `Services/FileService.swift` — list / read / write
- `Stores/DocumentSessionStore.swift` — session lifecycle (open, activate, edit, save, close)
- `Screens/Home/HomeView.swift` — empty + populated states, action tiles, recent projects
- `Screens/NewProject/NewProjectView.swift` — modal sheet, single primary action
- `Screens/Explorer/ExplorerView.swift` — file tree, 5 states, inline folder expand/collapse
- `Screens/Explorer/FileRow.swift` — depth-indented, active highlight, file-type icons
- `Screens/Editor/EditorContainerView.swift` — top bar + editor body (all states)
- `Screens/Editor/CodeEditorView.swift` — UIKit UITextView, monospace, no lag
- `Screens/Editor/TabsBar.swift` — tabs with active / dirty / close states

**Gaps / known issues:** none blocking

---

### Slice 2 — Tabs + Search ✅
**Multiple open files in tabs. In-file search overlay with next/prev navigation.**

#### Changed files
- `Screens/Editor/SearchOverlay.swift` *(new)* — single-row overlay: field, match counter, prev/next, done
- `Screens/Editor/CodeEditorView.swift` *(modified)* — `highlightedRange: NSRange?`; selects + scrolls on change; clears on nil; coordinator guards redundant updates
- `Screens/Editor/EditorContainerView.swift` *(modified)* — search state (`showSearch`, `searchQuery`, `searchMatches`, `currentMatchIndex`, `highlightedRange`); search button in top bar; SearchOverlay in ZStack above editor; recomputes on query change + tab switch; `dismissSearch()` resets atomically

#### Behavior contracts (locked)
- Search is a top-entry overlay, not a pushed screen
- Match count visible while querying; "No results" in error color when zero
- Tab close button only on active tab; dirty dot before filename
- Active tab auto-scrolls into view
- Search cleared on tab switch

**Gaps / known issues:**
- Matches not recomputed when file content is edited while search is open (stale until query changes)

---

### Slice 3 — Open File + Open Folder ✅
**UIDocumentPickerViewController for opening external files and folders.**

#### Changed files
- `Screens/Home/DocumentPickerView.swift` *(new)* — `UIViewControllerRepresentable` wrapping `UIDocumentPickerViewController`; `.file` and `.folder` modes
- `Services/FileService.swift` *(modified)* — `startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource` added to `listItems`, `readFile`, `writeFile`; no-op for in-sandbox URLs
- `Screens/Home/HomeView.swift` *(modified)* — `showFilePicker`, `showFolderPicker`, `navigateToEditor` states; picker sheets; `navigationDestination(isPresented:)` for direct-to-editor navigation
- `Screens/Editor/EditorContainerView.swift` *(modified)* — last-tab auto-dismiss: `dismissSearch()` + `sessionStore.close(id:)` + `dismiss()` when closing final session
- `PocketDev.xcodeproj/project.pbxproj` *(modified)* — registered `SearchOverlay.swift` and `DocumentPickerView.swift` (were missing from target)

#### Behavior
- Open File → picker → `sessionStore.openFile(at:)` → `EditorContainerView`
- Open Folder → picker → in-memory `Project(name:rootURL:)` → `navPath.append(project)` → `ExplorerView`
- External folders not persisted to Recent list (by design)
- Closing last tab auto-dismisses editor back to Explorer

**Gaps / known issues:**
- External folder expansion may be fragile for deeply nested trees if security scope expires between `listItems` calls at different depths (low risk for typical use)
- No error recovery UI if an externally-picked file becomes inaccessible after opening (existing error state in EditorContainerView handles it)

---

### Slice 4 — Stability / UX Hardening ✅
**Stale search matches, Explorer expansion state loss, async file write.**

#### Changed files
- `Screens/Editor/EditorContainerView.swift` *(modified)* — added `.onChange(of: sessionStore.activeSession?.content)` observer to recompute matches while search is open; `recomputeMatches()` clamps `currentMatchIndex` instead of resetting to 0 (preserves position across edits); added `@State private var isSaving` + `Task { @MainActor in }` wrapper for save; save button shows loading spinner and stays visible while saving
- `Screens/Explorer/ExplorerView.swift` *(modified)* — replaced `private var expandedDirs: Set<URL> = []` with static `expansionCache: [URL: Set<URL>]` keyed by `rootURL`; expansion state now survives view recreation when navigating back to Home and re-entering the same project
- `Stores/DocumentSessionStore.swift` *(modified)* — `save(sessionID:)` now async: `withCheckedContinuation` + `DispatchQueue.global(qos: .userInitiated)`; captures `url`/`content`/`service` before background dispatch; only clears `isDirty` if `$0.content == content` after write; `[weak self]` moved to inner `DispatchQueue.main.async` only; marked `@unchecked Sendable`
- `Services/FileService.swift` *(modified)* — marked `@unchecked Sendable` to eliminate Swift concurrency warning

#### Behavior contracts (locked)
- Search matches stay current when file content is edited while search is open
- Explorer folder expansion state persists across back-navigation and re-entry
- File writes run on background thread; `isDirty` only clears if content unchanged since save started
- Save button shows loading state and remains visible during in-flight save

**Gaps / known issues:** none blocking

---

### Slice 5 — Syntax Highlighting + Search Match Highlighting ✅
**Per-language syntax colors. All search matches highlighted; active match distinctly styled. No full re-highlight on search-only changes.**

#### New files
- `Services/SyntaxHighlighter.swift` *(new)* — pure `enum SyntaxHighlighter`; `static highlight(text:fileExtension:) -> NSMutableAttributedString`; languages: Swift, JS/TS, Python, JSON, Markdown; regex patterns compiled once (static cache); 20 KB cap returns plain text; 5 token colors (keyword, string, comment, number, type)

#### Changed files
- `Screens/Editor/CodeEditorView.swift` *(modified)* — replaced `highlightedRange: NSRange?` with `fileExtension: String`, `searchMatches: [NSRange]`, `activeMatchIndex: Int`; two-pass highlight pipeline in `updateUIView`: Pass 1 (syntax) runs only when text or extension changes; Pass 2 (search overlay) runs when matches or activeMatchIndex changes; `cachedSyntaxAttr` stored in coordinator so Pass 1 is skipped on search navigation; `isRangeVisible` checks layout manager bounds before `scrollRangeToVisible`; cursor preserved via savedRange; IME guard (`markedTextRange == nil`)
- `Screens/Editor/EditorContainerView.swift` *(modified)* — removed `@State private var highlightedRange`; passes `fileExtension`, `searchMatches`, `activeMatchIndex` to `CodeEditorView`; removed `highlightedRange` assignments from `dismissSearch`, `recomputeMatches`, `navigateMatch`
- `PocketDev.xcodeproj/project.pbxproj` *(modified)* — registered `SyntaxHighlighter.swift` (fileRef `C9A51F7E82B34DE1B0F63892`, buildFile `B2F4E8AC1D3A4F0C9E72D305`)

#### Behavior contracts (locked)
- Syntax colors applied on file open and after every edit, per file extension
- All search matches shown with amber background tint (28% opacity)
- Active search match shown with accent blue background tint (45% opacity)
- Pressing next/prev match re-applies only Pass 2 (no syntax re-parse)
- `scrollRangeToVisible` called only when `activeMatchIndex` changes AND match is off-screen
- Cursor position preserved across all attributed-text updates
- IME composition never interrupted
- Files > 20 KB render as plain text (no stutter on large generated files)

**Gaps / known issues:**
- Syntax colors are regex-based; edge cases (nested structures, multi-line strings) may mis-color — acceptable for Phase 1
- IME composition guard means highlights are stale until IME commits; unavoidable without breaking input

---

## Locked Behavior Contracts

These must not regress:

| Behavior | Source |
|---|---|
| Search overlay: top-entry + fade | DESIGN.md §6.3 |
| Match count visible while querying | DESIGN.md §1.5 |
| No replace, no project-wide search | Phase 1 exclusions |
| Tab close only on active tab | DESIGN.md §5.1 |
| Dirty dot before filename | DESIGN.md §10.2 |
| Active tab auto-scrolls into view | TabsBar `ScrollViewReader` |
| Search cleared on tab switch | EditorContainerView contract |
| Dismiss search resets all state atomically | `dismissSearch()` |
| Last-tab close auto-dismisses editor | EditorContainerView Slice 3 fix |
| All search matches amber-highlighted | CodeEditorView Pass 2 overlay |
| Active match accent-highlighted + scrolled | CodeEditorView activeMatchIndex guard |
| Syntax pass skipped on search-only change | CodeEditorView cachedSyntaxAttr |
| Cursor preserved across highlight updates | CodeEditorView savedRange restore |

---

## Build Status

- All source files type-check: ✅
- All new files registered in `project.pbxproj`: ✅
- Deployment target: iOS 16.0

---

## Recommended Next Steps (Priority Order)

1. **Clone Repo** — only if explicitly requested

2. **Phase 2** — only when explicitly started

3. **Syntax highlighting hardening** (optional Phase 1 polish)
   - Line number gutter
   - Incremental re-highlight (only re-parse edited paragraph, not full document)
   - Add HTML/CSS/Shell language support
