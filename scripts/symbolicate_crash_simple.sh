#!/bin/bash

# symbolicate_crash_simple.sh - Symbolicate macOS crash logs using Apple's symbolicatecrash
# Usage: ./symbolicate_crash_simple.sh <crash_log_file> [dsym_path]

set -e

# Colors for output
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

if [ $# -lt 1 ]; then
    echo "Usage: $0 <crash_log_file> [dsym_directory]"
    echo ""
    echo "Arguments:"
    echo "  crash_log_file   - Path to the crash log file"
    echo "  dsym_directory   - (Optional) Path to directory containing dSYMs"
    echo "                     Defaults to searching Xcode archives"
    echo ""
    echo "Example:"
    echo "  $0 MacCrash.log"
    echo "  $0 MacCrash.log ~/Library/Developer/Xcode/Archives/.../dSYMs"
    exit 1
fi

CRASH_LOG="$1"
DSYM_DIR="$2"

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

# Find symbolicatecrash
SYMBOLICATE_CRASH=$(find /Applications/Xcode.app -name "symbolicatecrash" 2>/dev/null | head -n 1)

if [ -z "$SYMBOLICATE_CRASH" ]; then
    print_error "symbolicatecrash not found. Please install Xcode."
    exit 1
fi

print_info "Using symbolicatecrash: $SYMBOLICATE_CRASH"

# Set up environment for symbolicatecrash
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

# If no dSYM directory specified, try to find it
if [ -z "$DSYM_DIR" ]; then
    print_info "Searching for matching dSYMs..."

    # Extract app info
    APP_NAME=$(grep "^Process:" "$CRASH_LOG" | awk '{print $2}' | head -n 1)
    APP_PATH=$(grep "^Path:" "$CRASH_LOG" | awk '{print $2}' | head -n 1)

    print_info "App: $APP_NAME"

    # Detect platform
    if [[ "$APP_PATH" == *"/Contents/MacOS/"* ]]; then
        PLATFORM="macOS"
        print_info "Platform: macOS"
    else
        PLATFORM="iOS"
        print_info "Platform: iOS"
    fi

    # Extract UUID - try both formats (+AppName and AppName.app)
    APP_UUID=$(sed -n '/^Binary Images:/,$p' "$CRASH_LOG" | grep "0x" | grep -E "(\+$APP_NAME |$APP_NAME\.app)" | head -n 1 | grep -o '<[a-f0-9-]*>' | tr -d '<>' || echo "")

    if [ -n "$APP_UUID" ]; then
        print_info "App UUID: $APP_UUID"

        # Search for matching archive
        ARCHIVE_BASE="$HOME/Library/Developer/Xcode/Archives"
        FOUND_ARCHIVE=""

        while IFS= read -r archive; do
            # Check platform
            archive_name=$(basename "$archive")

            if [[ "$PLATFORM" == "macOS" ]] && [[ "$archive_name" == *"iOS"* ]]; then
                continue
            fi
            if [[ "$PLATFORM" == "iOS" ]] && [[ "$archive_name" != *"iOS"* ]]; then
                continue
            fi

            # Find app dSYM
            app_dsym=$(find "$archive/dSYMs" -name "$APP_NAME.app.dSYM" -type d 2>/dev/null | head -n 1)
            if [ -n "$app_dsym" ]; then
                dwarf_file=$(find "$app_dsym" -type f -path "*/DWARF/$APP_NAME" 2>/dev/null | head -n 1)
                if [ -f "$dwarf_file" ]; then
                    archive_uuid=$(dwarfdump --uuid "$dwarf_file" 2>/dev/null | grep -i "arm64\|x86_64" | head -n 1 | awk '{print $2}' | tr -d '-' | tr '[:upper:]' '[:lower:]')

                    if [ "$archive_uuid" == "$APP_UUID" ]; then
                        FOUND_ARCHIVE="$archive"
                        print_info "Found matching archive: $(basename "$archive")"
                        break
                    fi
                fi
            fi
        done < <(find "$ARCHIVE_BASE" -name "*.xcarchive" -type d 2>/dev/null | sort -r)

        if [ -n "$FOUND_ARCHIVE" ]; then
            DSYM_DIR="$FOUND_ARCHIVE/dSYMs"
        fi
    fi

    # Fallback: use most recent matching archive
    if [ -z "$DSYM_DIR" ]; then
        print_warning "Could not find archive by UUID, trying by name..."

        while IFS= read -r archive; do
            archive_name=$(basename "$archive")

            if [[ "$PLATFORM" == "macOS" ]] && [[ "$archive_name" == *"iOS"* ]]; then
                continue
            fi
            if [[ "$PLATFORM" == "iOS" ]] && [[ "$archive_name" != *"iOS"* ]]; then
                continue
            fi

            if [[ "$archive_name" == *"$APP_NAME"* ]]; then
                DSYM_DIR="$archive/dSYMs"
                print_warning "Using most recent archive: $(basename "$archive")"
                break
            fi
        done < <(find "$ARCHIVE_BASE" -name "*.xcarchive" -type d 2>/dev/null | sort -r)
    fi

    if [ -z "$DSYM_DIR" ]; then
        print_error "Could not find dSYMs. Please specify dSYM directory manually."
        exit 1
    fi
fi

if [ ! -d "$DSYM_DIR" ]; then
    print_error "dSYM directory not found: $DSYM_DIR"
    exit 1
fi

print_info "dSYM directory: $DSYM_DIR"
print_info "Available dSYMs:"
find "$DSYM_DIR" -name "*.dSYM" -type d 2>/dev/null | while IFS= read -r dsym; do
    basename "$dsym" .dSYM
done

# Create output file
OUTPUT_FILE="${CRASH_LOG%.log}_symbolicated.log"

print_info "Symbolicating crash log..."
print_info "This may take a minute..."

# Run symbolicatecrash with system framework paths for better system symbol resolution
# Note: System symbols may not be available for all macOS versions
if DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer "$SYMBOLICATE_CRASH" -d "$DSYM_DIR" "$CRASH_LOG" /System/Library/Frameworks /System/Library/PrivateFrameworks /usr/lib > "$OUTPUT_FILE" 2>/dev/null; then
    print_info "Symbolication complete!"
    print_info "Output: $OUTPUT_FILE"

    print_info ""
    print_info "Preview (Thread 0):"
    echo ""
    sed -n '/^Thread 0 Crashed:/,/^Thread [0-9]/p' "$OUTPUT_FILE" | head -n 15
else
    print_warning "symbolicatecrash completed with warnings"
    print_info "Output may be partial: $OUTPUT_FILE"
fi

echo ""
print_info "Full symbolicated log: $OUTPUT_FILE"
