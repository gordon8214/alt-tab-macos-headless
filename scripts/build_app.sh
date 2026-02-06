#!/usr/bin/env bash

set -ex

if [[ -f config/signing-overrides.local.xcconfig ]]; then
  scripts/codesign/setup_team_signing_overrides.sh --check
fi

set -o pipefail && xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Release -derivedDataPath DerivedData | scripts/xcbeautify
file "$BUILD_DIR/$XCODE_BUILD_PATH/$APP_NAME.app/Contents/MacOS/$APP_NAME"
