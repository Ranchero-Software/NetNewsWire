#!/bin/bash
set -euo pipefail

# Copies the app on the Desktop on a local Intel laptop in Brent’s office.
# rsync doesn't add the quarantine flag, so the app launches without notarization.

REMOTE_HOST="heinlein.local"
SOURCE_APP="$HOME/Desktop/NetNewsWire.app"

if [ ! -d "$SOURCE_APP" ]; then
	echo "❌ $SOURCE_APP not found. Build app first."
	exit 1
fi

echo "🚚 Copying to $REMOTE_HOST..."
rsync -a --delete "$SOURCE_APP" "$REMOTE_HOST:Desktop/"
echo "✅ Copied to $REMOTE_HOST:Desktop/NetNewsWire.app"
