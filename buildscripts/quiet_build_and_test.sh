#!/bin/bash
set -euo pipefail

# This script is for checking that both Mac and iOS targets build and that tests pass.
# Note: depends on xcbeautify: <https://github.com/cpisciotta/xcbeautify>

# === CONFIGURABLE VARIABLES ===
PROJECT_PATH="NetNewsWire.xcodeproj"
SCHEME_MAC="NetNewsWire"
SCHEME_IOS="NetNewsWire-iOS"
DESTINATION_MAC="platform=macOS,arch=arm64"
DESTINATION_IOS="platform=iOS Simulator,name=iPhone 17"

echo "🛠 Building macOS target..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_MAC" \
  -destination "$DESTINATION_MAC" \
  CODE_SIGNING_ALLOWED=NO \
  clean build | xcbeautify --quiet

echo "🛠 Building iOS target..."
OS_ACTIVITY_MODE=disable xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_IOS" \
  -destination "$DESTINATION_IOS" \
  CODE_SIGNING_ALLOWED=NO \
  clean build | xcbeautify --quiet

echo "✅ Builds completed."

echo "🧪 Running tests for macOS target..."
OS_ACTIVITY_MODE=disable xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_MAC" \
  -destination "$DESTINATION_MAC" \
  CODE_SIGNING_ALLOWED=NO \
  test 2>&1 | xcbeautify --quiet | sed '/CoreData/d;/persistence/d'

echo "🎉 All builds and tests completed successfully."
