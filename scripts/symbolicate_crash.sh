#!/bin/bash

# symbolicate_crash.sh - Symbolicate macOS crash logs
# Usage: ./symbolicate_crash.sh <crash_log_file> [archive_path]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_debug() {
    if [ -n "$DEBUG" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Check if crash log file is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <crash_log_file> [archive_path]"
    echo ""
    echo "Arguments:"
    echo "  crash_log_file  - Path to the crash log file to symbolicate"
    echo "  archive_path    - (Optional) Path to specific .xcarchive directory"
    echo "                    If not provided, will search for matching archive by UUID"
    echo ""
    echo "Example:"
    echo "  $0 MacCrash.log"
    echo "  $0 MacCrash.log ~/Library/Developer/Xcode/Archives/2024-11-28/MyApp.xcarchive"
    echo ""
    echo "Environment variables:"
    echo "  DEBUG=1         - Enable debug output"
    exit 1
fi

CRASH_LOG="$1"
SPECIFIC_ARCHIVE="$2"

# Verify crash log exists
if [ ! -f "$CRASH_LOG" ]; then
    print_error "Crash log file not found: $CRASH_LOG"
    exit 1
fi

# Skip if already symbolicated
if [[ "$CRASH_LOG" == *"symbolicated"* ]]; then
    print_warning "File appears to already be symbolicated (contains 'symbolicated' in name): $CRASH_LOG"
    print_info "Skipping to avoid re-symbolicating"
    exit 0
fi

print_info "Crash log: $CRASH_LOG"

# Extract app info from crash log
APP_NAME=$(grep "^Process:" "$CRASH_LOG" | awk '{print $2}' | head -n 1)
APP_IDENTIFIER=$(grep "^Identifier:" "$CRASH_LOG" | awk '{print $2}' | head -n 1)
APP_VERSION=$(grep "^Version:" "$CRASH_LOG" | awk '{print $2, $3}' | head -n 1)
CODE_TYPE=$(grep "^Code Type:" "$CRASH_LOG" | awk '{print $3}' | head -n 1)

print_info "App: $APP_NAME ($APP_IDENTIFIER)"
print_info "Version: $APP_VERSION"
print_info "Architecture: $CODE_TYPE"

# Determine architecture for atos
if [ "$CODE_TYPE" == "ARM-64" ]; then
    ARCH="arm64"
elif [ "$CODE_TYPE" == "X86-64" ]; then
    ARCH="x86_64"
else
    print_warning "Unknown architecture: $CODE_TYPE, defaulting to arm64"
    ARCH="arm64"
fi

# Extract binary images and UUIDs from crash log
print_info "Extracting UUIDs from crash log..."

# Detect platform (Mac vs iOS)
APP_PATH=$(grep "^Path:" "$CRASH_LOG" | awk '{print $2}' | head -n 1)
if [[ "$APP_PATH" == *"/Contents/MacOS/"* ]]; then
    PLATFORM="macOS"
    print_info "Detected platform: macOS"
else
    PLATFORM="iOS"
    print_info "Detected platform: iOS"
fi

temp_uuids=$(mktemp)

# Extract lines from "Binary Images:" section
sed -n '/^Binary Images:/,$p' "$CRASH_LOG" | grep "0x" | while read line; do
    # Extract binary name and UUID
    # Two formats supported:
    #   Old: 0xaddress - 0xaddress +BinaryName arch <uuid> /path
    #   New: 0xaddress - 0xaddress com.bundle.id (version) <uuid> /path
    if [[ "$line" =~ \<([a-f0-9-]+)\> ]]; then
        uuid="${BASH_REMATCH[1]}"

        # Try to extract binary name from path (last component)
        if [[ "$line" =~ /([^/]+)$ ]]; then
            binary="${BASH_REMATCH[1]}"
        else
            # Fallback: try field 4 (old format with + prefix)
            binary=$(echo "$line" | awk '{
                bin = $4
                gsub(/^\+/, "", bin)
                print bin
            }')
        fi

        # Clean up UUID (remove hyphens)
        uuid=$(echo "$uuid" | tr -d '-')
        echo "$binary:$uuid" >> "$temp_uuids"
    fi
done

# Read UUIDs into a temp file
mv "$temp_uuids" /tmp/crash_uuids.txt

print_info "Found $(wc -l < /tmp/crash_uuids.txt | tr -d ' ') binary images with UUIDs"

# Find the correct archive
ARCHIVE_PATH=""

if [ -n "$SPECIFIC_ARCHIVE" ]; then
    # User specified an archive
    if [ ! -d "$SPECIFIC_ARCHIVE" ]; then
        print_error "Specified archive not found: $SPECIFIC_ARCHIVE"
        exit 1
    fi
    ARCHIVE_PATH="$SPECIFIC_ARCHIVE"
    print_info "Using specified archive: $(basename "$ARCHIVE_PATH")"
else
    # Search for matching archive by UUID
    print_info "Searching for matching archive in ~/Library/Developer/Xcode/Archives"

    ARCHIVE_BASE="$HOME/Library/Developer/Xcode/Archives"

    if [ ! -d "$ARCHIVE_BASE" ]; then
        print_error "Archive directory not found: $ARCHIVE_BASE"
        exit 1
    fi

    # Get the main app UUID to search for
    # First try from the extracted UUIDs, then try direct extraction from Binary Images
    APP_UUID=$(grep "^$APP_NAME:" /tmp/crash_uuids.txt | cut -d: -f2 | head -n 1)
    if [ -z "$APP_UUID" ]; then
        APP_UUID=$(sed -n '/^Binary Images:/,$p' "$CRASH_LOG" | grep "0x" | grep -E "(\+$APP_NAME |$APP_NAME\.app)" | head -n 1 | grep -o '<[a-f0-9-]*>' | tr -d '<>-' | tr '[:upper:]' '[:lower:]' || echo "")
    fi

    if [ -z "$APP_UUID" ]; then
        print_warning "Could not find UUID for $APP_NAME in crash log"
        print_info "Falling back to name-based archive search..."

        # Fall back to name-based search
        while IFS= read -r archive; do
            info_plist="$archive/Info.plist"
            if [ -f "$info_plist" ]; then
                archive_name=$(/usr/libexec/PlistBuddy -c "Print :Name" "$info_plist" 2>/dev/null || echo "")
                archive_bundle_id=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleIdentifier" "$info_plist" 2>/dev/null || echo "")

                # Check if name/bundle ID matches
                name_matches=false
                if [[ "$archive_name" == *"$APP_NAME"* ]] || [[ "$archive_bundle_id" == "$APP_IDENTIFIER" ]]; then
                    name_matches=true
                fi

                # Check platform match
                platform_matches=false
                if [[ "$PLATFORM" == "macOS" ]] && [[ "$archive_name" != *"-iOS"* ]] && [[ "$archive_name" != *"iOS"* ]]; then
                    platform_matches=true
                elif [[ "$PLATFORM" == "iOS" ]] && [[ "$archive_name" == *"iOS"* ]]; then
                    platform_matches=true
                fi

                if [[ "$name_matches" == "true" ]] && [[ "$platform_matches" == "true" ]]; then
                    ARCHIVE_PATH="$archive"
                    print_warning "Using most recent archive (UUID matching failed): $(basename "$archive")"
                    break
                fi
            fi
        done < <(find "$ARCHIVE_BASE" -name "*.xcarchive" -type d 2>/dev/null | sort -r)
    else
        print_info "Searching for archive with matching UUID: $APP_UUID"

        # Search for archive with matching UUID
        while IFS= read -r archive; do
            # Find the app bundle in the archive
            app_dsym=$(find "$archive/dSYMs" -name "$APP_NAME.app.dSYM" -type d 2>/dev/null | head -n 1)

            if [ -n "$app_dsym" ]; then
                dwarf_file=$(find "$app_dsym" -type f -path "*/DWARF/$APP_NAME" 2>/dev/null | head -n 1)

                if [ -f "$dwarf_file" ]; then
                    archive_uuid=$(dwarfdump --uuid "$dwarf_file" 2>/dev/null | grep "$ARCH" | awk '{print $2}' | tr -d '-' | tr '[:upper:]' '[:lower:]')

                    print_debug "Checking archive: $(basename "$archive") - UUID: $archive_uuid"

                    if [ "$archive_uuid" == "$APP_UUID" ]; then
                        ARCHIVE_PATH="$archive"
                        print_info "Found matching archive by UUID: $(basename "$archive")"
                        break
                    fi
                fi
            fi
        done < <(find "$ARCHIVE_BASE" -name "*.xcarchive" -type d 2>/dev/null | sort -r)
    fi

    if [ -z "$ARCHIVE_PATH" ]; then
        print_error "No matching archive found for $APP_NAME"
        print_info "Please specify an archive path manually"
        exit 1
    fi
fi

# Find dSYMs directory
DSYMS_DIR="$ARCHIVE_PATH/dSYMs"
if [ ! -d "$DSYMS_DIR" ]; then
    print_error "dSYMs directory not found in archive: $DSYMS_DIR"
    exit 1
fi

print_info "dSYMs directory: $(basename "$ARCHIVE_PATH")/dSYMs"

# List all available dSYMs
print_info "Available dSYMs:"
find "$DSYMS_DIR" -name "*.dSYM" -type d 2>/dev/null | while IFS= read -r dsym; do
    basename "$dsym" .dSYM
done

# Create output file
OUTPUT_FILE="${CRASH_LOG%.log}_symbolicated.log"
cp "$CRASH_LOG" "$OUTPUT_FILE"

print_info "Symbolicating crash log..."

# Cache for dSYM lookups to avoid repeated searches
DSYM_CACHE=$(mktemp)

# Function to find dSYM path for a binary
find_dsym_for_binary() {
    local binary_name="$1"
    local dsyms_dir="$2"

    # Check cache first
    cached=$(grep "^$binary_name:" "$DSYM_CACHE" 2>/dev/null | cut -d: -f2-)
    if [ -n "$cached" ]; then
        echo "$cached"
        return 0
    fi

    # Look for matching dSYM - try different patterns
    local dsym_path=""

    # Try exact match first (e.g., MyApp)
    dsym_path=$(find "$dsyms_dir" -name "${binary_name}.dSYM" -type d 2>/dev/null | head -n 1)

    # Try framework pattern (e.g., MyFramework.framework)
    if [ -z "$dsym_path" ]; then
        dsym_path=$(find "$dsyms_dir" -name "${binary_name}.framework.dSYM" -type d 2>/dev/null | head -n 1)
    fi

    # Try app pattern (e.g., MyApp.app)
    if [ -z "$dsym_path" ]; then
        dsym_path=$(find "$dsyms_dir" -name "${binary_name}.app.dSYM" -type d 2>/dev/null | head -n 1)
    fi

    if [ -n "$dsym_path" ]; then
        # Find the actual binary inside the dSYM
        local binary_base=$(basename "$binary_name" .framework)
        binary_base=$(basename "$binary_base" .app)

        local binary_path=$(find "$dsym_path" -type f -path "*/DWARF/$binary_base" 2>/dev/null | head -n 1)

        if [ -n "$binary_path" ]; then
            # Cache the result
            echo "$binary_name:$binary_path" >> "$DSYM_CACHE"
            echo "$binary_path"
            return 0
        fi
    fi

    return 1
}

# Process each line of the crash log
print_info "Processing stack traces..."

# Symbolicate using atos for each frame
temp_file=$(mktemp)
symbolicated_count=0

while IFS= read -r line; do
    # Check if this is a stack frame line
    # Format: <frame_num> <binary_name> <address> <load_address> + <offset>
    if [[ "$line" =~ ^[[:space:]]*([0-9]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(0x[0-9a-f]+)[[:space:]]+(0x[0-9a-f]+)[[:space:]]+\+[[:space:]]+([0-9]+) ]]; then
        frame_num="${BASH_REMATCH[1]}"
        binary_name="${BASH_REMATCH[2]}"
        address="${BASH_REMATCH[3]}"
        load_address="${BASH_REMATCH[4]}"
        offset="${BASH_REMATCH[5]}"

        # Find dSYM for this binary
        dsym_binary=$(find_dsym_for_binary "$binary_name" "$DSYMS_DIR")

        if [ -n "$dsym_binary" ]; then
            # Symbolicate the address
            symbol=$(atos -arch "$ARCH" -o "$dsym_binary" -l "$load_address" "$address" 2>/dev/null)

            # If we got a valid symbol (not just the address back), use it
            if [ -n "$symbol" ] && [[ ! "$symbol" =~ ^0x[0-9a-f]+ ]] && [[ "$symbol" != "$address "* ]]; then
                # Format the symbolicated line to match Apple's format
                echo "$line ($symbol)" >> "$temp_file"
                symbolicated_count=$((symbolicated_count + 1))
                continue
            fi
        fi
    fi

    # If not symbolicated or not a stack frame, keep original line
    echo "$line" >> "$temp_file"
done < "$CRASH_LOG"

mv "$temp_file" "$OUTPUT_FILE"
rm -f "$DSYM_CACHE" /tmp/crash_uuids.txt

print_info "Symbolication complete!"
print_info "Symbolicated $symbolicated_count addresses"
print_info "Output file: $OUTPUT_FILE"

# Show a preview of the symbolicated crash
print_info ""
print_info "Preview of symbolicated crash (Thread 0):"
echo ""
sed -n '/^Thread 0 Crashed:/,/^Thread [0-9]/p' "$OUTPUT_FILE" | head -n 15

echo ""
print_info "Full symbolicated crash log saved to: $OUTPUT_FILE"
