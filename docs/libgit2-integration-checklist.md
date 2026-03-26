# libgit2 on iOS (Xcode + SwiftPM) — Concrete Implementation Checklist

## Goal
Ship a **maintainable, App-Store-safe, clone-only** Git integration for an iOS app using **libgit2 via SwiftPM**, with a thin Swift wrapper and minimal surface area.

---

## 1. Dependency setup

### SwiftPM
- Pin the libgit2 package to an exact version.
- Do not leave it floating on a branch.
- Avoid adding additional Git-related native dependencies unless there is a concrete need.

### Verify
- The package resolves cleanly on a fresh machine.
- The package builds for:
  - iOS Simulator on Apple Silicon
  - Physical iPhone device
  - Release archive
- No duplicate symbol or linker issues appear after adding the package.

### Action
- In Xcode, open **Package Dependencies** and confirm:
  - exact version pin
  - only the needed product is linked to the app target

---

## 2. Build settings to verify in Xcode

### Architectures / platforms
Verify the app and package build for the actual targets you ship:
- iOS Simulator
- iOS Device
- Release Archive

### Bitcode
- Keep **bitcode disabled**.
- Do not spend time optimizing for bitcode.

### Dead code stripping
- Ensure **Dead Code Stripping** is enabled for Release.
- Ensure standard Release optimization settings are in place.

### Debug symbols
- Keep normal debug symbols for Debug builds.
- Verify Release archiving is not accidentally bloated by unnecessary debug artifacts in the shipped binary.

### Other linker / C settings
- Check that no custom linker flags were added unless they are truly required.
- Avoid random manual C flags unless the package explicitly requires them.

### Verify
- Clean build succeeds.
- Release archive succeeds.
- App launches on real device.
- Clone flow works on real device, not only simulator.

---

## 3. Project structure to use

Keep libgit2 fully contained.

### Recommended files
- `Git/Libgit2Manager.swift`
- `Git/GitCloneService.swift`
- `Git/GitCloneError.swift`
- `Features/CloneRepo/CloneRepoViewModel.swift`
- `Features/CloneRepo/CloneRepoView.swift`

### Strict boundary
Only these files should know about libgit2 symbols:
- `Libgit2Manager.swift`
- `GitCloneService.swift`

The rest of the app should not import or reference libgit2 directly.

---

## 4. One-time library initialization

### Implement
Create a small app-level manager:

- `Libgit2Manager.initialize()`
- internally calls `git_libgit2_init()` once
- guarded so it cannot initialize multiple times accidentally

### Best place to call it
Call it once at app startup:
- SwiftUI `App.init()`
- or `AppDelegate`

### Do not
- do not init/shutdown around every clone
- do not scatter init calls across the codebase

### Verify
- app startup initializes libgit2 exactly once
- clone works repeatedly in the same app session

---

## 5. Thin clone-only service API

### Exported Swift API
Use a small protocol and implementation:

```swift
protocol GitCloning {
    func cloneRepository(
        from urlString: String,
        token: String?,
        to destinationURL: URL
    ) async throws
}
```

### Concrete implementation
`GitCloneService` should:
- validate inputs
- prepare clone options
- optionally configure credentials callback
- call `git_clone`
- translate libgit2 errors into Swift errors

### Do not
- do not expose raw libgit2 pointers outside the service
- do not let UI code know about callbacks or payload pointers
- do not add fetch/pull/push APIs yet

---

## 6. Error model

### Create a Swift error enum
Example categories:
- `invalidURL`
- `authenticationFailed`
- `repositoryNotFound`
- `networkError`
- `destinationAlreadyExists`
- `cloneFailed(message: String)`

### Map libgit2 errors
Map low-level failures into user-readable messages.

### UI rule
`CloneRepoViewModel` should expose:
- user-friendly title/message
- not raw libgit2 error strings by default

### Verify
Test these cases manually:
- bad URL
- private repo without token
- wrong token
- network unavailable
- destination collision

---

## 7. Token handling best practices

### Rules
- Keep token input in memory only.
- Do not persist tokens unless product requirements explicitly require it.
- Clear token state after success or failure where practical.
- Do not log tokens.
- Do not include tokens in analytics or crash reports.

### Credentials callback
If token auth is supported:
- isolate callback logic inside `GitCloneService`
- keep payload objects short-lived
- release any retained objects cleanly after clone completes

### Verify
- private repo clone works
- invalid token shows a clean auth error
- no token appears in logs

---

## 8. Background execution model

### Implement
Run clone off the main thread.

Recommended:
- Swift async entry point
- internal detached/background execution for the blocking libgit2 work
- UI updates return to the main actor in the view model

### UI state
`CloneRepoViewModel` should own:
- `isCloning`
- `progressMessage`
- `errorMessage`
- `didFinishSuccessfully`

### Do not
- do not call blocking libgit2 work on the main thread
- do not let the view directly orchestrate clone logic

### Verify
- UI remains responsive during clone
- loading state appears immediately
- success/error state updates correctly

---

## 9. Progress and cancellation structure

### MVP
Even if you do not fully implement percentage progress yet, structure the code so it can be added safely.

### Best practice
Prepare for:
- libgit2 transfer/progress callbacks
- a cancel flag owned by the view model/service

### Suggested design
- service reports progress via callback or async stream
- view model converts that into UI strings

### Do not
- do not put libgit2 callbacks in the view
- do not block future progress support by hardcoding a fire-and-forget API

---

## 10. Destination directory handling

### Rules
- Generate a safe destination folder name from repo name.
- Resolve collisions by suffixing (`repo`, `repo-1`, `repo-2`, etc.).
- Clone into app-controlled writable storage.

### After success
- register/import the cloned project through existing project flow
- optionally auto-open the cloned repo

### Verify
- duplicate clone names do not overwrite existing projects
- destination path is writable on device
- `.git` remains hidden if your explorer already hides dotfiles

---

## 11. Scope constraints to enforce

### Supported MVP scope
- HTTPS clone
- default branch
- public repos
- optional token auth for private repos if already working cleanly

### Explicitly unsupported for now
- fetch
- pull
- push
- branch switching
- submodules
- SSH keys
- shallow clone unless trivial and already proven stable

### Why
This keeps the native dependency surface small and the UX predictable.

---

## 12. Release-size verification

### Measure, don’t guess
Create a Release archive:
- before libgit2
- after libgit2

Check:
- archive size
- app size estimate
- whether the growth is acceptable for the product stage

### If size looks high
Investigate before changing architecture:
- duplicate linkage
- unnecessary products linked to target
- debug artifacts skewing local perception

---

## 13. Real-device validation checklist

Run all of these on a physical iPhone:

### Public repo clone
- small repo
- medium repo
- mixed text/assets repo

### Private repo clone
- valid token
- invalid token

### Failure handling
- no internet
- malformed URL
- repo not found
- cancellation if implemented

### Post-clone flow
- imported into project list
- project opens correctly
- files visible in explorer
- `.git` hidden

---

## 14. CI / team hygiene

### Dependency hygiene
- keep the package version pinned
- document why libgit2 is used
- document the intentionally limited scope

### CI checks to add later
- simulator build
- release build
- basic smoke test for clone flow if feasible

### Team rule
Any new Git feature request should first answer:
- does this require widening native surface area?
- does this still fit MVP scope?
- is this better deferred?

---

## 15. Recommended code skeleton

### `Libgit2Manager.swift`
Responsibilities:
- one-time initialization
- optional one-time shutdown hook if you decide to manage it

### `GitCloneError.swift`
Responsibilities:
- stable Swift-native error surface
- user-displayable mapping helpers

### `GitCloneService.swift`
Responsibilities:
- input validation
- clone options setup
- credentials callback
- `git_clone` invocation
- error mapping

### `CloneRepoViewModel.swift`
Responsibilities:
- form state
- loading state
- calling the clone service
- importing project on success
- user-facing errors

### `CloneRepoView.swift`
Responsibilities:
- render fields/buttons/messages only
- no libgit2 logic

---

## 16. Final best-practice checklist

### Must-have now
- [ ] libgit2 pinned to exact version
- [ ] builds on simulator + device + release archive
- [ ] `git_libgit2_init()` called once globally
- [ ] clone runs off main thread
- [ ] thin `GitCloning` protocol-based wrapper exists
- [ ] user-friendly error mapping exists
- [ ] token is never persisted or logged
- [ ] destination collision handling exists
- [ ] project import works after clone
- [ ] real-device clone tested

### Nice-to-have next
- [ ] progress callback wired
- [ ] cancellation support
- [ ] auto-open cloned repo after success
- [ ] archive-size comparison documented

---

## 17. Default recommendation for your app

For your current stage, the best-practice setup is:
- keep libgit2
- keep the wrapper thin
- initialize once globally
- support clone only
- keep auth ephemeral
- verify on real device and release archive
- add progress/cancellation before any more Git features
