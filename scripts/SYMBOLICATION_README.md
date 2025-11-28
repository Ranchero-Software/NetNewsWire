# Crash Log Symbolication Scripts

## Overview

Three scripts for symbolicating macOS crash logs:

1. **symbolicate_all_crashes.sh** - Batch process multiple crash logs
2. **symbolicate_crash_simple.sh** - Symbolicate single crash log (recommended)
3. **symbolicate_crash.sh** - Advanced single file with detailed logging

## Quick Start

```bash
# Symbolicate all crash logs in current directory
./symbolicate_all_crashes.sh

# Symbolicate a single crash log
./symbolicate_crash_simple.sh MacCrash.log

# Symbolicate crashes in specific directory
./symbolicate_all_crashes.sh /path/to/crash/logs
```

## What Gets Symbolicated

### ✅ Your App's Code (Always)
- Your main app binary
- Your frameworks and libraries
- App extensions
- Embedded frameworks

**Example:**
```
Before: 0x00000001059feea0 0x1058d0000 + 1240736
After:  closure #1 in ReaderAPICaller.retrieveEntries(articleIDs:completion:) (ReaderAPICaller.swift:527)
```

### ⚠️ System Frameworks (Limited)
- AppKit, CoreFoundation, UIKit, etc.
- **May NOT symbolicate** on newer macOS versions
- Symbols often stripped from release builds
- Requires OS-specific symbols from Apple

**Why System Symbols Are Limited:**

1. **Stripped Binaries** - Release builds of macOS don't include debug symbols
2. **Dyld Shared Cache** - System frameworks are in a shared cache, not individual files
3. **OS Version Matching** - Requires exact OS build symbols
4. **Availability** - Apple doesn't always provide public symbol downloads for all macOS versions

## System Symbol Options

### Option 1: Use Current Scripts (Best Effort)
The scripts attempt to find system symbols by searching:
- `/System/Library/Frameworks`
- `/System/Library/PrivateFrameworks`
- `/usr/lib`

This works for some frameworks but not all.

### Option 2: Download Symbols from Apple (If Available)

For older macOS versions, you may be able to download symbols:

1. **Xcode Downloads** (For older OS versions):
   - Xcode → Settings → Platforms
   - Download symbols for specific OS versions

2. **Manual Symbol Download**:
   - Some macOS versions have public symbol packages
   - Not available for all versions/builds

### Option 3: Run on Matching OS Version

Symbolicate on a Mac running the **same OS version** as the crash:
- Symbols may be available locally
- Best chance for system framework symbolication

### Option 4: Focus on Your Code

Often, system framework symbols aren't needed:
- **Your code symbols** are what you can fix
- System framework stack frames show the call path
- Offsets can still indicate which system API was called

## Understanding the Output

### Fully Symbolicated Frame:
```
0  Account  0x1059feea0  closure #1 in ReaderAPICaller.retrieveEntries(articleIDs:completion:) + 1240736 (ReaderAPICaller.swift:527)
```
- **Function**: `closure #1 in ReaderAPICaller.retrieveEntries`
- **File**: `ReaderAPICaller.swift`
- **Line**: `527`

### Partially Symbolicated Frame (System):
```
12  CoreFoundation  0x18464e980  0x1845c5000 + 563584
```
- Shows framework name and offset
- No function/file info (symbols not available)
- Still useful for understanding call stack

## Technical Details

### How It Works

1. **Extract App Info** - Reads process name, architecture, platform from crash log
2. **Extract UUIDs** - Gets unique identifiers for each binary
3. **Find Archive** - Searches Xcode archives for matching UUID
4. **Symbolicate** - Uses Apple's `symbolicatecrash` tool
5. **Add Symbols** - Replaces addresses with function names

### Requirements

- macOS with Xcode installed
- Xcode archives with dSYM files
- Crash log must be from your own build

### Files Created

- `*_symbolicated.log` - Output file with symbols
- Original crash log is never modified

## Troubleshooting

### "No matching archive found"
- Ensure you have an Xcode archive for this build
- Check that archive contains dSYM files
- Verify archive matches crash log's architecture (arm64/x86_64)

### "Could not find dSYMs"
- Archive may not have been created with debug symbols
- Check Build Settings → Debug Information Format = "DWARF with dSYM File"

### System frameworks not symbolicated
- **This is normal** for many macOS versions
- See "System Symbol Options" above
- Focus on your own code's symbols

### Wrong archive selected
- Script matches by UUID (most accurate)
- Falls back to name matching if UUID fails
- Specify archive manually: `./symbolicate_crash_simple.sh crash.log /path/to/archive/dSYMs`

## Advanced Usage

### Specify Custom dSYM Directory
```bash
./symbolicate_crash_simple.sh MacCrash.log ~/path/to/dSYMs
```

### Enable Debug Output
```bash
DEBUG=1 ./symbolicate_crash.sh MacCrash.log
```

### Process Specific Pattern
```bash
# Only files matching pattern
find . -name "*production_crash*.log" -exec ./symbolicate_crash_simple.sh {} \;
```

## Best Practices

1. **Always archive with dSYMs** - Enable "Debug Information Format" in build settings
2. **Keep all archives** - You need the exact build's archive to symbolicate
3. **Save archives by version** - Organize by version number and build number
4. **Test symbolication** - Verify after each release that you can symbolicate

## Limitations

- Cannot symbolicate crashes from App Store builds without matching archive
- System framework symbolication depends on OS version
- Requires Xcode installation
- macOS only (for macOS crash logs)

## Output Format

Symbolicated logs maintain Apple's standard crash log format and can be:
- Opened in Console.app
- Shared with Apple via Feedback Assistant
- Analyzed with other crash analysis tools
- Searched for specific functions/files

## Additional Resources

- [Apple Technical Note TN2151 - Understanding Crash Reports](https://developer.apple.com/documentation/xcode/diagnosing-issues-using-crash-reports-and-device-logs)
- [WWDC Videos on Crash Analysis](https://developer.apple.com/videos/)
- Xcode Help → "Analyzing Crash Reports"
