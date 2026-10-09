#!/bin/bash
set -euo pipefail

# Archives NetNewsWire for Mac, exports it signed with Developer ID (not notarized), and copies it to the Desktop.
# For testing on other Macs: copy via rsync/scp so the app isn't quarantined.
# Note: depends on xcbeautify: <https://github.com/cpisciotta/xcbeautify>

PROJECT_PATH="NetNewsWire.xcodeproj"
SCHEME_MAC="NetNewsWire"
APP_NAME="NetNewsWire.app"
DESTINATION_APP="$HOME/Desktop/$APP_NAME"

WORK_DIRECTORY="$(mktemp -d)"
trap 'rm -rf "$WORK_DIRECTORY"' EXIT

ARCHIVE_PATH="$WORK_DIRECTORY/NetNewsWire.xcarchive"
EXPORT_PATH="$WORK_DIRECTORY/Export"
EXPORT_OPTIONS_PATH="$WORK_DIRECTORY/ExportOptions.plist"

cd "$(dirname "$0")/.."

echo "🛠 Archiving..."
xcodebuild \
	-project "$PROJECT_PATH" \
	-scheme "$SCHEME_MAC" \
	-configuration Release \
	-destination "generic/platform=macOS" \
	-archivePath "$ARCHIVE_PATH" \
	-allowProvisioningUpdates \
	archive | xcbeautify --quiet

TEAM_ID="$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:Team" "$ARCHIVE_PATH/Info.plist")"

cat > "$EXPORT_OPTIONS_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>destination</key>
	<string>export</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>$TEAM_ID</string>
</dict>
</plist>
EOF

echo "📦 Exporting with Developer ID..."
xcodebuild \
	-exportArchive \
	-archivePath "$ARCHIVE_PATH" \
	-exportPath "$EXPORT_PATH" \
	-exportOptionsPlist "$EXPORT_OPTIONS_PATH" \
	-allowProvisioningUpdates | xcbeautify --quiet

rm -rf "$DESTINATION_APP"
ditto "$EXPORT_PATH/$APP_NAME" "$DESTINATION_APP"

codesign --verify --deep --strict "$DESTINATION_APP"
echo "✅ $DESTINATION_APP"
echo "Copy with: rsync -a --delete \"$DESTINATION_APP\" other-mac.local:Desktop/"
