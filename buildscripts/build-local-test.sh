#!/bin/bash
set -euo pipefail

# Build a universal (arm64 + x86_64) debug build of NetNewsWire
# and copy it to the Desktop for testing on local machines.

PROJECT_PATH="NetNewsWire.xcodeproj"
SCHEME="NetNewsWire"
DESTINATION="platform=macOS"
DESKTOP="$HOME/Desktop"
APP_NAME="NetNewsWire.app"

echo "Building universal binary..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  ARCHS="x86_64 arm64" \
  ONLY_ACTIVE_ARCH=NO \
  build | xcbeautify

# Find the built app in DerivedData.
BUILD_DIR=$(xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -showBuildSettings 2>/dev/null \
  | grep -m1 '^\s*BUILT_PRODUCTS_DIR' \
  | sed 's/.*= //')

BUILT_APP="$BUILD_DIR/$APP_NAME"

if [ ! -d "$BUILT_APP" ]; then
  echo "Error: could not find $BUILT_APP"
  exit 1
fi

# Verify it's actually universal.
ARCHS=$(lipo -archs "$BUILT_APP/Contents/MacOS/NetNewsWire")
echo "Architectures: $ARCHS"

if [[ "$ARCHS" != *"x86_64"* ]] || [[ "$ARCHS" != *"arm64"* ]]; then
  echo "Error: build is not universal"
  exit 1
fi

# Copy to Desktop, replacing any existing copy.
rm -rf "$DESKTOP/$APP_NAME"
cp -R "$BUILT_APP" "$DESKTOP/$APP_NAME"

echo "Copied $APP_NAME to $DESKTOP"
echo "Remember: on the test machine, right-click > Open or run: xattr -cr $APP_NAME"
