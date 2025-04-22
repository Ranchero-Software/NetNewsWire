#!/bin/bash
set -euo pipefail

# This script is for checking that both Mac and iOS targets build and that tests pass.
# Note: depends on xcbeautify: <https://github.com/cpisciotta/xcbeautify>

# === CONFIGURABLE VARIABLES ===
PROJECT_PATH="NetNewsWire.xcodeproj"
SCHEME_MAC="NetNewsWire"
SCHEME_IOS="NetNewsWire-iOS"
DESTINATION_MAC="platform=macOS,arch=arm64"
DESTINATION_IOS="platform=iOS Simulator,name=iPhone 16"

echo "🛠 Building macOS target..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_MAC" \
  -destination "$DESTINATION_MAC" \
  clean build | xcbeautify

echo "🛠 Building iOS target..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_IOS" \
  -destination "$DESTINATION_IOS" \
  clean build | xcbeautify

echo "✅ Builds completed."

echo "🧪 Running tests for macOS target..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_MAC" \
  -destination "$DESTINATION_MAC" \
  test | xcbeautify

echo "🧪 Running tests for iOS target..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_IOS" \
  -destination "$DESTINATION_IOS" \
  test | xcbeautify

echo "🔎 Running Swift Package tests..."


# Run `swift test` for each directory containing a Package.swift
find . -type f -name Package.swift | while read -r package_file; do
  package_dir=$(dirname "$package_file")
  echo "📦 Testing package in: $package_dir"
  pushd "$package_dir" > /dev/null
  swift test
  popd > /dev/null
done

echo "🎉 All builds and tests completed successfully."
echo "🎉 All builds and tests completed successfully."
