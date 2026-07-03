#!/usr/bin/env bash
# ship-ios.sh — archive PockeDev, export a signed .ipa, upload to TestFlight.
#
# Native Swift + XcodeGen pipeline. No Expo, no Fastlane, no EAS.
#   xcodegen generate → xcodebuild archive → -exportArchive → altool --upload-app
#
# Prereqs (one-time):
#   1. cp .env.signing.example .env.signing  and fill in your ASC API key.
#   2. An Apple Distribution cert in your login keychain (you have one).
#
# Usage:
#   source .env.signing         # or the script sources it for you
#   ./scripts/ship-ios.sh                 # bump build number, archive, upload
#   ./scripts/ship-ios.sh --no-bump       # ship whatever project.yml says
#   ./scripts/ship-ios.sh --archive-only  # stop before upload (inspect the .ipa)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUMP=1
UPLOAD=1
for arg in "$@"; do
  case "$arg" in
    --no-bump)      BUMP=0 ;;
    --archive-only) UPLOAD=0 ;;
    -h|--help)      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# ── env ──
[[ -f .env.signing ]] && source .env.signing
: "${ASC_KEY_ID:?source .env.signing first (see .env.signing.example)}"
: "${ASC_ISSUER_ID:?source .env.signing first}"
: "${ASC_KEY_PATH:?source .env.signing first}"
command -v xcodegen >/dev/null || { echo "xcodegen not installed (brew install xcodegen)" >&2; exit 1; }

SCHEME="PockeDev"
BUNDLE_ID="com.pockedev.app"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/PockeDev.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
IPA="$EXPORT_DIR/PockeDev.ipa"

mkdir -p "$BUILD_DIR"

# ── bump CURRENT_PROJECT_VERSION (build number) in project.yml ──
# ponytail: sed on the one line, not a YAML parser. project.yml has exactly one
# CURRENT_PROJECT_VERSION. If that stops being true, switch to yq.
if (( BUMP )); then
  CUR=$(grep -E 'CURRENT_PROJECT_VERSION:' project.yml | grep -oE '[0-9]+' | head -1)
  NEXT=$(( CUR + 1 ))
  sed -i '' -E "s/(CURRENT_PROJECT_VERSION: )\"?${CUR}\"?/\1\"${NEXT}\"/" project.yml
  echo "▸ build number: $CUR → $NEXT"
fi

echo "▸ regenerating Xcode project"
xcodegen generate --quiet

echo "▸ archiving (Release)"
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
  | tail -20

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
  | tail -20

[[ -f "$IPA" ]] || { echo "✗ export produced no .ipa at $IPA" >&2; exit 1; }
echo "✓ archived: $IPA"

if (( ! UPLOAD )); then
  echo "▸ --archive-only: stopping before upload."
  exit 0
fi

echo "▸ uploading to App Store Connect"
xcrun altool --upload-app \
  --type ios \
  --file "$IPA" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID"

echo "✓ uploaded. Poll processing status with:"
echo "    ./scripts/poll-build.sh $BUNDLE_ID --watch"
