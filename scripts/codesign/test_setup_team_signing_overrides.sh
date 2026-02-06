#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
setup_script="$repo_root/scripts/codesign/setup_team_signing_overrides.sh"
template_file="$repo_root/config/signing-overrides.local.example.xcconfig"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/team-signing-setup-test.XXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

mkdir -p "$tmp_dir/scripts/codesign" "$tmp_dir/config"
cp "$setup_script" "$tmp_dir/scripts/codesign/setup_team_signing_overrides.sh"
cp "$template_file" "$tmp_dir/config/signing-overrides.local.example.xcconfig"
chmod +x "$tmp_dir/scripts/codesign/setup_team_signing_overrides.sh"

setup_output="$(
  cd "$tmp_dir"
  scripts/codesign/setup_team_signing_overrides.sh 2>&1
)"
if [[ ! -f "$tmp_dir/config/signing-overrides.local.xcconfig" ]]; then
  echo "Expected setup script to create config/signing-overrides.local.xcconfig" >&2
  exit 1
fi
if ! printf '%s\n' "$setup_output" | ggrep -q "Update DEVELOPMENT_TEAM and CODE_SIGN_IDENTITY"; then
  echo "Expected setup output to remind user to update placeholder values" >&2
  exit 1
fi

set +e
placeholder_check_output="$(
  cd "$tmp_dir"
  scripts/codesign/setup_team_signing_overrides.sh --check 2>&1
)"
placeholder_check_status=$?
set -e
if [[ "$placeholder_check_status" -eq 0 ]]; then
  echo "Expected --check to fail when placeholders are unchanged" >&2
  exit 1
fi
if ! printf '%s\n' "$placeholder_check_output" | ggrep -q "contains placeholders for DEVELOPMENT_TEAM"; then
  echo "Expected --check output to explain placeholder failure" >&2
  exit 1
fi

gsed -i 's/YOUR_TEAM_ID/ABCDE12345/g' "$tmp_dir/config/signing-overrides.local.xcconfig"
gsed -i 's/Your Team Name/Example Corp/g' "$tmp_dir/config/signing-overrides.local.xcconfig"

valid_check_output="$(
  cd "$tmp_dir"
  scripts/codesign/setup_team_signing_overrides.sh --check 2>&1
)"
if ! printf '%s\n' "$valid_check_output" | ggrep -q "Team signing overrides look valid."; then
  echo "Expected --check success confirmation after replacing placeholders" >&2
  exit 1
fi

set +e
wrong_cwd_output="$(
  cd "$tmp_dir/scripts"
  ./codesign/setup_team_signing_overrides.sh 2>&1
)"
wrong_cwd_status=$?
set -e
if [[ "$wrong_cwd_status" -eq 0 ]]; then
  echo "Expected setup script to fail outside repository root" >&2
  exit 1
fi
if ! printf '%s\n' "$wrong_cwd_output" | ggrep -q "Run this script from the repository root."; then
  echo "Expected cwd failure message to explain repository root requirement" >&2
  exit 1
fi

echo "Team signing override setup tests passed."
