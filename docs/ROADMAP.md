# Roadmap

## Direction — prioritized themes (2026-07-04)

Three "why reach for PockeDev on a phone" moments, in build priority. **AI pair-programming is the lead direction.** The first theme is being taken into a full design (see `docs/superpowers/specs/`).

1. **AI pair-programmer (primary).** Chat with an LLM about the open file — explanations, edits, and generation inline over your real repo. The phone becomes a conversational coding assistant, the thing you can't easily do in other mobile editors.
2. **Review & fix on the go (second).** Away from the desk: read code, review a PR/diff, make a small fix, commit & push. Quick-hit edits, not deep work. Builds on existing Git strengths (diff viewer, commit/push, branch switcher).
3. **Remote control / ops (third).** SSH into a server or dev environment (Codespaces, a VPS) to check logs, run commands, restart services, edit remote files. Phone as a terminal.

**Strategic through-line:** don't chase local code execution (Apple's sandbox forbids it) — own offline editing + real Git + language intelligence, which is the community's own fallback when remote dev fails.

> **Note on the git items:** the following tasks come from a checklist written against a raw `libgit2` dependency — [#1](#idx-1), [#2](#idx-2), [#3](#idx-3), [#4](#idx-4), [#5](#idx-5), [#6](#idx-6), [#7](#idx-7). libgit2 has since been replaced by **Gitty** (see the README Changelog), which handles global init, off-main-thread work, and error mapping internally. The listed items are the ones Gitty does **not** already cover — the rest are satisfied by the migration.

> **Note on Effort & Dependency:** these two columns are estimates, not stated in the source notes. Effort is a rough T-shirt size (S / M / L / XL). Treat them as a starting point, not a commitment.

## Backlog

| Idx | Task | Description | Category | Type | Priority | Effort | Dependency |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <a id="idx-1"></a>1 | Real-device clone tested | Confirm Gitty clone works on a physical device, not just simulator | Verify (Gitty) | Follow-up | P1 | S | — |
| <a id="idx-2"></a>2 | Release-archive build verified | Confirm a Release archive builds & runs (sim + device already pass) | Verify (Gitty) | Follow-up | P1 | S | — |
| <a id="idx-3"></a>3 | Token never persisted or logged | Confirm Keychain-only token path holds through Gitty (no disk/log leak) | Verify (Gitty) | Follow-up | P1 | M | — |
| <a id="idx-4"></a>4 | Destination-collision handling on clone | Handle cloning into an existing/occupied destination path | Verify (Gitty) | Follow-up | P1 | M | — |
| <a id="idx-5"></a>5 | Progress callback wired into clone/fetch | Consume the progress Gitty already exposes in the clone/fetch UI | Git | Enhancement | P2 | M | — |
| <a id="idx-6"></a>6 | Cancellation for long-running clone/pull | Let the user cancel an in-flight clone or pull | Git | Enhancement | P2 | M | #5 |
| <a id="idx-7"></a>7 | Auto-open cloned repo after success | Open the repo automatically once a clone completes | Git | Enhancement | P2 | S | — |
| 8 | Tab close button on active tab only | Show the tab close button only on the active tab, hidden on the rest (no hover state on touch; `DESIGN.md` §tabs) | UI polish | Enhancement | P3 | S | — |
| 9 | Archive-size comparison doc | Document Gitty vs. previous archive-size comparison | Docs | Other | P3 | S | — |
| 10 | Regex find & replace | In-file find & replace with capture-group templates + live highlighting | Editor | Feature | P1 (selected) | L | — |
| 11 | Multi-caret / multi-cursor editing | Edit at multiple carets simultaneously | Editor | Feature | Unprioritized | L | — |
| 12 | Tree-sitter incremental highlighting | Incremental syntax highlighting, scale from 8 languages toward 20–150 | Editor | Feature | Unprioritized | XL | — |
| 13 | Large-file performance engine | Editor stays fast on very large files | Editor | Feature | Unprioritized | XL | — |
| 14 | Code completion / IntelliSense / LSP | Language-server-backed completions & diagnostics | Editor | Feature | Theme 1 (AI) | XL | — |
| 15 | Code formatting / prettifying | Format via Prettier, Emmet, etc. | Editor | Feature | Unprioritized | M | — |
| 16 | Minimap + folding + outline nav | Minimap, code folding, symbol/outline navigation | Editor | Feature | Unprioritized | L | — |
| 17 | Snippets / custom templates | User-defined snippets and templates | Editor | Feature | Unprioritized | M | — |
| 18 | Custom syntax defs & themes | TextMate/Sublime-compatible syntax definitions & themes | Editor | Feature | Unprioritized | L | #12 |
| 19 | Popular dark themes | One Dark Pro, Dracula, Solarized + syntax-highlight quality | Editor | Enhancement | Unprioritized | M | — |
| 20 | Opt-in AI assistance | Inline/on-device AI editing + AI commit messages | AI | Feature | Theme 1 (AI) | XL | — |
| 21 | Git history / commit graph viewer | View log / history / commit graph | Git | Feature | Theme 2 (Review) | L | — |
| 22 | Conflict resolution + merge tool | Merge/rebase conflict resolution with a visual merge tool | Git | Feature | Theme 2 (Review) | XL | #21 |
| 23 | Advanced Git ops | rebase, stash, cherry-pick, revert, reset, tags, submodules, worktrees, LFS, signing | Git | Feature | Unprioritized | XL | — |
| 24 | Pull Request workflows in-app | Create/review/manage PRs inside the app | Git | Feature | Theme 2 (Review) | XL | — |
| 25 | Better mobile Git/PR review client | Best-in-class on-the-go PR review experience | Git | Feature | Theme 2 (Review) | L | #24 |
| 26 | SSH-remote Git | Git over SSH remotes | Git | Feature | Theme 3 (Remote) | L | #30 |
| 27 | Files-app document-provider integration | Expose repos through the iOS Files app | Git | Feature | Unprioritized | M | — |
| 28 | Real-time collaboration | Live collaboration / pair programming | Git | Feature | Unprioritized | XL | — |
| 29 | Built-in SSH terminal / shell | In-app SSH terminal | Remote | Feature | Theme 3 (Remote) | XL | — |
| 30 | Resilient remote/SSH sessions | Sessions survive backgrounding (Mosh/tmux-style reconnect) | Remote | Feature | Theme 3 (Remote) | XL | #29 |
| 31 | Multi-hop / jump hosts + key mgmt | Jump hosts, SSH agent, Secure Enclave key management | Remote | Feature | Theme 3 (Remote) | L | #29 |
| 32 | Broad remote + cloud connectivity | SFTP/FTP/WebDAV + Dropbox/Drive/OneDrive, edit-in-place | Remote | Feature | Unprioritized | XL | — |
| 33 | External keyboard + trackpad support | Hardware keyboard, trackpad/mouse, customizable extra key row | UX | Feature | Unprioritized | L | — |
| 34 | Configurable keyboard shortcuts | Configurable shortcuts + ESC/Ctrl remapping | UX | Enhancement | Unprioritized | M | — |
| 35 | Best-in-class touch text interaction | Cursor, selection, two-finger scroll refinement | UX | Enhancement | Unprioritized | L | — |
| 36 | Multi-window / Split View | Tabbed sessions with restore, Split View, multi-window | UX | Feature | Unprioritized | L | — |
| 37 | Modern iOS API polish | Live Activities for Git ops, background ops, Secure Enclave, Vision Pro | UX | Enhancement | Unprioritized | L | — |
| 38 | Apple Shortcuts / Siri automation | Shortcuts, Siri automation, URL schemes | Automation | Feature | Unprioritized | M | — |
| 39 | Live web preview | Live web preview with JS console / dev tools | Automation | Feature | Unprioritized | L | — |
| 40 | On-device code execution / runtime | Run code on-device (blocked by Apple sandbox — see through-line) | Automation | Feature | Unprioritized | XL | — |
| 41 | Drag-and-drop native UI builder | Visual drag-and-drop UI builder | Automation | Feature | Unprioritized | XL | — |
| 42 | Extensions / plugin ecosystem | Third-party extensions / plugins | Ecosystem | Feature | Unprioritized | XL | — |
