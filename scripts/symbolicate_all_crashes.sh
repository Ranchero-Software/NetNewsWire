#!/bin/bash

# symbolicate_all_crashes.sh - Batch symbolicate all crash logs in a directory
# Usage: ./symbolicate_all_crashes.sh [directory]

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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if symbolication scripts exist
if [ ! -f "$SCRIPT_DIR/symbolicate_crash.sh" ]; then
    print_error "symbolicate_crash.sh not found in $SCRIPT_DIR"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/symbolicate_json_crash.sh" ]; then
    print_error "symbolicate_json_crash.sh not found in $SCRIPT_DIR"
    exit 1
fi

print_section "Crash Log Batch Symbolication"
print_info "Directory: $CRASH_DIR"
print_info "Pattern: *crash*.log (case-insensitive)"

# Find all crash log files (case-insensitive), excluding already symbolicated files
CRASH_LOGS=()
while IFS= read -r -d '' file; do
    # Skip files with "symbolicated" in the name
    if [[ "$file" == *"symbolicated"* ]]; then
        continue
    fi
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

# Function to detect crash log format
detect_format() {
    local crash_log="$1"

    # Check first line for JSON format
    local first_line=$(head -n 1 "$crash_log")
    if echo "$first_line" | grep -q '{"app_name"'; then
        echo "json"
        return
    fi

    # Otherwise assume traditional/translated format
    echo "traditional"
}

# Function to symbolicate a single crash log
symbolicate_single() {
    local crash_log="$1"
    local index="$2"
    local total="$3"

    local basename=$(basename "$crash_log")

    print_section "[$index/$total] Processing: $basename"

    # Detect crash log format
    local format=$(detect_format "$crash_log")

    # Determine output file name - always use .log extension
    local output_file="${crash_log%.log}_symbolicated.log"

    # Check if symbolicated file already exists
    if [ -f "$output_file" ]; then
        print_warning "Symbolicated file already exists: $(basename "$output_file")"
        print_info "Skipping (use rm to delete and re-symbolicate)"
        return 2
    fi

    print_info "Format: $format"

    # Use appropriate script based on format
    if [ "$format" == "json" ]; then
        if "$SCRIPT_DIR/symbolicate_json_crash.sh" "$crash_log" > /dev/null 2>&1; then
            print_info "✓ Success"
            return 0
        else
            print_error "✗ Failed"
            return 1
        fi
    else
        if "$SCRIPT_DIR/symbolicate_crash.sh" "$crash_log" > /dev/null 2>&1; then
            print_info "✓ Success"
            return 0
        else
            print_error "✗ Failed"
            return 1
        fi
    fi
}

# Process each crash log
index=1
for crash_log in "${CRASH_LOGS[@]}"; do
    if symbolicate_single "$crash_log" "$index" "$TOTAL"; then
        ((SUCCESSFUL++))
    else
        exit_code=$?
        if [ $exit_code -eq 2 ]; then
            ((SKIPPED++))
        else
            ((FAILED++))
        fi
    fi
    ((index++))
done

print_section "Summary"
echo -e "${GREEN}Successful:${NC} $SUCCESSFUL"
echo -e "${YELLOW}Skipped:${NC}    $SKIPPED"
echo -e "${RED}Failed:${NC}     $FAILED"
echo "Total:      $TOTAL"
echo ""
print_info "Symbolicated files are saved with '_symbolicated.log' suffix"
