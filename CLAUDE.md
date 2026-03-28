# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

### Setup
- First-time setup: `./setup.sh` (creates `SharedXcodeSettings/DeveloperSettings.xcconfig` in parent directory)
- Requires `xcbeautify`: https://github.com/cpisciotta/xcbeautify

### Building
- **Full build and test**: `./buildscripts/build_and_test.sh`
- **Quiet build and test** (CI-friendly): `./buildscripts/quiet_build_and_test.sh`
- **macOS only**: `xcodebuild -project NetNewsWire.xcodeproj -scheme NetNewsWire -destination "platform=macOS,arch=arm64" build`
- **iOS only**: `xcodebuild -project NetNewsWire.xcodeproj -scheme NetNewsWire-iOS -destination "platform=iOS Simulator,name=iPhone 17" build`

### Testing
- **All macOS tests**: `xcodebuild -project NetNewsWire.xcodeproj -scheme NetNewsWire -destination "platform=macOS,arch=arm64" test`
- **Single test class**: `xcodebuild -project NetNewsWire.xcodeproj -scheme NetNewsWire -destination "platform=macOS,arch=arm64" -only-testing:AccountTests/ArticleFilterTests test`
- **Single test method**: `xcodebuild -project NetNewsWire.xcodeproj -scheme NetNewsWire -destination "platform=macOS,arch=arm64" -only-testing:AccountTests/ArticleFilterTests/testContainsMatchesTitleKeyword test`
- Test plans: `NetNewsWire.xctestplan` (macOS), `NetNewsWire-iOS.xctestplan` (iOS)
- Tests use XCTest framework with `@MainActor` attribute on test classes

## Project Architecture

### Overview
NetNewsWire is a multi-platform RSS reader (macOS/iOS) with a modular architecture. Shared business logic lives in Swift packages under `Modules/`; platform UI is in `Mac/` (AppKit) and `iOS/` (UIKit).

### Module Dependency Hierarchy (bottom-up)
- **Level 0**: RSCore (base utilities)
- **Level 1**: RSDatabase (SQLite/FMDB), RSParser (feed parsing), RSWeb (networking)
- **Level 2**: Articles (data models), FeedFinder (feed discovery)
- **Level 3**: ArticlesDatabase (article persistence)
- **Level 4**: Secrets, SyncDatabase, ErrorLog
- **Level 5**: Account (orchestrator - depends on 11 modules)

### Key Protocols
- **AccountDelegate** (`Modules/Account/Sources/Account/AccountDelegate.swift`): Defines behavior for account types (Local, Feedly, Feedbin, NewsBlur, CloudKit, etc.)
- **Container** (`Modules/Account/Sources/Account/Container.swift`): Hierarchical feed/folder organization. Adopted by Account and Folder
- **PseudoFeed** (`Shared/SmartFeeds/PseudoFeed.swift`): Virtual feeds (Today, All Unread, Starred)

### Key Patterns
- **Notifications over KVO**: Use `NotificationCenter.default.postOnMainThread()` for state changes. KVO is entirely forbidden
- **Delegates over subclasses**: AccountDelegate pattern for pluggable sync service backends
- **Extensions for conformances**: Protocol implementations go in extensions, private methods in `private extension`

## Coding Guidelines

These come from `Technotes/CodingGuidelines.md` -- read it for full details.

### Priority Values (in order)
1. No data loss
2. No crashes
3. No other bugs
4. Fast performance
5. Developer productivity

### Strict Rules
- **All classes must be `final`** (except required AppKit/UIKit subclasses). Use protocols and delegates instead of inheritance
- **Everything runs on the main thread**. Only exceptions: feed parsing and database fetches run in the background
- **No KVO, no bindings, no NSArrayController**. Use NotificationCenter or `didSet`
- **No Core Data**. Use plain Swift structs/classes with RSDatabase (FMDB/SQLite)
- **No locks** (almost never). Use serial queues for isolation instead
- **No force unwrapping** except as intentional precondition
- **No stack views in table/outline cells** (performance)
- **Tabs for indentation**, not spaces
- **Commit messages start with a present-tense verb**
- **Storyboards preferred** over XIBs (except small UI pieces)

### Code Style
- Prefer `if let x` and `guard let x` over `if let x = x` and `guard let x = x`
- Guard statements: always put `return` on a separate line
- Don't use `...` or `...` in Logger messages
- Prefer immutable structs
- Small objects over large ones
- Use `@MainActor` attribute on classes and protocols that must run on main thread
- Nil-targeted actions and responder chain for UI commands

### Development Build Limitations
Some features are disabled in dev builds due to private API keys (iCloud sync, Feedly, Reader View). API keys managed through `buildscripts/updateSecrets.sh` which runs as a pre-build action.

## Things to Know

- Just because unit tests pass doesn't mean a bug is fixed. Many things require manual testing
- Don't contribute features without discussing in the [Discourse forum](https://discourse.netnewswire.com/) first (see CONTRIBUTING.md)
- Documentation and technical notes are in `Technotes/`
