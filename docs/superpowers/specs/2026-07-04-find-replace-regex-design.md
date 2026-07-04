# In-File Find & Replace + Regex — Design

**Date:** 2026-07-04
**Status:** Approved, ready for implementation planning
**Scope:** One focused editor feature. Extends the existing in-file search.

---

## Background

PockeDev already ships in-file search: an overlay (`SearchOverlay`) with a query
field, prev/next navigation, a match counter, and dual-color highlighting driven
by `searchMatches: [NSRange]` flowing from `EditorContainerView` → `CodeEditorView`.
`SearchOverlay.swift` is explicitly annotated *"In-file search only. No replace.
No persistence."* — this feature lifts the "no replace" half of that constraint.

Both the competitor analysis (Kodex, Buffer Editor, Textastic, Runestone all ship
regex find & replace) and the user-request research (HIGH demand, the dividing line
for a "serious" editor) point to find & replace with regex as the highest-impact
focused editor feature that fits the current architecture without a new engine.

## Goals

Ship, for the **active file only**:

1. **Replace** — replace the current active match, then advance to the next.
2. **Replace All** — replace every match in one text mutation (one undo step).
3. **Regex mode** — toggle from literal matching to `NSRegularExpression`, with
   **capture-group templates** (`$1`, `$2`, …) in the replacement string.
4. **Case-sensitivity toggle** — applies in both literal and regex modes.
5. **Invalid-regex feedback** — a bad pattern shows an "Invalid regex" state
   instead of silently matching nothing.

## Non-goals (deferred to follow-ups)

- **Project-wide / across-files replace** (multi-file I/O, results list, per-file
  undo, unsaved-buffer handling). This is the clear next step, deliberately cut to
  keep this a single focused feature.
- Whole-word toggle.
- Search/replace history or persistence.
- Incremental replace preview as you type.

## UI

The overlay renders **only when search is active** (existing `showSearch` gate;
tapping the magnifying-glass toggles it). No persistent chrome. Within the overlay,
**replace starts collapsed** — the default is today's single find row, unchanged.
A **⇄** toggle on the left of the search field expands the replace row.

```
┌────────────────────────────────────────────────┐
│ 🔍  func (\w+)\(              3/8   ⌃ ⌄  │ .* Aa │   ← find row
│ ⇄   $1_impl(                    Replace  All  ✕ │   ← replace row (when expanded)
└────────────────────────────────────────────────┘
```

- **`.*`** = regex on/off. **`Aa`** = case-sensitive on/off. Both on the find row,
  accent-tinted when active.
- **Replace** = replace active match, advance to next. **All** = replace every match.
- Find-only collapsed view is byte-for-byte the current behavior → zero regression
  for the common case.
- Invalid regex: match-counter slot shows "Invalid regex" in `Tokens.Color.error`;
  Replace / Replace All disabled.

Layout grows from one 48pt row to a two-row stack. Stacking (not mode-swapping) is
chosen so find + replace are visible together, which matters when authoring regex
capture templates.

## Logic

All logic stays in `EditorContainerView`, extending `findMatches(in:query:)`.
No new files.

### Matching

- **Literal** (default): existing `NSString.range(of:)` loop; `.caseInsensitive`
  becomes conditional on the case toggle.
- **Regex**: `NSRegularExpression` (`.caseInsensitive` unless case-sensitive is on);
  `matches(in:range:)` returns all ranges in one pass. A pattern that fails to
  compile sets `isInvalidRegex = true` and yields zero matches.

### Replace (single)

Replace the active match's range in the file text:
- **Literal**: substitute the fixed replacement string.
- **Regex**: resolve the replacement *template* (`$1`, `$2`, …) against that single
  match via `NSRegularExpression`. Mutate `text` at the active range, re-run
  matching, keep `currentMatchIndex` on the next match (wrap to 0 past the end,
  mirroring the existing `navigateMatch` wrap).

### Replace All

One text mutation, not N — so it is a single undo step and a single re-highlight:
- **Regex**: `regex.replaceMatches(in:range:withTemplate:)` over an `NSMutableString`.
- **Literal**: single reverse-order pass over the ranges.

Because replace mutates the bound `text`, the existing pipeline handles the rest:
`updateContent` marks the session dirty, highlight pass 1 re-runs, cursor is
preserved, IME (`markedTextRange`) is untouched. **No changes to `CodeEditorView`
or `DocumentSessionStore`.**

## Edge cases

- **Empty replacement** is allowed → deletes matches (standard behavior).
- **Zero-width regex matches** (e.g. `a*`) guarded so Replace All cannot loop forever.
- **Invalid template** (e.g. `$9` with no group 9) → treated as empty by
  `NSRegularExpression`; no crash.
- **Read-only file** (`isEditable == false`) → replace suppressed, buttons disabled.
- **No matches** → Replace / Replace All disabled (same rule as existing prev/next).

## Affected files

- `PockeDev/Screens/Editor/SearchOverlay.swift` — two-row layout; new bindings
  (`replaceText`, `isRegex`, `isCaseSensitive`, `showReplace`, `isInvalidRegex`) and
  callbacks (`onReplace`, `onReplaceAll`).
- `PockeDev/Screens/Editor/EditorContainerView.swift` — regex/replace state and the
  extended matching + replace logic.
- No new files. No changes to `CodeEditorView.swift` or the store.

## Verification

| # | Check | Pass condition |
|---|-------|----------------|
| 1 | Literal Replace All | all `foo`→`bar`; dirty flag set; highlights refresh |
| 2 | Single Replace | only active match replaced; advances to next |
| 3 | Regex capture template | `func (\w+)\(` + `$1_impl(` renames correctly |
| 4 | Case toggle | `Foo` vs `foo` respected in both modes |
| 5 | Invalid regex | "Invalid regex" shown; no crash; buttons disabled |
| 6 | Empty replace | deletes matches |
| 7 | Zero-width regex | no hang/freeze |
| 8 | Large file (100 KB+) | Replace All completes without UI hang |
| 9 | Undo | Replace All reverts as one step (verify UITextView undo) |
| 10 | Find-only regression | collapsed overlay identical to today |
| 11 | Cursor / IME | cursor preserved; no IME interruption |

Checks **8** (large-file performance) and **9** (single-step undo) are the two open
risks to actively test rather than assume; everything else falls out of reusing the
existing search/highlight pipeline.
