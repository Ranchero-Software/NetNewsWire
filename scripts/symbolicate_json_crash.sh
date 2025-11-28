#!/bin/bash

# symbolicate_json_crash.sh - Symbolicate JSON-format macOS crash logs
# Usage: ./symbolicate_json_crash.sh <json_crash_log> [archive_path]
#
# This script handles the newer JSON crash report format (as seen in macOS 15+).
# Unlike traditional text-based crash logs, JSON crash logs have:
#   - A header JSON object on line 1
#   - The main crash data JSON on line 2+
#   - Binary images in a usedImages array
#   - Thread frames as structured objects
#
# Requirements:
#   - jq (install with: brew install jq)
#   - Xcode with matching dSYMs in ~/Library/Developer/Xcode/Archives

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
    print_error "jq is required. Install with: brew install jq"
    exit 1
fi

if [ $# -lt 1 ]; then
    echo "Usage: $0 <json_crash_log> [archive_path]"
    exit 1
fi

CRASH_LOG="$1"
SPECIFIC_ARCHIVE="$2"

if [ ! -f "$CRASH_LOG" ]; then
    print_error "Crash log not found: $CRASH_LOG"
    exit 1
fi

# Skip if already symbolicated
if [[ "$CRASH_LOG" == *"symbolicated"* ]]; then
    print_warning "File appears to already be symbolicated (contains 'symbolicated' in name): $CRASH_LOG"
    print_info "Skipping to avoid re-symbolicating"
    exit 0
fi

print_info "JSON crash log: $CRASH_LOG"

# Extract header
HEADER_JSON=$(head -n 1 "$CRASH_LOG")
APP_NAME=$(echo "$HEADER_JSON" | jq -r '.app_name // empty')
APP_VERSION=$(echo "$HEADER_JSON" | jq -r '.app_version // empty')
BUILD_VERSION=$(echo "$HEADER_JSON" | jq -r '.build_version // empty')
BUNDLE_ID=$(echo "$HEADER_JSON" | jq -r '.bundleID // empty')
SLICE_UUID=$(echo "$HEADER_JSON" | jq -r '.slice_uuid // empty' | tr -d '-')

if [ -z "$APP_NAME" ]; then
    print_error "Could not parse app name"
    exit 1
fi

print_info "App: $APP_NAME ($BUNDLE_ID)"
print_info "Version: $APP_VERSION ($BUILD_VERSION)"
print_info "UUID: $SLICE_UUID"

# Save crash JSON to temp file
CRASH_JSON=$(mktemp)
tail -n +2 "$CRASH_LOG" > "$CRASH_JSON"

CPU_TYPE=$(jq -r '.cpuType // "ARM-64"' < "$CRASH_JSON")
ARCH=$([ "$CPU_TYPE" == "ARM-64" ] && echo "arm64" || echo "x86_64")

print_info "Architecture: $CPU_TYPE ($ARCH)"

# Find archive
ARCHIVE_PATH=""

if [ -n "$SPECIFIC_ARCHIVE" ]; then
    ARCHIVE_PATH="$SPECIFIC_ARCHIVE"
    print_info "Using specified archive: $(basename "$ARCHIVE_PATH")"
else
    ARCHIVE_BASE="$HOME/Library/Developer/Xcode/Archives"

    if [ -n "$SLICE_UUID" ]; then
        print_info "Searching for archive with UUID: $SLICE_UUID"

        while IFS= read -r archive; do
            app_dsym=$(find "$archive/dSYMs" -name "$APP_NAME.app.dSYM" -type d 2>/dev/null | head -n 1)
            if [ -n "$app_dsym" ]; then
                dwarf_file=$(find "$app_dsym" -type f -path "*/DWARF/$APP_NAME" 2>/dev/null | head -n 1)
                if [ -f "$dwarf_file" ]; then
                    archive_uuid=$(dwarfdump --uuid "$dwarf_file" 2>/dev/null | grep "$ARCH" | awk '{print $2}' | tr -d '-' | tr '[:upper:]' '[:lower:]')
                    if [ "$archive_uuid" == "$SLICE_UUID" ]; then
                        ARCHIVE_PATH="$archive"
                        print_info "Found archive: $(basename "$archive")"
                        break
                    fi
                fi
            fi
        done < <(find "$ARCHIVE_BASE" -name "*.xcarchive" -type d 2>/dev/null | sort -r)
    fi

    if [ -z "$ARCHIVE_PATH" ]; then
        print_error "No matching archive found"
        exit 1
    fi
fi

DSYMS_DIR="$ARCHIVE_PATH/dSYMs"
if [ ! -d "$DSYMS_DIR" ]; then
    print_error "dSYMs directory not found: $DSYMS_DIR"
    exit 1
fi

print_info "dSYMs: $(basename "$ARCHIVE_PATH")/dSYMs"

# Build dSYM cache
DSYM_CACHE=$(mktemp)

find "$DSYMS_DIR" -name "*.dSYM" -type d 2>/dev/null | while IFS= read -r dsym; do
    base_name=$(basename "$dsym" .dSYM)
    base_name=$(basename "$base_name" .app)
    base_name=$(basename "$base_name" .appex)
    base_name=$(basename "$base_name" .framework)

    binary_path=$(find "$dsym" -type f -path "*/DWARF/$base_name" 2>/dev/null | head -n 1)
    if [ -n "$binary_path" ]; then
        echo "$base_name|$binary_path" >> "$DSYM_CACHE"
    fi
done

print_info "Found $(wc -l < "$DSYM_CACHE" | tr -d ' ') dSYMs"

# Create output file
OUTPUT_FILE="${CRASH_LOG%.log}_symbolicated.txt"

print_info "Generating symbolicated report..."

{
    echo "========================================"
    echo "Symbolicated Crash Report"
    echo "========================================"
    echo ""
    echo "Process:         $APP_NAME"
    echo "Bundle ID:       $BUNDLE_ID"
    echo "Version:         $APP_VERSION ($BUILD_VERSION)"
    echo "Architecture:    $CPU_TYPE"
    echo "Crash Time:      $(jq -r '.captureTime // "Unknown"' < "$CRASH_JSON")"
    echo "OS Version:      $(jq -r '.osVersion.train // "Unknown"' < "$CRASH_JSON") ($(jq -r '.osVersion.build // "Unknown"' < "$CRASH_JSON"))"
    echo ""
    echo "Exception Information:"
    echo "Type:            $(jq -r '.exception.type // "Unknown"' < "$CRASH_JSON")"
    echo "Signal:          $(jq -r '.exception.signal // "Unknown"' < "$CRASH_JSON")"
    echo "Codes:           $(jq -r '.exception.codes // "Unknown"' < "$CRASH_JSON")"

    asi=$(jq -r '.asi // empty | to_entries[] | "\(.key): \(.value[])"' < "$CRASH_JSON" 2>/dev/null || echo "")
    if [ -n "$asi" ]; then
        echo ""
        echo "Application Specific Information:"
        echo "$asi"
    fi

    echo ""
    echo "========================================"
    echo "Thread Backtraces"
    echo "========================================"
    echo ""

    # Extract all thread data at once and process
    jq -r '.threads[] | @json' < "$CRASH_JSON" | while IFS= read -r thread_json; do
        thread_id=$(echo "$thread_json" | jq -r '.id')
        thread_name=$(echo "$thread_json" | jq -r '.name // empty')
        triggered=$(echo "$thread_json" | jq -r '.triggered // false')
        queue=$(echo "$thread_json" | jq -r '.queue // empty')

        # Get thread index for display
        thread_num=$(jq -r --argjson tid "$thread_id" '.threads | to_entries[] | select(.value.id == $tid) | .key' < "$CRASH_JSON")

        echo "----------------------------------------"
        if [ "$triggered" == "true" ]; then
            echo "Thread $thread_num Crashed (ID: $thread_id)"
        else
            echo "Thread $thread_num (ID: $thread_id)"
        fi

        [ -n "$thread_name" ] && echo "Name: $thread_name"
        [ -n "$queue" ] && echo "Queue: $queue"
        echo "----------------------------------------"

        # Extract all frames for this thread at once
        frame_num=0
        echo "$thread_json" | jq -r '.frames[]? | @json' | while IFS= read -r frame_json; do
            image_index=$(echo "$frame_json" | jq -r '.imageIndex')
            image_offset=$(echo "$frame_json" | jq -r '.imageOffset')
            symbol=$(echo "$frame_json" | jq -r '.symbol // empty')
            symbol_location=$(echo "$frame_json" | jq -r '.symbolLocation // empty')

            # Get image info
            image_info=$(jq -r ".usedImages[$image_index] | {name: (.name // (.path | if type == \"string\" then split(\"/\")[-1] else \"unknown\" end)), base: .base}" < "$CRASH_JSON")
            image_name=$(echo "$image_info" | jq -r '.name')
            base_address=$(echo "$image_info" | jq -r '.base')

            # Calculate address
            actual_address=$((base_address + image_offset))
            actual_address_hex=$(printf "0x%x" "$actual_address")

            # Convert base address to hex (atos requires hex format for -l flag)
            base_address_hex=$(printf "0x%x" "$base_address")

            # Try to symbolicate if it's one of our binaries
            symbolicated=""
            dsym_binary=$(grep "^$image_name|" "$DSYM_CACHE" 2>/dev/null | cut -d'|' -f2)

            if [ -n "$dsym_binary" ]; then
                symbolicated=$(atos -arch "$ARCH" -o "$dsym_binary" -l "$base_address_hex" "$actual_address_hex" 2>/dev/null || echo "")

                # Check if we got a real symbol (not just address back)
                if [ -n "$symbolicated" ] && [[ ! "$symbolicated" =~ ^0x[0-9a-f]+ ]]; then
                    # Valid symbolication
                    :
                else
                    symbolicated=""
                fi
            fi

            # Format output with frame number
            if [ -n "$symbolicated" ]; then
                printf "%-3d %-30s %s %s\n" "$frame_num" "$image_name" "$actual_address_hex" "$symbolicated"
            elif [ -n "$symbol" ]; then
                if [ -n "$symbol_location" ] && [ "$symbol_location" != "null" ]; then
                    printf "%-3d %-30s %s %s + %s\n" "$frame_num" "$image_name" "$actual_address_hex" "$symbol" "$symbol_location"
                else
                    printf "%-3d %-30s %s %s\n" "$frame_num" "$image_name" "$actual_address_hex" "$symbol"
                fi
            else
                printf "%-3d %-30s %s 0x%x\n" "$frame_num" "$image_name" "$actual_address_hex" "$image_offset"
            fi

            frame_num=$((frame_num + 1))
        done

        echo ""
    done

    echo "========================================"
    echo "Binary Images"
    echo "========================================"
    echo ""

    jq -r '.usedImages[] | select(.uuid != "00000000-0000-0000-0000-000000000000") |
        (if .name then .name elif .path then (.path | if type == "string" then split("/")[-1] else "unknown" end) else "unknown" end) as $name |
        (if .path and (.path | type == "string") then .path else "unknown" end) as $path |
        "\(.base | "0x" + (tonumber | tostring)) \($name) <\(.uuid)> \($path)"' < "$CRASH_JSON"

} > "$OUTPUT_FILE"

# Cleanup
rm -f "$DSYM_CACHE" "$CRASH_JSON"

print_info "Symbolication complete!"
print_info "Output: $OUTPUT_FILE"

# Show preview
echo ""
print_info "Preview (Thread 0):"
echo ""
sed -n '/^Thread 0 Crashed/,/^Thread [0-9]/p' "$OUTPUT_FILE" | head -n 25
echo ""
print_info "Full report: $OUTPUT_FILE"
