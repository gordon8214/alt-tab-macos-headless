#!/usr/bin/env bash

set -euo pipefail

sourceFile="config/signing-overrides.local.example.xcconfig"
targetFile="config/signing-overrides.local.xcconfig"

print_usage() {
  cat <<EOF
Usage:
  scripts/codesign/setup_team_signing_overrides.sh
  scripts/codesign/setup_team_signing_overrides.sh --check

Run this script from the repository root.
EOF
}

ensure_repo_root() {
  if [[ ! -f "$sourceFile" ]]; then
    echo "Could not find $sourceFile." >&2
    echo "Run this script from the repository root." >&2
    exit 1
  fi
}

extract_setting() {
  local file="$1"
  local key="$2"

  awk -v key="$key" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      value = $0
      sub(/^[^=]*=/, "", value)
      sub(/[[:space:]]*\/\/.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "$file"
}

validate_override_values() {
  if [[ ! -f "$targetFile" ]]; then
    echo "Missing $targetFile." >&2
    echo "Run scripts/codesign/setup_team_signing_overrides.sh first." >&2
    return 1
  fi

  local development_team
  local code_sign_identity
  development_team="$(extract_setting "$targetFile" "DEVELOPMENT_TEAM")"
  code_sign_identity="$(extract_setting "$targetFile" "CODE_SIGN_IDENTITY")"

  if [[ -z "$development_team" || "$development_team" == "YOUR_TEAM_ID" ]]; then
    echo "$targetFile contains placeholders for DEVELOPMENT_TEAM." >&2
    echo "Set DEVELOPMENT_TEAM to your real Apple Team ID, then rerun with --check." >&2
    return 1
  fi

  if [[ -z "$code_sign_identity" ]]; then
    echo "$targetFile is missing CODE_SIGN_IDENTITY." >&2
    echo "Set CODE_SIGN_IDENTITY, then rerun with --check." >&2
    return 1
  fi

  if [[ "$code_sign_identity" == *"Your Team Name"* || "$code_sign_identity" == *"YOUR_TEAM_ID"* ]]; then
    echo "$targetFile contains placeholders for CODE_SIGN_IDENTITY." >&2
    echo "Set CODE_SIGN_IDENTITY to a real Developer ID certificate, then rerun with --check." >&2
    return 1
  fi

  return 0
}

mode="${1:-setup}"
case "$mode" in
  setup)
    ;;
  --check)
    ;;
  --help|-h)
    print_usage
    exit 0
    ;;
  *)
    print_usage >&2
    exit 1
    ;;
esac

ensure_repo_root

if [[ "$mode" == "--check" ]]; then
  validate_override_values
  echo "Team signing overrides look valid."
  exit 0
fi

if [[ -f "$targetFile" ]]; then
  echo "$targetFile already exists. Keeping existing file."
else
  cp "$sourceFile" "$targetFile"
  echo "Created $targetFile."
fi

if validate_override_values; then
  echo "Team signing overrides look valid."
else
  echo "Update DEVELOPMENT_TEAM and CODE_SIGN_IDENTITY, then run --check before release builds." >&2
fi
