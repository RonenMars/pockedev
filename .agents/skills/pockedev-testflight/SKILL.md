---
name: pockedev-testflight
description: Use when shipping a PockeDev iOS build to TestFlight — bumps or sets CURRENT_PROJECT_VERSION, runs xcodegen + xcodebuild archive/export, uploads the IPA via xcrun altool with the App Store Connect API key. Triggers on "ship to TestFlight", "deploy PockeDev", "release a PockeDev build", "upload IPA". Native Swift, not Flutter.
---

# PockeDev TestFlight Deployment

End-to-end TestFlight ship for the PockeDev iOS app (SwiftUI + XcodeGen).

Authoritative source for the steps: `docs/DEPLOY.md` in the repo. Read it before
deviating. There is **no Flutter** in this repo — do not run `flutter build ipa`.

## When to Use

- User asks to "ship to TestFlight", "deploy PockeDev", "upload a build", or similar.
- Confirm this is PockeDev: `project.yml` `name: PockeDev`, bundle id `com.pockedev.app`, team `GUW6BN8X57`.

## Local vs GitHub Actions

- **Local Mac** (login keychain already has Apple Distribution): `source .env.signing && ./scripts/ship-ios.sh`
- **CI**: `.github/workflows/testflight.yml` (workflow_dispatch or `v*` tags). Requires the secrets listed in `docs/DEPLOY.md`.

## Preconditions (local)

1. Working tree is clean OR the changes you intend to ship are already committed. If dirty, ask the user before continuing — uncommitted code that ships is a debugging hazard.
2. API key file exists (bootstrap via `./scripts/bootstrap-signing-op.sh` or copy `.env.signing.example` → `.env.signing`). `altool` also needs a copy at `~/.appstoreconnect/private_keys/AuthKey_<id>.p8`.
3. `xcodegen` on PATH (`brew install xcodegen`). System Xcode, not Flutter.

## Identifiers

- Team ID: `GUW6BN8X57`
- Bundle ID: `com.pockedev.app`
- Key ID / Issuer ID: from `.env.signing` (`ASC_KEY_ID`, `ASC_ISSUER_ID`) — never commit the `.p8`.

## Steps (local)

### 1. Bump build number

`./scripts/ship-ios.sh` increments `CURRENT_PROJECT_VERSION` in `project.yml` unless you pass `--no-bump` or `--build-number N`. TestFlight rejects duplicate build numbers within a marketing version (`MARKETING_VERSION`).

Commit the bump (and any other intended changes) — get explicit approval per the user's commit policy before running `git commit`.

### 2. Build IPA

The script runs:

```bash
xcodegen generate
xcodebuild archive ... -allowProvisioningUpdates \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -authenticationKeyPath "$ASC_KEY_PATH"
xcodebuild -exportArchive ... -exportOptionsPlist scripts/ExportOptions.plist
```

Output: `build/export/PockeDev.ipa`.

**Common failure: `exportArchive No signing certificate "iOS Distribution" found`** — the Apple Distribution cert is missing from the keychain. Diagnose:

```bash
security find-identity -v -p codesigning | grep -i distribution
```

If no `Apple Distribution: … (GUW6BN8X57)` row appears, the user must install it via Xcode (cannot be done headless from this environment):

1. Xcode → Settings → **Apple Accounts** → select the team account → team row
2. **Manage Certificates…** → **+** → **Apple Distribution**
3. After they confirm, re-verify with `security find-identity`, then **delete any stale IPA in `build/export/`** before retrying.

### 3. Upload

Handled by the same script (`xcrun altool --upload-app --type ios`). Successful end-state: `No errors uploading '.ipa'`. Takes 1–5 minutes.

`--archive-only` stops before this step.

### 4. Hand off to user

Tell the user:

- Bumped/set build number (e.g. `CURRENT_PROJECT_VERSION` 4)
- IPA path (`build/export/PockeDev.ipa`)
- That Apple processing takes 5–15 minutes before the build appears as "Ready to Test"
- Optional poll: `source .env.signing && ./scripts/poll-build.sh com.pockedev.app --build-version N --watch`

## GitHub Actions

1. Confirm secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`, `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD` exist. If the repo is empty, the user runs `./scripts/push-github-secrets.sh` on their Mac (`gh` + `.env.signing` + a `.p12` path). Do not open `.env.signing`. Do not print secret values.
2. Trigger **TestFlight** via `workflow_dispatch` (or push a `v*` tag).
3. If CI build numbers collide with local ships, set Actions variable `TESTFLIGHT_BUILD_OFFSET`.
4. Do not commit the API key or `.p12`.

## Anti-patterns

- **Don't** run `flutter` / `fvm` / Fastlane / EAS — this app is Swift + XcodeGen.
- **Don't** retry the upload with the same build number — bump first (`--build-number` or let the script increment).
- **Don't** glob `*.ipa` for upload; always use `build/export/PockeDev.ipa`.
- **Don't** add `--verbose` to `altool` unless debugging; it's very chatty.
- **Don't** commit `.env.signing`, `*.p8`, or certificates.
- **Don't** try to fix a missing Apple Distribution cert yourself on a local Mac — keychain installs need user GUI interaction in Xcode.
- **Don't** assume a recent successful ship means the cert still exists. Re-verify with `security find-identity` when export fails on signing.
