# Crash Log Symbolication Scripts

This directory contains scripts for symbolicating macOS crash logs. Different scripts are needed for different crash log formats.

## Quick Start

```bash
# Traditional text format crash logs
./symbolicate_crash_simple.sh MacCrash.log

# JSON format crash logs (macOS 15+)
./symbolicate_json_crash.sh crash.log

# Batch process all crashes in a directory
./symbolicate_all_crashes.sh /path/to/crash/logs
```

## Script Overview

### Traditional Text Format Crash Logs

For standard macOS crash logs (plain text format with "Process:", "Binary Images:", etc.):

- **`symbolicate_crash.sh`** - Full-featured symbolication script
  - Automatically finds matching .xcarchive by UUID
  - Symbolicates all frames using `atos`
  - Supports both macOS and iOS crash logs
  - Detailed logging with `DEBUG=1` option

- **`symbolicate_crash_simple.sh`** - Uses Apple's `symbolicatecrash` tool (recommended)
  - Simpler approach using Apple's built-in tool
  - Requires Xcode to be installed

- **`symbolicate_all_crashes.sh`** - Batch process multiple crash logs
  - Automatically processes all .crash files in a directory
  - Uses `symbolicate_crash.sh` internally

### JSON Format Crash Logs (macOS 15+)

For newer JSON-format crash logs (as seen in macOS 15 and later):

- **`symbolicate_json_crash.sh`** - Handles JSON crash log format
  - Parses JSON crash data structure
  - Extracts and symbolicates thread backtraces
  - Reformats output into readable text format
  - Numbers frames starting from 0 (like traditional format)
  - **Requires `jq`** (install with: `brew install jq`)

## Identifying Crash Log Format

### Traditional Text Format
```
Process:             NetNewsWire [12345]
Path:                /Applications/NetNewsWire.app/Contents/MacOS/NetNewsWire
Identifier:          com.ranchero.NetNewsWire-Evergreen
Version:             6.2 (6200)
Code Type:           ARM-64

Binary Images:
0x100000000 - 0x100ffffff +NetNewsWire arm64 <uuid> /path/to/app
```

### Translated Report Format (macOS 15+)
```
Process:               NetNewsWire [12345]
Thread 0 Crashed::  Dispatch queue: com.apple.main-thread
0   libsystem_kernel.dylib        	       0x1821a2388 __pthread_kill + 8
3   NetNewsWire                   	       0x103017460 0x102ef0000 + 1209440
```
**Advantage**: System frameworks are already symbolicated, only your app code needs symbolication

### JSON Format (macOS 15+)
```json
{"app_name":"NetNewsWire","timestamp":"2025-11-17 06:48:17.00 -0800",...}
{
  "uptime" : 2300000,
  "procRole" : "Foreground",
  "threads" : [...],
  "usedImages" : [...]
}
```

**Key difference**: JSON format has two JSON objects - a header on line 1, and the main crash data starting on line 2.

## Usage Examples

### Symbolicate a Traditional Crash Log
```bash
# Auto-find archive by UUID
./symbolicate_crash_simple.sh MacCrash.log

# Or use advanced script with debug output
DEBUG=1 ./symbolicate_crash.sh MacCrash.log

# Specify archive path manually
./symbolicate_crash.sh MacCrash.log ~/Library/Developer/Xcode/Archives/2024-11-28/MyApp.xcarchive
```

### Symbolicate a JSON Crash Log
```bash
# Auto-find archive by UUID
./symbolicate_json_crash.sh crash.log

# Specify archive path manually
./symbolicate_json_crash.sh crash.log ~/Library/Developer/Xcode/Archives/2024-11-28/MyApp.xcarchive
```

### Symbolicate All Crashes in a Directory
```bash
# Process all .crash files in current directory
./symbolicate_all_crashes.sh

# Process crashes in specific directory
./symbolicate_all_crashes.sh /path/to/crash/directory
```

### Advanced Usage
```bash
# Specify custom dSYM directory
./symbolicate_crash_simple.sh MacCrash.log ~/path/to/dSYMs

# Enable debug output
DEBUG=1 ./symbolicate_crash.sh MacCrash.log

# Process specific pattern
find . -name "*production*.log" -exec ./symbolicate_crash_simple.sh {} \;
```

## What Gets Symbolicated

The scripts symbolicate your app's code:
- Your main app binary
- Your frameworks and libraries
- App extensions
- Embedded frameworks

**Example:**
```
Before: 0   NetNewsWire  0x00000001059feea0 0x1058d0000 + 1240736
After:  0   NetNewsWire  0x00000001059feea0 closure #1 in ReaderAPICaller.retrieveEntries(articleIDs:completion:) (ReaderAPICaller.swift:527)
```

## Understanding the Output

### Symbolicated Frame:
```
0   Account  0x1059feea0  closure #1 in ReaderAPICaller.retrieveEntries(articleIDs:completion:) (ReaderAPICaller.swift:527)
```
- **Frame Number**: `0` (top of stack)
- **Function**: `closure #1 in ReaderAPICaller.retrieveEntries`
- **File**: `ReaderAPICaller.swift`
- **Line**: `527`

## Output Files

All scripts create a `*_symbolicated.log` file with:
- App and system information
- Exception details
- Symbolicated stack traces for all threads (with frame numbers)
- Binary image information

The output maintains Apple's standard crash log format and can be:
- Opened in Console.app
- Shared with Apple via Feedback Assistant
- Analyzed with other crash analysis tools
- Searched for specific functions/files

## Requirements

### All Scripts
- macOS with Xcode installed
- Xcode command line tools
- Matching .xcarchive with dSYMs in `~/Library/Developer/Xcode/Archives`
- The crash log must match the architecture and UUID of a built archive

### JSON Crash Log Script Only
- **`jq`** command-line JSON processor
  - Install with: `brew install jq`
  - Used to parse JSON crash log structure

## Troubleshooting

### "No matching archive found"
- Ensure you have an Xcode archive for this build
- Check that archive contains dSYM files
- Verify archive matches crash log's architecture (arm64/x86_64)
- Try specifying the archive path manually

### "Could not find dSYMs"
- Archive may not have been created with debug symbols
- Check Build Settings → Debug Information Format = "DWARF with dSYM File"

### "jq is required" (JSON script only)
```bash
brew install jq
```

### Partial or Missing Symbols
- Verify the dSYM files exist in the archive's `dSYMs` directory
- Check that the architecture matches (arm64 vs x86_64)
- Ensure the crash log matches the exact build that was archived

### Wrong archive selected
- Script matches by UUID (most accurate)
- Falls back to name matching if UUID fails
- Specify archive manually to override

### Script Hangs or is Very Slow
- The JSON script may take a while for crashes with many threads
- Consider using the traditional format scripts if possible

## Technical Details

### How It Works

1. **Extract App Info** - Reads process name, architecture, platform from crash log
2. **Extract UUIDs** - Gets unique identifiers for each binary
3. **Find Archive** - Searches Xcode archives for matching UUID
4. **Symbolicate** - Uses `atos` or Apple's `symbolicatecrash` tool
5. **Add Symbols** - Replaces addresses with function names, file names, and line numbers

### Files Created

- `*_symbolicated.log` - Output file with symbols
- Original crash log is never modified

## Best Practices

1. **Always archive with dSYMs** - Enable "Debug Information Format" in build settings
2. **Keep all archives** - You need the exact build's archive to symbolicate
3. **Save archives by version** - Organize by version number and build number
4. **Test symbolication** - Verify after each release that you can symbolicate
5. **Archive before distribution** - Create archive before exporting for distribution

## Limitations

- Cannot symbolicate crashes from App Store builds without matching archive
- Requires Xcode installation
- macOS only (for macOS crash logs)
- JSON crash logs require `jq` to be installed
- Traditional scripts will not work on JSON format logs and vice versa

## Notes

- The JSON crash log format appeared in macOS 15 (Sequoia) and is structurally different from traditional crash logs
- "Translated Report" format crash logs (macOS 15+) include pre-symbolicated system frameworks, which is valuable for debugging
- Archives must be built with debug symbols (dSYMs) enabled
- The scripts search for archives from newest to oldest by default
- Frame numbers start from 0 (top of stack) to match Apple's format
- Scripts automatically skip files with "symbolicated" in the filename to avoid re-symbolicating

## Additional Resources

- [Apple Technical Note TN2151 - Understanding Crash Reports](https://developer.apple.com/documentation/xcode/diagnosing-issues-using-crash-reports-and-device-logs)
- [WWDC Videos on Crash Analysis](https://developer.apple.com/videos/)
- Xcode Help → "Analyzing Crash Reports"
