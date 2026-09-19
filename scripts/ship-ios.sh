#!/usr/bin/env bash
# ship-ios.sh — archive PockeDev, export a signed .ipa, upload to TestFlight.
#
# Native Swift + XcodeGen pipeline. No Expo, no Fastlane, no Flutter, no EAS.
#   xcodegen generate → xcodebuild archive → -exportArchive → altool --upload-app
#
# Prereqs (local):
#   1. cp .env.signing.example .env.signing  and fill in your ASC API key.
#   2. An Apple Distribution cert in your login keychain (you have one).
#
# Prereqs (GitHub Actions):
#   Secrets + a Distribution .p12 imported into a temporary keychain.
#   See .github/workflows/testflight.yml and docs/DEPLOY.md.
#
# Usage:
#   source .env.signing         # or the script sources it for you
#   ./scripts/ship-ios.sh                 # bump build number, archive, upload
#   ./scripts/ship-ios.sh --no-bump       # ship whatever project.yml says
#   ./scripts/ship-ios.sh --build-number N
#   ./scripts/ship-ios.sh --archive-only  # stop before upload (inspect the .ipa)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUMP=1
UPLOAD=1
BUILD_NUMBER_OVERRIDE="${BUILD_NUMBER:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-bump)      BUMP=0; shift ;;
    --archive-only) UPLOAD=0; shift ;;
    --build-number)
      BUILD_NUMBER_OVERRIDE="${2:?--build-number needs a value}"
      BUMP=0
      shift 2
      ;;
    -h|--help)      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ── env ──
[[ -f .env.signing ]] && source .env.signing

: "${ASC_KEY_ID:?source .env.signing first (see .env.signing.example)}"
: "${ASC_ISSUER_ID:?source .env.signing first}"

# CI may pass the .p8 as base64 instead of a path.
if [[ -n "${ASC_KEY_P8_BASE64:-}" ]]; then
  KEY_DIR="${HOME}/.appstoreconnect/private_keys"
  mkdir -p "$KEY_DIR"
  umask 077
  ASC_KEY_PATH="${ASC_KEY_PATH:-$KEY_DIR/AuthKey_${ASC_KEY_ID}.p8}"
  python3 -c 'import base64,sys; sys.stdout.buffer.write(base64.b64decode(sys.stdin.read()))' \
    <<<"$ASC_KEY_P8_BASE64" > "$ASC_KEY_PATH"
  chmod 600 "$ASC_KEY_PATH"
fi

: "${ASC_KEY_PATH:?source .env.signing first}"
[[ -r "$ASC_KEY_PATH" ]] || { echo "Cannot read ASC .p8 at $ASC_KEY_PATH" >&2; exit 1; }

# altool looks in ~/.appstoreconnect/private_keys/AuthKey_<id>.p8
ALTOOL_DIR="${HOME}/.appstoreconnect/private_keys"
mkdir -p "$ALTOOL_DIR"
ALTOOL_KEY="$ALTOOL_DIR/AuthKey_${ASC_KEY_ID}.p8"
if [[ ! -e "$ALTOOL_KEY" ]] || ! cmp -s "$ASC_KEY_PATH" "$ALTOOL_KEY"; then
  cp "$ASC_KEY_PATH" "$ALTOOL_KEY"
  chmod 600 "$ALTOOL_KEY"
fi

command -v xcodegen >/dev/null || { echo "xcodegen not installed (brew install xcodegen)" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "xcodebuild not found — this pipeline is macOS/Xcode only" >&2; exit 1; }

SCHEME="PockeDev"
BUNDLE_ID="com.pockedev.app"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/PockeDev.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
IPA="$EXPORT_DIR/PockeDev.ipa"

mkdir -p "$BUILD_DIR"

# ── bump / set CURRENT_PROJECT_VERSION (build number) in project.yml ──
# ponytail: sed on the one line, not a YAML parser. project.yml has exactly one
# CURRENT_PROJECT_VERSION. If that stops being true, switch to yq.
CUR=$(grep -E 'CURRENT_PROJECT_VERSION:' project.yml | grep -oE '[0-9]+' | head -1)
NEXT="$CUR"
if [[ -n "$BUILD_NUMBER_OVERRIDE" ]]; then
  [[ "$BUILD_NUMBER_OVERRIDE" =~ ^[0-9]+$ ]] || { echo "--build-number must be a positive integer" >&2; exit 2; }
  NEXT="$BUILD_NUMBER_OVERRIDE"
  if [[ "$(uname)" == Darwin ]]; then
    sed -i '' -E "s/(CURRENT_PROJECT_VERSION: )\"?[0-9]+\"?/\1\"${NEXT}\"/" project.yml
  else
    sed -i -E "s/(CURRENT_PROJECT_VERSION: )\"?[0-9]+\"?/\1\"${NEXT}\"/" project.yml
  fi
  echo "▸ build number: $CUR → $NEXT (override)"
elif (( BUMP )); then
  NEXT=$(( CUR + 1 ))
  if [[ "$(uname)" == Darwin ]]; then
    sed -i '' -E "s/(CURRENT_PROJECT_VERSION: )\"?${CUR}\"?/\1\"${NEXT}\"/" project.yml
  else
    sed -i -E "s/(CURRENT_PROJECT_VERSION: )\"?${CUR}\"?/\1\"${NEXT}\"/" project.yml
  fi
  echo "▸ build number: $CUR → $NEXT"
fi

# ── never reuse a build number App Store Connect already has ──
# altool accepts a duplicate CFBundleVersion and Apple rejects it afterwards by
# email, so the upload looks green while nothing reaches TestFlight.
# ponytail: max over the last 200 uploads; page through /builds if that's ever too few.
if (( UPLOAD )); then
  command -v jq >/dev/null || { echo "jq not installed (brew install jq)" >&2; exit 1; }
  JWT=$(ASC_KEY_ID="$ASC_KEY_ID" ASC_ISSUER_ID="$ASC_ISSUER_ID" ASC_KEY_PATH="$ASC_KEY_PATH" "$ROOT/scripts/asc-jwt.sh")
  asc_get() { curl -sS -G --fail-with-body --connect-timeout 5 --max-time 15 -H "Authorization: Bearer $JWT" "$@"; }
  APP_ID=$(asc_get https://api.appstoreconnect.apple.com/v1/apps \
    --data-urlencode "filter[bundleId]=$BUNDLE_ID" | jq -r '.data[0].id // empty')
  [[ -n "$APP_ID" ]] || { echo "✗ $BUNDLE_ID not found in App Store Connect" >&2; exit 1; }
  LATEST=$(asc_get https://api.appstoreconnect.apple.com/v1/builds \
    --data-urlencode "filter[app]=$APP_ID" \
    --data-urlencode "sort=-uploadedDate" \
    --data-urlencode "limit=200" \
    --data-urlencode "fields[builds]=version" | jq '[.data[].attributes.version | tonumber] | max // 0')
  if (( NEXT <= LATEST )); then
    echo "▸ build number: $NEXT already used in App Store Connect (latest $LATEST) → $((LATEST + 1))"
    NEXT=$(( LATEST + 1 ))
    if [[ "$(uname)" == Darwin ]]; then
      sed -i '' -E "s/(CURRENT_PROJECT_VERSION: )\"?[0-9]+\"?/\1\"${NEXT}\"/" project.yml
    else
      sed -i -E "s/(CURRENT_PROJECT_VERSION: )\"?[0-9]+\"?/\1\"${NEXT}\"/" project.yml
    fi
  fi
fi

echo "▸ regenerating Xcode project"
xcodegen generate --quiet

echo "▸ archiving (Release)"
# Keep the last lines on stdout but still fail if xcodebuild fails (pipefail).
xcodebuild archive \
  -project PockeDev.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="${ASC_TEAM_ID:-GUW6BN8X57}" \
  | tee "$BUILD_DIR/archive.log" | tail -30

echo "▸ exporting signed .ipa"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$ROOT/scripts/ExportOptions.plist" \
  -allowProvisioningUpdates \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  | tee "$BUILD_DIR/export.log" | tail -30

[[ -f "$IPA" ]] || { echo "✗ export produced no .ipa at $IPA" >&2; ls -la "$EXPORT_DIR" >&2 || true; exit 1; }
echo "✓ archived: $IPA"

if (( ! UPLOAD )); then
  echo "▸ --archive-only: stopping before upload."
  exit 0
fi

echo "▸ uploading to App Store Connect"
# Delete leftover IPAs would be a Flutter glob hazard; we upload a single path.
xcrun altool --upload-app \
  --type ios \
  --file "$IPA" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID"

echo "✓ uploaded. Poll processing status with:"
echo "    ./scripts/poll-build.sh $BUNDLE_ID --build-version $NEXT --watch"
