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

## Scripts

| File | Purpose |
| --- | --- |
| [`ship-ios.sh`](../scripts/ship-ios.sh) | the pipeline — archive, export, upload |
| [`bootstrap-signing-op.sh`](../scripts/bootstrap-signing-op.sh) | write `.env.signing` from 1Password |
| [`asc-jwt.sh`](../scripts/asc-jwt.sh) | mint a short-lived ES256 JWT for the ASC API |
| [`poll-build.sh`](../scripts/poll-build.sh) | poll ASC for a build's processing state |
| [`ExportOptions.plist`](../scripts/ExportOptions.plist) | export config — automatic signing, team `GUW6BN8X57` |

## Signing model

Ships use **automatic** signing (`-allowProvisioningUpdates`) against the
**Apple Distribution** cert in the login keychain. No manual provisioning-profile
UUIDs to track. If you ever move to headless CI (no keychain), that's when to
add manual cert/profile import — see how `tb-mobile` does it.

## Troubleshooting

- **`ASC_KEY_ID not set`** — you didn't `source .env.signing` (or it doesn't
  exist yet; see setup above).
- **`Not signed in to op`** — run `eval "$(op signin)"` before the bootstrap
  script.
- **`No app found with bundleId=...`** in `poll-build.sh` — the app record isn't
  visible to this API key, or the key is for a different team.
- **Build stuck in `PROCESSING`** — normal for a few minutes after upload;
  `poll-build.sh --watch` waits it out (30-min cap).
