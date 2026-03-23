
# ORCHESTRATOR_ADVANCED_STATEFUL.md

## Purpose
This document is the active execution controller for PocketDev **after completion of the Tabs + Search slice**.

It is designed for Claude Code and similar coding agents working on an incremental, spec-driven, token-efficient implementation.

This version includes the **current implemented state** so future work can continue without depending on long chat history.

---

## 1. Project Mode

You are working on **PocketDev**, a local-first iOS code editor.

Current product scope is still **Phase 1**.

### Phase 1 includes
- Home / Projects
- Open File
- Open Folder
- New Project
- File Explorer
- Editor
- Tabs
- In-file Search
- Optional Clone Repo later, only if explicitly requested

### Phase 1 excludes
- Git workflows
- SSH / terminal
- AI product features
- replace
- project-wide search
- speculative persistence
- redesign of approved screens unless explicitly requested

Do not introduce excluded features.

---

## 2. Source of Truth Priority

Always resolve decisions in this order:

1. ORCHESTRATOR_ADVANCED_STATEFUL.md
2. Current user request
3. BUILD_ORDER.md
4. ARCHITECTURE.md
5. UI_SPEC.md
6. COMPONENT_MAP.md
7. TOKENS.md
8. DESIGN.md
9. Existing codebase

### Interpretation rule
- DESIGN.md defines UX philosophy and constraints
- TOKENS.md defines visual system
- COMPONENT_MAP.md defines primitive and app-level UI building blocks
- UI_SPEC.md defines screens, flows, and states
- ARCHITECTURE.md defines implementation boundaries
- BUILD_ORDER.md defines sequencing
- Existing codebase defines current implementation reality, but may be corrected if it conflicts with higher-priority docs

If docs conflict, explicitly state the conflict and choose the higher-priority source.

---

## 3. Current Implemented State (Authoritative)

The following slices are considered **implemented and must be preserved** unless explicitly changed.

### Slice 1 — Core flow implemented
Home → New Project → Explorer → Open File → Edit → Save

This slice is complete enough to be treated as the stable base flow.

### Slice 2 — Tabs + Search implemented
Tabs + in-file search are implemented and are part of the approved baseline.

#### Changed files in this slice

### 1. `SearchOverlay.swift` (new)
`SearchOverlay` exists as a named component from `COMPONENT_MAP.md`.

It is a single-row overlay containing:
- search `TextField`
- magnifying glass icon
- auto-focus on appear
- match counter `"X of Y"`
- red `"No results"` state when query has zero matches
- clear button via `xmark.circle.fill`
- previous / next navigation buttons using chevron icons
- Done button to dismiss

Transition is handled by the caller using:
- move from top
- opacity combination

This is aligned with `DESIGN.md` motion guidance for search overlay behavior.

### 2. `CodeEditorView.swift` (modified)
Current behavior includes:
- `highlightedRange: NSRange? = nil` input
- if highlighted range changes, the editor:
  - selects the range
  - scrolls it into view
- if highlighted range becomes `nil` after previously being set:
  - selection is cleared by moving cursor to end
- `Coordinator` tracks `lastHighlightedRange` to suppress redundant updates

Important implementation rule:
- search highlighting currently uses the native `UITextView` selection highlight
- do not replace this with attributed-string complexity unless explicitly required

### 3. `EditorContainerView.swift` (modified)
Current local search state exists here and is **not persisted**.

Implemented local state:
- `showSearch`
- `searchQuery`
- `searchMatches`
- `currentMatchIndex`
- `highlightedRange`

Implemented behavior:
- magnifying glass button in top bar toggles search
- search overlay is placed in `ZStack(alignment: .top)` inside editor body
- search query changes recompute matches on each keystroke
- switching active session recomputes matches
- matching uses case-insensitive `NSString.range(of:options:range:)` looping
- navigation wraps through matches
- closing the last relevant tab clears search state before session close
- dismissing search resets all local search state atomically

---

## 4. Locked UX / Behavior Contracts

These behaviors are already implemented and should be treated as current product contracts unless explicitly changed.

- Search is an overlay, not a pushed screen
- Search overlay uses top-entry + fade behavior
- Match count is visible while querying
- No replace
- No project-wide search
- Tab close button appears only on active tab
- Dirty dot `●` appears in tab before file name
- Active tab auto-scrolls into view
- Search is cleared on tab switch to avoid hidden cross-tab state
- SearchOverlay remains a named standalone component

Do not regress these behaviors.

---

## 5. Regression Protection (Expanded)

Before concluding any future slice, verify all of the following still work:

### Core flow regressions
- Home still loads correctly
- New Project still creates and opens a project
- Explorer still shows files correctly
- Open File still opens into editor
- Edit + Save still works

### Tabs regressions
- multiple files can remain open in tabs
- active tab switching still works
- dirty indicator still shows correctly
- active tab remains visible in horizontal tab list
- active tab close behavior remains consistent

### Search regressions
- search overlay still appears above editor content
- search query updates still recompute results
- next / previous still navigate matches
- no-results state still displays clearly
- highlighted result still scrolls into view
- search still clears on tab switch
- dismiss search still resets all local search state

Always call out any regression risk introduced by new work.

---

## 6. Context Management Rules

### Keep only high-value context
Do not rely on long conversation history.

Prefer:
- current codebase
- spec docs
- this orchestrator
- latest Slice Progress file

### At the start of a fresh session
Read only:
- ORCHESTRATOR_ADVANCED_STATEFUL.md
- DESIGN.md
- TOKENS.md
- UI_SPEC.md
- COMPONENT_MAP.md
- ARCHITECTURE.md
- BUILD_ORDER.md
- latest Slice Progress file

Ignore older conversation history unless explicitly requested.

### If context becomes noisy
Symptoms:
- repeated redesign ideas
- inconsistent naming
- unnecessary refactors
- feature creep
- divergence from current implemented contracts

Then:
1. stop
2. summarize current implementation state
3. recommend a reset
4. continue from docs + slice summary + current codebase

---

## 7. General Execution Rules

You must:
- build in vertical slices
- preserve previously completed slices
- prefer end-to-end usable flows over broad scaffolding
- keep state explicit
- keep future changes tightly scoped
- produce concise explanations
- minimize token usage by referring to docs and implemented state rather than restating everything

You must not:
- redesign approved screens without explicit request
- add “nice to have” features unasked
- silently expand scope
- replace working implementations without justification
- rewrite search architecture unless there is a concrete problem or explicit request

---

## 8. Output Format Rules

Unless the user asks otherwise, use this format:

### 1. Plan
Very short. 3–7 bullets max.

### 2. Changed Files
List created/modified files.

### 3. Code
Provide only relevant code.

### 4. Mapping to Spec
Briefly map implementation to:
- UI_SPEC.md
- ARCHITECTURE.md
- TOKENS.md
- DESIGN.md when behavior/UX matters
- current orchestrator contracts when preserving existing functionality matters

### 5. Risks / Follow-ups
Only include if important.

Keep responses compact.

---

## 9. Vertical Slice Policy

A vertical slice must:
- deliver a user-visible outcome
- be testable end-to-end
- include key states
- integrate with the current stable baseline

### Implemented slice order so far
1. Home → New Project → Explorer → Open File → Edit → Save
2. Tabs + Search

### Preferred next slice
3. Clone Repo, only if explicitly requested
4. Refinements or hardening requested by the user
5. Phase 2 only when explicitly started

Do not start a new slice until the current one is functionally complete or explicitly accepted.

---

## 10. Stitch MCP Rules

If Stitch MCP is connected, Stitch remains a **rendering/refinement tool**, not a design authority.

Use Stitch only for:
- refining specific screen/component layouts
- reconciling implementation with approved visual direction
- comparing against approved screen expectations

Do not use Stitch to:
- invent new flows
- override UI_SPEC.md
- replace implemented behavior contracts
- introduce components not justified by COMPONENT_MAP.md

If Stitch conflicts with specs or existing approved behavior, specs and approved implementation win.

---

## 11. Technical Guardrails

### Platform
- iOS native
- Swift
- SwiftUI for shell by default
- UIKit allowed where technically justified, especially editor internals

### Architecture
Respect ARCHITECTURE.md.
Do not introduce unrelated patterns unless necessary.

### State
Prefer explicit local state over hidden behavior.

### Search-specific guardrail
Current search implementation is local to `EditorContainerView`.
Do not introduce persistence, global search state, or cross-project search without explicit request.

### Editor-specific guardrail
Current highlighted result behavior is implemented through native text selection.
Preserve this unless a real need justifies a different approach.

---

## 12. Naming Rules

Use stable, descriptive names.

Prefer:
- `HomeScreen`
- `FileExplorerScreen`
- `EditorScreen`
- `SearchOverlay`
- `ProjectService`
- `FileService`
- `DocumentSessionStore`

Avoid clever or overloaded names.

If renaming existing code, explain why.

---

## 13. Token Efficiency Rules

To conserve tokens:
- do not restate full specs
- summarize only the requested change
- refer to current implemented contracts instead of repeating earlier slices in detail
- avoid repeating unchanged code
- prefer focused snippets or diffs unless full files are requested

If the user asks for a full file, provide the full file.

---

## 14. Ambiguity Protocol

If a requirement is ambiguous:
1. check spec docs
2. check this orchestrator’s implemented state
3. check the codebase
4. choose the smallest valid interpretation
5. if ambiguity materially affects architecture or UX, ask one concise question

Do not ask clarifying questions for minor implementation details if a low-risk choice exists.

---

## 15. Completion Protocol

At the end of each future slice:
1. summarize what was implemented
2. list changed files
3. state known gaps
4. state regression risks
5. recommend whether to continue or reset context
6. generate or update a Slice Progress file if asked

### Recommend resetting context when:
- a slice is complete
- the next slice differs significantly in nature
- the conversation contains substantial debugging or discarded directions

---

## 16. Fresh Session Kickoff Template

Use or adapt this in a fresh session:

You are working on PocketDev.

Read:
- ORCHESTRATOR_ADVANCED_STATEFUL.md
- DESIGN.md
- TOKENS.md
- UI_SPEC.md
- COMPONENT_MAP.md
- ARCHITECTURE.md
- BUILD_ORDER.md
- latest Slice Progress file

Ignore prior chat history.
Treat the first two slices as implemented baseline.
Do not redesign approved UI.
Do not expand scope.
Implement only the requested vertical slice or refinement.

---

## 17. Example Continuation Prompt

Continue following ORCHESTRATOR_ADVANCED_STATEFUL.md.

Current baseline already includes:
- Home → New Project → Explorer → Open File → Edit → Save
- Tabs + Search

Implement ONLY the requested next slice or refinement.
Preserve all current search and tab behavior contracts unless explicitly told otherwise.

Output:
1. Plan
2. Changed files
3. Code
4. Mapping to specs
5. Regression risks

---

## 18. Final Rule

If a proposed change makes the app more complex, less predictable, or less aligned with approved docs and current implemented contracts, do not make it without explicit approval.
