#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
selector_script="$repo_root/scripts/headless/select_swift_file_list.sh"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/headless-swift-list-test.XXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

target_temp_dir="$tmp_dir/Build/Intermediates.noindex/alt-tab-macos.build/Debug/alt-tab-headless.build"
arm64_dir="$target_temp_dir/Objects-normal/arm64"
x86_64_dir="$target_temp_dir/Objects-normal/x86_64"
mkdir -p "$arm64_dir" "$x86_64_dir"

arm64_list="$arm64_dir/AltTabHeadless.SwiftFileList"
x86_64_list="$x86_64_dir/AltTabHeadless.SwiftFileList"
printf '/tmp/arm64.swift\n' > "$arm64_list"
printf '/tmp/x86.swift\n' > "$x86_64_list"

selected="$("$selector_script" --target-temp-dir "$target_temp_dir" --native-arch arm64)"
if [[ "$selected" != "$arm64_list" ]]; then
  echo "Expected arm64 list to be selected, got: $selected" >&2
  exit 1
fi

rm -f "$arm64_list"
selected="$("$selector_script" --target-temp-dir "$target_temp_dir" --native-arch arm64)"
if [[ "$selected" != "$x86_64_list" ]]; then
  echo "Expected fallback list to be selected, got: $selected" >&2
  exit 1
fi

echo "SwiftFileList selector tests passed."
