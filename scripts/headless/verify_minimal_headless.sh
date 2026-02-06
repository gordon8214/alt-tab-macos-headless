#!/usr/bin/env bash

set -euo pipefail

WORKSPACE="alt-tab-macos.xcworkspace"
SCHEME="Headless"
CONFIGURATION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

xcodebuild_args=(-workspace "$WORKSPACE" -scheme "$SCHEME")
if [[ -n "$CONFIGURATION" ]]; then
  xcodebuild_args+=(-configuration "$CONFIGURATION")
fi

build_settings="$(
  xcodebuild "${xcodebuild_args[@]}" -showBuildSettings | awk '
    /Build settings for action build and target alt-tab-headless:/ { capture = 1; next }
    /Build settings for action build and target / { if (capture) exit }
    capture { print }
  '
)"

extract_setting() {
  local key="$1"
  local value
  value="$(printf '%s\n' "$build_settings" | ggrep -m1 "^[[:space:]]*$key = " | awk -F' = ' '{print $2}')"
  if [[ -z "$value" ]]; then
    echo "Failed to resolve build setting: $key" >&2
    exit 1
  fi
  printf '%s' "$value"
}

target_build_dir="$(extract_setting TARGET_BUILD_DIR)"
wrapper_name="$(extract_setting WRAPPER_NAME)"
executable_name="$(extract_setting EXECUTABLE_NAME)"
target_temp_dir="$(extract_setting TARGET_TEMP_DIR)"
native_arch="$(extract_setting NATIVE_ARCH_64_BIT)"

app_path="$target_build_dir/$wrapper_name"
binary_path="$app_path/Contents/MacOS/$executable_name"
debug_dylib_path="$app_path/Contents/MacOS/$executable_name.debug.dylib"
frameworks_path="$app_path/Contents/Frameworks"

if [[ ! -f "$binary_path" ]]; then
  echo "Headless binary not found: $binary_path" >&2
  exit 1
fi

forbidden_frameworks=(
  "LetsMove"
  "ShortcutRecorder"
  "Sparkle"
  "SwiftyBeaver"
  "AppCenter"
  "AppCenterCrashes"
)

otool_output="$(otool -L "$binary_path")"
if [[ -f "$debug_dylib_path" ]]; then
  otool_output="$otool_output"$'\n'"$(otool -L "$debug_dylib_path")"
fi

for framework in "${forbidden_frameworks[@]}"; do
  if printf '%s\n' "$otool_output" | ggrep -q "${framework}\\.framework"; then
    echo "Forbidden framework is still linked in headless binary: $framework" >&2
    exit 1
  fi
done

if [[ -d "$frameworks_path" ]]; then
  for framework in "${forbidden_frameworks[@]}"; do
    if [[ -n "$(find "$frameworks_path" -maxdepth 1 -name "${framework}.framework" -print -quit)" ]]; then
      echo "Forbidden framework is still embedded in headless app: $framework" >&2
      exit 1
    fi
  done
fi

swift_file_list="$(scripts/headless/select_swift_file_list.sh --target-temp-dir "$target_temp_dir" --native-arch "$native_arch")"

if [[ -z "$swift_file_list" || ! -f "$swift_file_list" ]]; then
  echo "Could not locate AltTabHeadless.SwiftFileList for target temp dir $target_temp_dir" >&2
  exit 1
fi

banned_sources=(
  "/src/api-wrappers/Logger.swift"
  "/src/logic/Preferences.swift"
  "/src/logic/DebugProfile.swift"
  "/src/api-wrappers/Bash.swift"
  "/src/api-wrappers/Markdown.swift"
  "/src/api-wrappers/HelperExtensionsTestable.swift"
  "/src/logic/Appearance.swift"
  "/src/logic/AppearanceTestable.swift"
  "/src/api-wrappers/MissionControl.swift"
  "/src/logic/events/DockEvents.swift"
  "/src/logic/MacroPreferences.swift"
  "/src/logic/PreferencesMigrations.swift"
  "/src/headless/shims/WindowCaptureShims.swift"
  "/src/logic/events/SpacesEvents.swift"
  "/src/logic/events/ScreensEvents.swift"
  "/src/headless/shims/InputShims.swift"
  "/src/headless/shims/DebugMenuShim.swift"
)

for banned_source in "${banned_sources[@]}"; do
  if ggrep -Fq "$banned_source" "$swift_file_list"; then
    echo "Banned source is still compiled in headless target: $banned_source" >&2
    exit 1
  fi
done

source_count="$(wc -l < "$swift_file_list" | awk '{ print $1 }')"
if [[ "$source_count" -gt 30 ]]; then
  echo "Headless compile graph too large: $source_count sources (expected <= 30)" >&2
  exit 1
fi

echo "Headless minimalism verification passed: $source_count sources, no forbidden frameworks linked or embedded."
