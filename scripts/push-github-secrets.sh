#!/usr/bin/env bash
# push-github-secrets.sh — copy local signing credentials into GitHub Actions
# secrets/variables via the GitHub CLI (`gh`). `git` cannot set Actions secrets.
#
# Reads:
#   1. already-exported process environment (wins over files)
#   2. --env FILE (repeatable; first file wins for a given key if OS unset)
#   3. otherwise ./.env.signing then ./.env in the directory you run from
#
# Maps local ship-ios vars onto the TestFlight workflow names:
#   ASC_KEY_PATH → secret ASC_AUTH_KEY_B64 (file contents, base64)
#   BUILD_CERTIFICATE_PATH or P12_PATH → secret IOS_DIST_CERT_P12_B64
#     (unset → exported from the login keychain; P12_PASSWORD is generated if unset)
#
# Usage (run on your Mac; gh must be logged in with repo admin):
#   ./scripts/push-github-secrets.sh --dry-run
#   ./scripts/push-github-secrets.sh
#   ./scripts/push-github-secrets.sh --repo RonenMars/pockedev --env .env.signing
#
# Does not print secret values.

set -euo pipefail

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

DRY_RUN=0
REPO=""
ENV_FILES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --repo) REPO="${2:?--repo needs owner/name}"; shift 2 ;;
    --env)
      ENV_FILES="${ENV_FILES}${ENV_FILES:+$'\n'}${2:?--env needs a path}"
      shift 2
      ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Only these names are imported from dotenv files (so PATH etc. stay intact).
LOAD_KEYS="ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH ASC_KEY_P8_BASE64 ASC_TEAM_ID BUILD_CERTIFICATE_BASE64 BUILD_CERTIFICATE_PATH P12_PATH P12_PASSWORD TESTFLIGHT_BUILD_OFFSET"

os_has() {
  eval "[[ -n \"\${$1:-}\" ]]"
}

# Import unset LOAD_KEYS from a sourced file, via a subshell + JSON.
import_file() {
  local file="$1"
  [[ -f "$file" ]] || { echo "Env file not found: $file" >&2; exit 1; }
  echo "▸ reading $file"
  local json
  json="$(
    export KEEP_KEYS="$LOAD_KEYS"
    # shellcheck disable=SC1090
    set -a
    source "$file"
    set +a
    python3 -c '
import json, os
keys = os.environ.get("KEEP_KEYS", "").split()
print(json.dumps({k: os.environ[k] for k in keys if os.environ.get(k)}))
'
  )"
  local k val
  for k in $LOAD_KEYS; do
    if os_has "$k"; then
      continue
    fi
    val="$(
      KEY="$k" python3 -c '
import json, os, sys
data = json.load(sys.stdin)
sys.stdout.write(data.get(os.environ["KEY"]) or "")
' <<<"$json"
    )"
    if [[ -n "$val" ]]; then
      printf -v "$k" '%s' "$val"
      export "$k"
    fi
  done
}

b64_file() {
  local path="$1"
  [[ -r "$path" ]] || { echo "Cannot read file for $2" >&2; exit 1; }
  python3 -c 'import base64,sys; sys.stdout.write(base64.b64encode(open(sys.argv[1],"rb").read()).decode("ascii"))' "$path"
}

CWD="$(pwd)"
if [[ -z "$ENV_FILES" ]]; then
  [[ -f "$CWD/.env.signing" ]] && ENV_FILES="$CWD/.env.signing"
  if [[ -f "$CWD/.env" ]]; then
    ENV_FILES="${ENV_FILES}${ENV_FILES:+$'\n'}$CWD/.env"
  fi
fi

if [[ -n "$ENV_FILES" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    import_file "$f"
  done <<< "$ENV_FILES"
fi

if [[ -z "${ASC_KEY_P8_BASE64:-}" && -n "${ASC_KEY_PATH:-}" ]]; then
  echo "▸ encoding .p8 from ASC_KEY_PATH"
  ASC_KEY_P8_BASE64="$(b64_file "$ASC_KEY_PATH" ASC_KEY_PATH)"
  export ASC_KEY_P8_BASE64
fi

CERT_PATH="${BUILD_CERTIFICATE_PATH:-${P12_PATH:-}}"
if [[ -z "${BUILD_CERTIFICATE_BASE64:-}" && -n "$CERT_PATH" ]]; then
  echo "▸ encoding .p12 from BUILD_CERTIFICATE_PATH/P12_PATH"
  BUILD_CERTIFICATE_BASE64="$(b64_file "$CERT_PATH" BUILD_CERTIFICATE_PATH)"
  export BUILD_CERTIFICATE_BASE64
fi

# No .p12 on disk? The Distribution cert lives in the login keychain (same as
# tb-mobile), so export it from there. Keychain Access may prompt to allow the
# export. ponytail: `security export` can't pick one identity, so the .p12 holds
# every identity in the login keychain; harmless, xcodebuild picks the right one.
if [[ -z "${BUILD_CERTIFICATE_BASE64:-}" && -z "$CERT_PATH" ]]; then
  security find-identity -v -p codesigning | grep -q "Apple Distribution" \
    || { echo "No 'Apple Distribution' identity in login keychain; set BUILD_CERTIFICATE_PATH" >&2; exit 1; }
  echo "▸ exporting Distribution identity from login keychain"
  P12_PASSWORD="${P12_PASSWORD:-$(openssl rand -hex 16)}"
  export P12_PASSWORD
  tmp_p12="$(mktemp -t dist).p12"
  trap 'rm -f "$tmp_p12"' EXIT
  security export -k login.keychain-db -t identities -f pkcs12 -P "$P12_PASSWORD" -o "$tmp_p12" >/dev/null
  BUILD_CERTIFICATE_BASE64="$(b64_file "$tmp_p12" keychain-export)"
  export BUILD_CERTIFICATE_BASE64
fi

command -v gh >/dev/null || { echo "gh CLI not installed: https://cli.github.com/" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
[[ -n "$REPO" ]] || { echo "Could not detect GitHub repo. Pass --repo owner/name" >&2; exit 1; }

echo "▸ target repo: $REPO"
if (( DRY_RUN == 0 )); then
  gh auth status >/dev/null
fi

put_secret() {
  local name="$1" value="${2:-}"
  if [[ -z "$value" ]]; then
    echo "  skip secret $name (empty)"
    return 0
  fi
  if (( DRY_RUN )); then
    echo "  would set secret $name (${#value} chars)"
    return 0
  fi
  printf '%s' "$value" | gh secret set "$name" --repo "$REPO"
  echo "  set secret $name"
}

put_var() {
  local name="$1" value="${2:-}"
  if [[ -z "$value" ]]; then
    echo "  skip variable $name (empty)"
    return 0
  fi
  if (( DRY_RUN )); then
    echo "  would set variable $name"
    return 0
  fi
  printf '%s' "$value" | gh variable set "$name" --repo "$REPO"
  echo "  set variable $name"
}

missing=0
for req in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_P8_BASE64 BUILD_CERTIFICATE_BASE64 P12_PASSWORD; do
  if [[ -z "${!req:-}" ]]; then
    echo "✗ missing $req" >&2
    missing=1
  fi
done
if (( missing )); then
  cat >&2 <<EOF
Need every TestFlight secret before writing to GitHub.

From .env.signing (or the environment):
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH  →  ASC_KEY_P8_BASE64
  ASC_TEAM_ID (optional)

Plus a Distribution .p12. Leave both unset to export it from the login keychain,
or point at an existing file:
  export BUILD_CERTIFICATE_PATH=/path/to/AppleDistribution.p12
  export P12_PASSWORD='...'

Optional:
  export TESTFLIGHT_BUILD_OFFSET=10

Then:  ./scripts/push-github-secrets.sh --dry-run
EOF
  exit 1
fi

echo "▸ secrets"
put_secret ASC_KEY_ID "$ASC_KEY_ID"
put_secret ASC_ISSUER_ID "$ASC_ISSUER_ID"
put_secret ASC_AUTH_KEY_B64 "$ASC_KEY_P8_BASE64"
put_secret IOS_DIST_CERT_P12_B64 "$BUILD_CERTIFICATE_BASE64"
put_secret IOS_DIST_CERT_PASSWORD "$P12_PASSWORD"
put_secret ASC_TEAM_ID "${ASC_TEAM_ID:-}"

echo "▸ variables"
put_var TESTFLIGHT_BUILD_OFFSET "${TESTFLIGHT_BUILD_OFFSET:-}"

echo "✓ done (values not printed). Confirm in GitHub → Settings → Secrets and variables → Actions"
