# AI Pair-Programmer — Design (v1)

**Status:** Draft for review
**Date:** 2026-07-04
**Feature theme:** #1 of the three prioritized ROADMAP themes (see `docs/ROADMAP.md` → "Prioritized themes — 2026-07-04").

---

## 1. Goal

Let a developer, on their phone, have a conversation with an LLM **about the file
that's open in the editor** — ask for an explanation, a bug hunt, or a change —
on a dedicated chat screen, with answers streamed in. When the AI suggests a
change to the file, an **Apply** button shows a diff and asks for approval before
anything is written. This is the thing other mobile code editors don't do well,
and it's what makes PockeDev worth reaching for away from a laptop.

**Success criterion (verifiable):** with a real API key entered for the selected
provider (Anthropic **or** OpenAI), open a Swift file, tap "Ask AI" → a **separate
chat screen** pushes in, type "explain this file", and see a streamed answer
render token-by-token — with the open file's contents sent as context. Then type
"add a doc comment to the top function"; the answer includes a suggested updated
file with an **Apply** button; tapping it shows a **diff** (current vs. suggested)
and, on approval, writes the change back to the open file (marking it dirty) and
returns to the editor. Switching provider and entering that provider's key works
the same way. No key for the selected provider → a clear "add your API key" empty
state, not a crash or silent no-op.

---

## 2. Scope

### In scope (v1)

- A **dedicated chat screen** (pushed navigation from the editor), **not** a
  panel sharing the editor view. The open document is auto-attached as context
  (whole file; see §4.2 on why not selection in v1).
- **Apply-with-diff**: when the AI's answer contains a suggested updated version
  of the file, it gets an **Apply** button. Apply presents a **diff** (current
  vs. suggested) and writes the change to the open file **only on the user's
  approval** — then returns to the editor with the file marked dirty. Reuses the
  existing `DiffView`.
- **Two providers, BYOK**: the user picks a provider (**Anthropic** or
  **OpenAI**) and pastes that provider's own API key. The app calls the
  provider's API **directly from the device** — no proxy, no server of ours. Each
  key is stored in the Keychain, exactly like the existing GitHub PAT.
- **Streaming** responses (SSE), rendered incrementally.
- Code blocks in the answer get a **Copy** button (independent of Apply).
- Per-provider model choice:
  - Anthropic: `claude-opus-4-8` (default), `claude-haiku-4-5` (cheaper/faster).
  - OpenAI: a strong default (e.g. `gpt-4o`) and a cheaper option
    (e.g. `gpt-4o-mini`); exact IDs confirmed at implementation time.
- Graceful states: no key, network error, rate limit, refusal, empty file.

### Out of scope (v1) — deferred, tracked below

- **Selection-scoped editing** ("change *just these lines*"). v1's Apply operates
  on the **whole file** (the model returns a complete updated file; see §4.4).
  Editing a specific selection needs a real selection range threaded from
  `CodeEditorView` (the model has none today) — deferred.
- **AI commit messages** (small follow-up; reuses the same client against the
  staged diff).
- **On-device / hybrid model routing** (Apple Foundation Models). The model
  backend sits behind a protocol so this is an addition, not a rewrite.
- Multi-file / whole-repo context. v1 sends one file.
- Grok / other providers. The `AIClient` protocol makes each a future
  conformance; v1 ships Anthropic + OpenAI.
- Conversation persistence across app launches (in-memory only, matching how
  open tabs already behave — see README "Data Storage").

### Non-goals

- No hosted proxy, no subscription, no server. The app calls each provider's API
  directly from the device; the user's key pays for the user's tokens. (Ponytail:
  don't build infra we don't need.)

---

## 3. Why BYOK, direct-from-app, two providers

**BYOK.** Each provider key is stored in the Keychain — the same proven pattern
PockeDev already uses for the GitHub PAT (`KeychainService.swift`,
`com.pockedev.app / github.token`). Near-zero new infrastructure.

**Direct from the app, no server.** The app POSTs straight to
`api.anthropic.com` / `api.openai.com` over TLS. We considered embedding our own
key so users configure nothing — rejected: a key shipped inside an iOS binary is
extractable and would let anyone spend on our account. A server exists only to
hide such a key; with BYOK there's no key to hide, so there's no server.

**Two providers (Anthropic + OpenAI).** Because the user brings the key, adding a
provider costs only a second `AIClient` conformance — no cost or ops on our side.
Claude is the stronger coding model and is the default; OpenAI is offered for
users who already have an OpenAI key. Frontier models (Claude/GPT/Grok) are
hosted-only — they cannot run on-device — so "on-device real AI" is not on the
table; that option would mean Apple Foundation Models or a bundled open-weight
model, both deferred.

---

## 4. Architecture

Follows the existing SwiftUI + MVVM structure (`Services/`, `Stores/`,
`Screens/`, `Models/`, `DesignSystem/`). New units, each with one clear job:

### 4.1 New files

```
Models/
  ChatMessage.swift          # id, role (.user/.assistant), text, isStreaming
  AIProvider.swift           # enum: .anthropic, .openai — endpoint, header style, Keychain account, model list
  AIModel.swift              # per-provider model options (wire ID + display name)

Services/
  AIClient.swift             # protocol AIClient { func stream(_ req: AIRequest) -> AsyncThrowingStream<String, Error> }
  AnthropicClient.swift      # AIClient — POST /v1/messages, x-api-key, SSE content_block_delta → message_stop
  OpenAIClient.swift         # AIClient — POST /v1/chat/completions, Bearer auth, SSE choices[].delta.content → [DONE]
  AIClientFactory.swift      # AIProvider → the right AIClient (+ its key from Keychain)
  AIContextBuilder.swift     # builds a provider-neutral AIRequest from the open DocumentSession

  SuggestedEdit.swift        # (Models/) a parsed full-file suggestion: originalContent, suggestedContent

Stores/
  ChatStore.swift            # @MainActor ObservableObject: [ChatMessage], send(), streaming state, error state; holds the sessionID it was opened for

Screens/Chat/               # new screen group — chat is its own page, not an editor panel
  ChatScreen.swift           # the pushed screen: message list + input; nav title = file name
  ChatMessageRow.swift       # one bubble; Copy on ``` blocks; Apply on a suggested-edit block
  ApplyEditView.swift        # presents DiffView(original, suggested) + Apply / Cancel

Screens/Settings/            # new screen group (none exists yet)
  AISettingsView.swift       # pick provider, paste/clear that provider's key, pick model
```

`AIRequest` is a provider-neutral value (system text, prior turns, the new user
turn, the attached file, chosen model). Each `AIClient` conformance serializes it
to that provider's wire format and parses that provider's SSE back into a plain
text-delta stream — so `ChatStore` and the UI never branch on provider.

### 4.2 Reused / touched (surgically)

- `KeychainService.swift` — it's an `enum` with static methods keyed to a
  hardcoded `account = "github.token"`. **Add** provider-key methods keyed by
  account name — one Keychain item per provider (`anthropic.key`, `openai.key`).
  Cleanest fit: a small `saveAPIKey(_:for: AIProvider)` / `loadAPIKey(for:)` /
  `deleteAPIKey(for:)` trio that maps the provider to its account string. Do not
  parameterize or refactor the existing PAT methods — leave `github.token` as is.
- `EditorContainerView.swift` — **add** an "Ask AI" button to the top bar that
  **pushes `ChatScreen`** onto the existing navigation stack (the editor is
  already presented via push — its `PDTopBar` has a `chevron.left` →
  `@Environment(\.dismiss)`). Pass the active `sessionID`; the store is read from
  the environment. No editor layout change — chat is a separate page.
- `DocumentSessionStore` — **Apply writes back through the existing
  `updateContent(_:sessionID:)`**, which already sets `isDirty = true`. That is
  the entire write path; the user then saves with the existing Save button. **No
  new persistence, no store changes.**
- `DocumentSession` — **read-only** for context. Already exposes `content`,
  `fileName`, `language` — everything `AIContextBuilder` needs. Has **no selection
  range** (selection lives in the `UITextView` in `CodeEditorView`, not the
  model), which is why v1 operates on the whole file and selection-scoped editing
  is deferred. **No model changes.**
- `DiffView` (`Screens/Explorer/DiffView.swift`) — **reused** by `ApplyEditView`
  to render current-vs-suggested before the write. Verify at implementation time
  that its inputs are two strings (or adapt with a thin wrapper); do not modify it.
- `DesignSystem/` — reuse `PDButton`, `PDInput`, `PDSurface`, `PDEmptyState`,
  `PDTopBar`, `Colors`, `Spacing`, `Motion`. No new design primitives.

### 4.3 Data flow (deterministic — matches DESIGN.md §10.3)

```
User types in ChatScreen
  → ChatStore.send(text)
      → AIContextBuilder.build(open session, history, text) → AIRequest       [Input]
      → AIClientFactory.client(for: selectedProvider)  // Anthropic | OpenAI
      → client.stream(request)  →  AsyncThrowingStream<String>               [State]
      → ChatStore appends tokens to the streaming assistant message          [UI]
      → row renders each delta; ``` blocks get Copy; a suggested-file block   [Feedback]
        gets Apply
```

`ChatStore` is provider-agnostic: it holds an `AIClient`, not a concrete client.
The factory picks the conformance and loads the matching Keychain key.

### 4.4 Apply-with-diff mechanism

The reliable, phone-friendly unit of change is the **whole file**, not a patch.

1. **Ask the model for full files.** The system prompt instructs: "When you
   suggest a change to the open file, output the **complete updated file** in a
   single fenced code block tagged with the file's language. Do not output partial
   snippets or diffs for changes meant to be applied." Explanations stay as prose;
   applyable changes are one full-file block.
2. **Detect.** `ChatMessageRow` treats a fenced block whose content looks like a
   full-file replacement (heuristic: the assistant framed it as the updated file,
   or it's the sole/last large code block in a change-request answer) as a
   `SuggestedEdit { original: session.content, suggested: blockText }`. Every
   fenced block still gets **Copy**; a suggested edit *additionally* gets **Apply**.
3. **Apply → diff → approve.** Apply presents `ApplyEditView`, which shows
   `DiffView(original, suggested)`. On **Apply**, call
   `sessionStore.updateContent(suggested, sessionID:)` (sets dirty) and pop back
   to the editor. On **Cancel**, nothing is written.
4. **Save is still explicit.** Apply only updates the in-memory session (dirty);
   the file on disk changes only when the user taps the editor's existing **Save**
   — consistent with DESIGN.md §1.3 "Save → explicit action."

Ponytail: no patch parser, no snippet-splicing, no three-way merge. Full-file
replace + the existing diff + the existing save. Add finer-grained edits only
when selection-scoped editing lands.

---

## 5. The provider calls

Neither provider ships an official Swift SDK, so both clients use **raw HTTP**
with `URLSession` + a hand-written SSE line reader. Same shape (one POST + a
stream of text deltas), different serialization — which is exactly what the
`AIClient` protocol absorbs. The shared system instruction is: "You are a coding
assistant embedded in a mobile editor. The user's open file is provided as
context. Be concise. **When you suggest a change to the file, output the complete
updated file in one fenced code block tagged with its language — not a partial
snippet or a diff.**" (That last sentence is what makes Apply-with-diff reliable;
see §4.4.) The open file is attached fenced with its filename + language.
`max_tokens` 4096 for v1 (streaming, so no HTTP-timeout concern).

### 5.1 Anthropic (`AnthropicClient`) — verified against the claude-api skill

- **Endpoint:** `POST https://api.anthropic.com/v1/messages`
- **Headers:** `x-api-key: <key>`, `anthropic-version: 2023-06-01`,
  `content-type: application/json`
- **Body:** `{ model, max_tokens, stream: true, system, messages }` — `system` is
  a **top-level** field; the file goes in the user turn's content.
- **SSE:** parse `event: content_block_delta` → `delta.text`; stop on
  `message_stop`.
- **Model:** `claude-opus-4-8` default, `claude-haiku-4-5` cheaper. Omit
  `thinking` (Opus 4.8 runs without it when omitted — right for low-latency chat).

### 5.2 OpenAI (`OpenAIClient`)

- **Endpoint:** `POST https://api.openai.com/v1/chat/completions`
- **Headers:** `Authorization: Bearer <key>`, `content-type: application/json`
- **Body:** `{ model, max_tokens, stream: true, messages }` — the system
  instruction is a `{"role": "system", ...}` **entry in `messages`** (no
  top-level `system` field); the file is appended to the user message.
- **SSE:** parse `data:` lines → `choices[0].delta.content`; stop on the
  `data: [DONE]` sentinel.
- **Model:** a strong default and a cheaper option; exact IDs (e.g. `gpt-4o` /
  `gpt-4o-mini`) confirmed against OpenAI's current model list at implementation
  time.

### 5.3 Error mapping (no silent failures — DESIGN.md §7)

Both providers map onto the same user-facing states:

| HTTP / condition | User-facing state |
|---|---|
| 401 | "API key invalid — check it in AI Settings." |
| 429 | "Rate limited — wait a moment and retry." (retryable) |
| 5xx / network drop | "Couldn't reach the AI service. Retry." (retryable) |
| refusal (Anthropic `stop_reason: "refusal"`; OpenAI content-filter finish) | Show it plainly; don't retry the same prompt. |
| no key for selected provider | Empty state with a button to AI Settings. |
| empty/binary file | Send the question without file context; note "no file attached". |

---

## 6. Security

- Each provider key lives **only** in the Keychain (`com.pockedev.app /
  anthropic.key`, `com.pockedev.app / openai.key`) — one item per provider. Never
  in `UserDefaults`, never logged. Mirrors the PAT rule in "Data Storage".
- A key is read at request-build time and passed to `URLSession`; not held in any
  `@Published` property or written to disk elsewhere.
- Requests go directly from device to `api.anthropic.com` / `api.openai.com` over
  TLS — no proxy of ours. The open file's contents leave the device — inherent to
  a cloud assistant — and must be stated in the AI Settings screen (one line, with
  the selected provider named: "Your open file is sent to <provider> to answer
  your questions.").
- **No embedded key.** We never ship our own provider key in the binary (it would
  be extractable). Only user-supplied keys are used.

---

## 7. Testing / verification

PockeDev has no test target today (README lists none). Following the app's
existing manual-verification practice, v1 is verified by driving the real flow —
plus one isolated, dependency-free check on the pure logic:

1. **SSE parser unit check — one per provider** (the non-trivial pure logic):
   feed each client's parser a captured SSE fixture (Anthropic
   `content_block_delta`…`message_stop`; OpenAI `choices[].delta.content`…
   `[DONE]`) and assert the reassembled text equals the expected answer, and that
   a mid-stream error surfaces as a thrown error. No network, no framework beyond
   `XCTest` if a test target is added; otherwise a `#if DEBUG` `assert`-based
   self-check.
2. **End-to-end manual, both providers:** real key → open a Swift file → "Ask AI"
   pushes the chat screen → "explain this file" → observe streamed tokens +
   attached-context correctness. Repeat after switching provider. (§1 success
   criterion.)
3. **Apply flow:** ask for a change → suggested-file block shows **Apply** → diff
   renders current-vs-suggested → **Apply** writes back and pops to the editor
   with the file dirty → **Save** persists; **Cancel** writes nothing.
4. **State checks:** no-key empty state; provider switch with no key for the new
   provider; airplane-mode network error; a deliberately bad key → 401 copy.

`AIClient` is a protocol, so the store can be exercised against a stub that
emits canned deltas without hitting the network.

---

## 8. Build sequence

1. `AIProvider`, `AIModel`, `ChatMessage`, `AIRequest`, `SuggestedEdit` (pure
   models/values).
2. `AIClient` protocol + `AnthropicClient` (raw HTTP + SSE) + its parser check.
3. `OpenAIClient` + its parser check.
4. `AIClientFactory` + `KeychainService` per-provider key methods.
5. `AIContextBuilder` (open session → `AIRequest`).
6. `ChatStore` (holds an `AIClient`; provider-agnostic; carries the `sessionID`).
7. `AISettingsView` (provider picker + key + model).
8. `ChatScreen` + `ChatMessageRow` (stream render + Copy on code blocks).
9. `ApplyEditView` — detect suggested-file block → **Apply** → `DiffView` →
   `updateContent` on approve.
10. Wire "Ask AI" into `EditorContainerView` (push `ChatScreen`).
11. Manual end-to-end verification, both providers + apply flow (§7).

Each step compiles and is independently reviewable. Anthropic + chat + apply work
end-to-end by step 10 even if OpenAI is descoped — step 3 is the only
OpenAI-specific one.

---

## 9. Deferred work (sequenced)

- **Selection-scoped editing** ("change *just these lines*"). v1's Apply already
  does whole-file suggest → diff → approve (§4.4); scoping it to a selection needs
  a real selection range threaded from `CodeEditorView` (the model has none). The
  diff + approve + `updateContent` write-back all carry over.
- **AI commit messages.** A "Generate" button in `GitCommitView` that sends the
  staged diff through the selected `AIClient`. Small; reuses everything.
- **More providers (Grok, etc.)** — each is a new `AIClient` conformance +
  `AIProvider` case. No other changes.
- **On-device / hybrid routing** — Apple Foundation Models or a bundled
  open-weight model as another `AIClient` conformance + a router, for
  free/offline quick tasks. The protocol boundary exists for exactly this.
