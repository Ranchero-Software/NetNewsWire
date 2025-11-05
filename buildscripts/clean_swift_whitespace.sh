#!/bin/bash
set -euo pipefail

# This script cleans whitespace-only lines in all .swift files in the project.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLEAN_SCRIPT="$SCRIPT_DIR/clean_whitespace.rb"

if [ ! -f "$CLEAN_SCRIPT" ]; then
  echo "Error: clean_whitespace.rb not found at $CLEAN_SCRIPT"
  exit 1
fi

echo "🧹 Cleaning whitespace-only lines in all .swift files..."

file_count=0

while IFS= read -r -d '' file; do
  "$CLEAN_SCRIPT" "$file"
  ((file_count++))
done < <(find "$PROJECT_ROOT" -name "*.swift" -type f -print0)

echo "✅ Cleaned $file_count Swift file(s)."
