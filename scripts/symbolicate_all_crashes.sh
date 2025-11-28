#!/bin/bash

# symbolicate_all_crashes.sh - Batch symbolicate all crash logs in a directory
# Usage: ./symbolicate_all_crashes.sh [directory]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_section() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}\n"
}

# Get directory to process
CRASH_DIR="${1:-.}"

if [ ! -d "$CRASH_DIR" ]; then
    print_error "Directory not found: $CRASH_DIR"
    exit 1
fi

# Find symbolicatecrash tool
SYMBOLICATE_CRASH=$(find /Applications/Xcode.app -name "symbolicatecrash" 2>/dev/null | head -n 1)

if [ -z "$SYMBOLICATE_CRASH" ]; then
    print_error "symbolicatecrash not found. Please install Xcode."
    exit 1
fi

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

print_section "Crash Log Batch Symbolication"
print_info "Directory: $CRASH_DIR"
print_info "Pattern: *crash*.log (case-insensitive)"

# Find all crash log files (case-insensitive)
CRASH_LOGS=()
while IFS= read -r -d '' file; do
    CRASH_LOGS+=("$file")
done < <(find "$CRASH_DIR" -maxdepth 1 -type f -iname "*crash*.log" -print0 2>/dev/null)

if [ ${#CRASH_LOGS[@]} -eq 0 ]; then
    print_warning "No crash logs found matching pattern '*crash*.log'"
    exit 0
fi

print_info "Found ${#CRASH_LOGS[@]} crash log(s) to process"
echo ""

# Statistics
TOTAL=${#CRASH_LOGS[@]}
SUCCESSFUL=0
FAILED=0
SKIPPED=0

# Function to symbolicate a single crash log
symbolicate_single() {
    local crash_log="$1"
    local index="$2"
    local total="$3"

    local basename=$(basename "$crash_log")
    local output_file="${crash_log%.log}_symbolicated.log"

    print_section "[$index/$total] Processing: $basename"

    # Check if already symbolicated
    if [ -f "$output_file" ]; then
        read -p "$(echo -e ${YELLOW}Output file exists. Overwrite? [y/N]:${NC} )" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Skipped: $basename"
            return 2
        fi
    fi

    # Extract app info
    APP_NAME=$(grep "^Process:" "$crash_log" | awk '{print $2}' | head -n 1)
    APP_PATH=$(grep "^Path:" "$crash_log" | awk '{print $2}' | head -n 1)

    if [ -z "$APP_NAME" ]; then
        print_error "Could not extract app name from crash log"
        return 1
    fi

    print_info "App: $APP_NAME"

    # Detect platform
    if [[ "$APP_PATH" == *"/Contents/MacOS/"* ]]; then
        PLATFORM="macOS"
    else
        PLATFORM="iOS"
    fi
    print_info "Platform: $PLATFORM"

    # Extract UUID
    APP_UUID=$(sed -n '/^Binary Images:/,$p' "$crash_log" | grep "0x" | grep "+$APP_NAME " | head -n 1 | grep -o '<[a-f0-9]*>' | tr -d '<>' || echo "")

    # Find matching archive
    DSYM_DIR=""
    ARCHIVE_BASE="$HOME/Library/Developer/Xcode/Archives"

    if [ -n "$APP_UUID" ]; then
        print_info "App UUID: $APP_UUID"
        print_info "Searching for matching archive..."

        # Search for archive by UUID
        while IFS= read -r archive; do
            archive_name=$(basename "$archive")

            # Filter by platform
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
                        DSYM_DIR="$archive/dSYMs"
                        print_info "Found by UUID: $(basename "$archive")"
                        break
                    fi
                fi
            fi
        done < <(find "$ARCHIVE_BASE" -name "*.xcarchive" -type d 2>/dev/null | sort -r)
    fi

    # Fallback: find by name
    if [ -z "$DSYM_DIR" ]; then
        print_warning "UUID match failed, searching by name..."

        while IFS= read -r archive; do
            archive_name=$(basename "$archive")

            # Filter by platform
            if [[ "$PLATFORM" == "macOS" ]] && [[ "$archive_name" == *"iOS"* ]]; then
                continue
            fi
            if [[ "$PLATFORM" == "iOS" ]] && [[ "$archive_name" != *"iOS"* ]]; then
                continue
            fi

            if [[ "$archive_name" == *"$APP_NAME"* ]]; then
                DSYM_DIR="$archive/dSYMs"
                print_warning "Using by name: $(basename "$archive")"
                break
            fi
        done < <(find "$ARCHIVE_BASE" -name "*.xcarchive" -type d 2>/dev/null | sort -r)
    fi

    if [ -z "$DSYM_DIR" ] || [ ! -d "$DSYM_DIR" ]; then
        print_error "Could not find dSYMs for $APP_NAME"
        return 1
    fi

    # Symbolicate with system framework paths
    print_info "Symbolicating..."
    if DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer "$SYMBOLICATE_CRASH" -d "$DSYM_DIR" "$crash_log" /System/Library/Frameworks /System/Library/PrivateFrameworks /usr/lib > "$output_file" 2>/dev/null; then
        print_info "✓ Success: $output_file"

        # Show preview
        if grep -q "Thread 0 Crashed:" "$output_file" 2>/dev/null; then
            echo ""
            echo -e "${BLUE}Preview (first 5 frames):${NC}"
            sed -n '/^Thread 0 Crashed:/,/^Thread [0-9]/p' "$output_file" | head -n 7 | tail -n +2
        fi

        return 0
    else
        print_warning "symbolicatecrash completed with warnings"
        if [ -f "$output_file" ]; then
            print_info "Partial output saved: $output_file"
            return 0
        else
            return 1
        fi
    fi
}

# Process each crash log
for i in "${!CRASH_LOGS[@]}"; do
    crash_log="${CRASH_LOGS[$i]}"
    index=$((i + 1))

    if symbolicate_single "$crash_log" "$index" "$TOTAL"; then
        SUCCESSFUL=$((SUCCESSFUL + 1))
    else
        exit_code=$?
        if [ $exit_code -eq 2 ]; then
            SKIPPED=$((SKIPPED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    fi

    echo ""
done

# Print summary
print_section "Summary"
echo -e "${GREEN}Successful:${NC} $SUCCESSFUL"
echo -e "${YELLOW}Skipped:${NC}    $SKIPPED"
echo -e "${RED}Failed:${NC}     $FAILED"
echo -e "Total:      $TOTAL"
echo ""

if [ $SUCCESSFUL -gt 0 ]; then
    print_info "Symbolicated files are saved with '_symbolicated.log' suffix"
fi

exit 0
