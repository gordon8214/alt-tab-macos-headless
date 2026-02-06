#!/usr/bin/env bash

set -euo pipefail

target_temp_dir=""
native_arch=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-temp-dir)
      target_temp_dir="$2"
      shift 2
      ;;
    --native-arch)
      native_arch="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$target_temp_dir" || -z "$native_arch" ]]; then
  echo "Usage: $0 --target-temp-dir <dir> --native-arch <arch>" >&2
  exit 1
fi

preferred_file="$target_temp_dir/Objects-normal/$native_arch/AltTabHeadless.SwiftFileList"
if [[ -f "$preferred_file" ]]; then
  printf '%s\n' "$preferred_file"
  exit 0
fi

fallback_file="$(
  find "$target_temp_dir/Objects-normal" -type f -name AltTabHeadless.SwiftFileList -print 2>/dev/null \
    | sort \
    | head -n 1
)"

if [[ -z "$fallback_file" ]]; then
  echo "Could not locate AltTabHeadless.SwiftFileList under $target_temp_dir/Objects-normal" >&2
  exit 1
fi

printf '%s\n' "$fallback_file"
