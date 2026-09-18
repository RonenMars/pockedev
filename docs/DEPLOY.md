# Deploy — iOS / TestFlight

PockeDev is a native **Swift + XcodeGen** app. It ships to TestFlight with a
small shell pipeline under [`scripts/`](../scripts) — no Fastlane, no EAS, no
Expo. The flow is:

```
bump build number → xcodegen generate → xcodebuild archive → -exportArchive → altool --upload-app
```

## One-time setup

You need an **App Store Connect API key** (role: App Manager). The same key
works for every app on the Apple team (`GUW6BN8X57`) — PockeDev reuses the key
already stored for other apps on this team; a key is scoped to the team, not one
app.

Two ways to get `.env.signing` in place:

### A. From 1Password (recommended)

The credentials live in a 1Password item. [`scripts/bootstrap-signing-op.sh`](../scripts/bootstrap-signing-op.sh)
reads them and writes `.env.signing` for you.

```bash
cp scripts/.env.signing-op.example scripts/.env.signing-op   # then edit vault/item names
eval "$(op signin)"
./scripts/bootstrap-signing-op.sh
```

`scripts/.env.signing-op` names the vault/item/fields to read (not secrets — it's
gitignored anyway). If the `.p8` isn't already on disk, the script materializes
it from the item's `auth_key_b64` field.

### B. By hand

```bash
cp .env.signing.example .env.signing   # then fill in the four values
```

Create the key at
<https://appstoreconnect.apple.com/access/integrations/api>, download the `.p8`,
and point `ASC_KEY_PATH` at it.

Either way, `.env.signing` and any `*.p8` are gitignored — they never get
committed.

## Shipping a build

```bash
source .env.signing
./scripts/ship-ios.sh
```

That bumps `CURRENT_PROJECT_VERSION` in [`project.yml`](../project.yml),
regenerates the Xcode project, archives Release, exports a signed `.ipa`, and
uploads it. Then watch it process:

```bash
./scripts/poll-build.sh com.pockedev.app --watch
```

### Flags

| Command | Effect |
| --- | --- |
| `./scripts/ship-ios.sh` | bump build number, archive, upload |
| `./scripts/ship-ios.sh --no-bump` | ship whatever `project.yml` already says |
| `./scripts/ship-ios.sh --archive-only` | stop after producing the `.ipa` (inspect, don't upload) |
| `./scripts/ship-ios.sh --build-number N` | set `CURRENT_PROJECT_VERSION` to `N` (no +1 bump) |

## Scripts

| File | Purpose |
| --- | --- |
| [`ship-ios.sh`](../scripts/ship-ios.sh) | the pipeline — archive, export, upload |
| [`push-github-secrets.sh`](../scripts/push-github-secrets.sh) | copy local env into GitHub Actions secrets via `gh` |
| [`bootstrap-signing-op.sh`](../scripts/bootstrap-signing-op.sh) | write `.env.signing` from 1Password |
| [`asc-jwt.sh`](../scripts/asc-jwt.sh) | mint a short-lived ES256 JWT for the ASC API |
| [`poll-build.sh`](../scripts/poll-build.sh) | poll ASC for a build's processing state |
| [`ExportOptions.plist`](../scripts/ExportOptions.plist) | export config — automatic signing, team `GUW6BN8X57` |

## GitHub Actions (TestFlight workflow)

[`.github/workflows/testflight.yml`](../.github/workflows/testflight.yml) runs
the same Swift pipeline on `macos-15` (not Flutter). Trigger it from
**Actions → TestFlight → Run workflow**, or push a `v*` tag.

### Push secrets from your Mac

`git` cannot write Actions secrets. Use [`scripts/push-github-secrets.sh`](../scripts/push-github-secrets.sh)
and the GitHub CLI (`gh auth login`, repo admin). It reads the process
environment first, then `.env.signing` / `.env` in the current directory
(or `--env FILE`). `ASC_KEY_PATH` is turned into `ASC_KEY_P8_BASE64`.

```bash
export BUILD_CERTIFICATE_PATH="$HOME/path/to/AppleDistribution.p12"
export P12_PASSWORD='...'          # password from the Keychain .p12 export
# optional: export TESTFLIGHT_BUILD_OFFSET=10
cd /path/to/pockedev
./scripts/push-github-secrets.sh --dry-run
./scripts/push-github-secrets.sh
```

The script never prints secret values. This cloud/Linux environment cannot
run `gh secret set` for you.

### Repository secrets

| Secret | What it is |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |
| `ASC_KEY_P8_BASE64` | `base64` of the `.p8` (no wrapping secrets file in git) |
| `BUILD_CERTIFICATE_BASE64` | Apple Distribution certificate exported as `.p12`, then base64 |
| `P12_PASSWORD` | Password used when exporting that `.p12` |
| `ASC_TEAM_ID` | Optional; defaults in `ship-ios.sh` to `GUW6BN8X57` |

Encode files on a Mac:

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
base64 -i AppleDistribution.p12 | pbcopy
```

Export the `.p12` from Keychain Access: My Certificates → **Apple Distribution:
… (GUW6BN8X57)** → Export → `.p12`.

### Build numbers on CI

TestFlight rejects duplicate `CFBundleVersion` values for the same marketing
version. CI sets `CURRENT_PROJECT_VERSION` to
`TESTFLIGHT_BUILD_OFFSET + github.run_number` (or the workflow input
`build_number`). If that is not greater than the value already in
`project.yml`, the workflow bumps once more.

Set the Actions **variable** `TESTFLIGHT_BUILD_OFFSET` to a number at or above
the last locally shipped build so the first CI run does not collide.

The workflow does **not** commit the bumped `project.yml`. Local ships still
edit the file so the repo records the last Mac-built number.

### SPM / Gitty

`project.yml` points Gitty at `git@github.com:RonenMars/Gitty.git`. The
workflow rewrites `git@github.com:` to `https://github.com/` so SwiftPM can
clone without an SSH key. If Gitty is private, grant the default `GITHUB_TOKEN`
access or switch the package URL to HTTPS with a PAT.

## Signing model

Ships use **automatic** signing (`-allowProvisioningUpdates`) plus the App
Store Connect API key (`-authenticationKey*`). Locally the **Apple
Distribution** cert lives in the login keychain. On GitHub Actions the same
cert is imported from `BUILD_CERTIFICATE_BASE64` into a temporary keychain.

## Troubleshooting

- **`ASC_KEY_ID not set`** — you didn't `source .env.signing` (or it doesn't
  exist yet; see setup above).
- **`Not signed in to op`** — run `eval "$(op signin)"` before the bootstrap
  script.
- **`No app found with bundleId=...`** in `poll-build.sh` — the app record isn't
  visible to this API key, or the key is for a different team.
- **Build stuck in `PROCESSING`** — normal for a few minutes after upload;
  `poll-build.sh --watch` waits it out (30-min cap).
