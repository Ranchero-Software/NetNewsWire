# Architecture

NetNewsWire is a multi-platform RSS reader for macOS and iOS. It is organized as a modular architecture with shared business logic, platform-specific UI layers, and a pluggable account system that supports nine sync service backends.

## Project Layout

```
NetNewsWire/
├── Mac/                    macOS AppKit UI
├── iOS/                    iOS UIKit UI
├── Shared/                 Cross-platform business logic
├── Modules/                Swift Package Manager modules (15 packages)
├── Widget/                 iOS home screen widgets (SwiftUI)
├── Intents/                Siri Shortcuts support
├── AppleScript/            macOS automation support
├── buildscripts/           Build automation
├── xcconfig/               Xcode build configuration
├── Technotes/              Developer documentation
├── Tests/                  App-level test targets
└── NetNewsWire.xcodeproj   Xcode project
```

## Module Dependency Graph

The project uses 15 Swift packages under `Modules/`, organized in a strict unidirectional dependency hierarchy. No circular dependencies exist.

```
                          ┌──────────┐
                          │ Account  │  (orchestration hub)
                          └────┬─────┘
           ┌──────┬──────┬────┼─────┬──────────┬───────────┐
           ▼      ▼      ▼    ▼     ▼          ▼           ▼
      Articles  ArticlesDB  SyncDB  FeedFinder  CloudKitSync  NewsBlur
           │      │    │      │       │    │                     │
           │      ▼    │      ▼       │    ▼                    │
           │  RSDatabase│   RSWeb ◄───┘  RSParser ◄─────────────┘
           │      │     │     │            │
           ▼      ▼     ▼     ▼            ▼
         RSCore  RSCore RSCore RSCore    RSMarkdown
                                           │
                                        Tidemark
```

Additional modules: **RSTree** (tree data structures for outline views), **Secrets** (Keychain credential management).

### Module Responsibilities

| Module | Role |
|--------|------|
| **RSCore** | Foundation extensions, `CoalescingQueue`, `MainThreadOperationQueue`, `OPMLRepresentable`, platform utilities |
| **RSParser** | Feed parsing for RSS, Atom, JSON Feed, RSS-in-JSON. C/Objective-C parsers for XML formats, native Swift for JSON |
| **RSWeb** | HTTP transport abstraction, conditional GET, downloading, HTML metadata |
| **RSDatabase** | SQLite abstraction over FMDB. `DatabaseQueue` provides serial-queue access with suspend/resume |
| **RSTree** | `Node`/`TreeController` for outline-view data sources |
| **RSMarkdown** | Markdown-to-HTML conversion via Tidemark |
| **Articles** | `Article`, `Author`, `ArticleStatus` data models |
| **ArticlesDatabase** | Article persistence: CRUD, unread/starred/today queries, FTS4 full-text search |
| **SyncDatabase** | Actor-isolated tracking of pending article status changes for sync services |
| **Account** | `Account`, `Feed`, `Folder`, `Container`, `AccountDelegate`, `AccountManager` |
| **CloudKitSync** | CloudKit zone management, change tokens, remote notifications |
| **FeedFinder** | Discovers feed URLs from HTML pages or direct URLs |
| **NewsBlur** | NewsBlur API client models and networking |
| **Secrets** | `CredentialsManager` (Keychain), `SecretKey` (API keys), credential types |

## Account System

The account system is the architectural centerpiece. It uses a delegate pattern: the `Account` class holds state and delegates sync operations to an `AccountDelegate` implementation.

### Supported Account Types

| Type | Delegate | Auth | Sync DB |
|------|----------|------|---------|
| On My Mac | `LocalAccountDelegate` | None | No |
| iCloud | `CloudKitAccountDelegate` | CloudKit | Yes |
| Feedbin | `FeedbinAccountDelegate` | HTTP Basic | Yes |
| Feedly | `FeedlyAccountDelegate` | OAuth2 | Yes |
| NewsBlur | `NewsBlurAccountDelegate` | Session ID | Yes |
| FreshRSS | `ReaderAPIAccountDelegate` | Basic | Yes |
| Inoreader | `ReaderAPIAccountDelegate` | Basic | Yes |
| BazQux | `ReaderAPIAccountDelegate` | Basic | Yes |
| The Old Reader | `ReaderAPIAccountDelegate` | Basic | Yes |

### AccountDelegate Protocol

Every sync backend implements this `@MainActor` protocol:

- **Refresh**: `refreshAll()`, `syncArticleStatus()`, `sendArticleStatus()`, `refreshArticleStatus()`
- **Feed management**: `createFeed()`, `renameFeed()`, `moveFeed()`, `removeFeed()`, `restoreFeed()`
- **Folder management**: `createFolder()`, `renameFolder()`, `removeFolder()`, `restoreFolder()`
- **Status**: `markArticles()` for read/starred state
- **Lifecycle**: `suspendNetwork()`, `suspendDatabase()`, `resume()` for iOS background
- **Validation**: `validateCredentials()` for login flows

### AccountBehaviors

Services declare UI constraints via `AccountBehaviors`:
- `.disallowFeedInRootFolder` (Feedly, FreshRSS)
- `.disallowFeedCopyInRootFolder` (Feedbin)
- `.disallowFeedInMultipleFolders` (Reader API variants)
- `.disallowMarkAsUnreadAfterPeriod(Int)` (Feedly: 31 days)

### Container Hierarchy

`Account` and `Folder` both conform to the `Container` protocol, providing a tree of feeds and folders:

```
Account (Container)
├── Feed
├── Feed
└── Folder (Container)
    ├── Feed
    └── Feed
```

Nested folders are not supported. Each `Feed` has a `feedID` (usually the URL), an optional `externalID` (sync service identifier), and tracks its own unread count.

### AccountManager

The singleton `AccountManager` coordinates all accounts:
- Discovers accounts by scanning the Accounts directory at startup
- Ensures a default local account always exists
- Refreshes all accounts in parallel via `withTaskGroup`
- Aggregates unread counts across accounts

### Data Storage Layout

```
~/Library/.../NetNewsWire/Accounts/
├── OnMyMac/
│   ├── DB.sqlite3              ArticlesDatabase
│   ├── Subscriptions.opml      Feed/folder structure
│   └── FeedMetadata.plist
├── 17_feedbin_{uuid}/
│   ├── DB.sqlite3              ArticlesDatabase
│   ├── Sync.sqlite3            SyncDatabase
│   ├── Subscriptions.opml
│   └── FeedMetadata.plist
└── AccountSettings.db          Global account metadata
```

## Data Persistence

### ArticlesDatabase

Each account owns an `ArticlesDatabase` instance backed by SQLite via FMDB.

**Schema (core tables):**

```
articles            articleID PK, feedID, uniqueID, title, contentHTML,
                    contentText, markdown, url, externalURL, summary,
                    imageURL, bannerImageURL, datePublished, dateModified,
                    searchRowID

statuses            articleID PK, read, starred, dateArrived

authors             authorID PK, name, url, avatarURL, emailAddress

authorsLookup       authorID, articleID  (many-to-many)

search              FTS4 virtual table (title, body)
```

Articles and statuses are stored in separate tables. The Technotes explain why: sync services may report statuses before article content arrives, and statuses are retained much longer than articles to detect re-appearing items.

**Retention styles:**
- `feedBased` (local/iCloud): articles retained based on feed contents
- `syncSystem` (Feedbin, etc.): articles retained based on sync service state

**Search**: FTS4 virtual table indexes stripped HTML content and author names. A trigger removes search entries when articles are deleted.

### SyncDatabase

An `@actor`-isolated database tracking pending status changes for sync services:

```
syncStatus          articleID, key, flag, selected
```

Workflow: mark article read/starred locally → insert into SyncDatabase → next sync sends pending changes → delete on success.

### DatabaseQueue

The `DatabaseQueue` class wraps FMDB with a serial GCD queue. It supports `suspend()` and `resume()` for iOS background transitions, which close and reopen the SQLite connection.

## Feed Parsing

`RSParser` detects feed format via fast byte-level heuristics and dispatches to the appropriate parser:

| Format | Parser | Implementation |
|--------|--------|---------------|
| RSS | `RSRSSParser` | Objective-C (libxml2 SAX) |
| Atom | `RSAtomParser` | Objective-C (libxml2 SAX) |
| JSON Feed | `JSONFeedParser` | Swift (JSONSerialization) |
| RSS-in-JSON | `RSSInJSONParser` | Swift (JSONSerialization) |

All parsers produce `ParsedFeed` / `ParsedItem` structs. If a `ParsedItem` contains a `markdown` field, it is automatically converted to HTML via RSMarkdown.

## Article Rendering

Articles are rendered to HTML for display in WKWebView using a template system.

### Rendering Pipeline

```
Article + Theme → ArticleRenderer → (HTML, CSS, title, baseURL) → WKWebView
```

`ArticleRenderer` loads an HTML template, substitutes placeholders (`[[title]]`, `[[body]]`, `[[byline]]`, `[[datetime_long]]`, etc.), and applies the theme's CSS stylesheet.

### Theme System

Themes are `.nnwtheme` bundles containing:
- `Info.plist` (identifier, name, creator, version)
- `template.html` (HTML structure with placeholder variables)
- `stylesheet.css` (CSS using theme variables like `--article-title-color`, `--header-color`)

Bundled themes: Sepia, NewsFax, Promenade, Appanoose, Hyperlegible. Users can install custom themes via `netnewswire://theme/add?url={url}`.

### Article Extraction

`ArticleExtractor` optionally fetches full article content via Feedbin's Mercury API for feeds that provide only summaries.

## Platform UI

### Three-Pane Interface

Both platforms implement a sidebar/timeline/detail layout:

| Component | macOS | iOS |
|-----------|-------|-----|
| Container | `MainWindowController` (NSWindowController) | `RootSplitViewController` (UISplitViewController) |
| Sidebar | `SidebarViewController` (NSOutlineView) | `MainFeedCollectionViewController` (UICollectionView, diffable) |
| Timeline | `TimelineViewController` (NSTableView) | `MainTimelineModernViewController` (UICollectionView, diffable) |
| Detail | `DetailWebViewController` (WKWebView) | `ArticleViewController` (UIPageViewController + WKWebView) |

### macOS (`Mac/`)

- **Entry point**: `AppDelegate` (`@main`, AppKit)
- **Window management**: `MainWindowController` with toolbar, search, theme menu
- **Preferences**: Tabbed `PreferencesWindowController` (Accounts, General, Advanced)
- **AppleScript**: Full scripting dictionary (`.sdef`) exposing accounts, feeds, folders, articles
- **Updates**: Sparkle framework for auto-updates
- **Crash reporting**: PLCrashReporter integration

### iOS (`iOS/`)

- **Entry point**: `AppDelegate` (`@main`, UIKit) + `SceneDelegate`
- **Navigation**: `SceneCoordinator` is the central navigation hub (~75KB), managing all transitions between feeds, timelines, and articles
- **Adaptive layout**: Three-column split on iPad, stack navigation on iPhone
- **Article swiping**: `UIPageViewController` for swiping between articles
- **Background refresh**: Background task scheduling for feed updates
- **Settings**: Table-based settings UI with some SwiftUI screens (About, Credits)

### Shared (`Shared/`)

Cross-platform code used by both macOS and iOS:

- **Smart Feeds**: `UnreadFeed`, `TodayFeedDelegate`, `StarredFeedDelegate`, `SearchFeedDelegate` — virtual feeds implemented via `SmartFeedDelegate` protocol, aggregating articles across all accounts
- **Article Rendering**: `ArticleRenderer`, HTML templates, CSS, JavaScript
- **Favicons**: Icon downloading and caching
- **User Notifications**: `UserNotificationManager` sends notifications for new articles, with Mark as Read/Starred actions
- **Commands**: Undoable command objects for feed/folder operations
- **Activity**: NSUserActivity for Handoff and state restoration
- **Extension Points**: Send to MarsEdit, Send to Micro.blog
- **Widget Data**: Encoding/decoding article data for iOS widgets via app group

## Extensions

### Share Extensions (iOS + macOS)

Allow subscribing to feeds from other apps. The extension writes an `ExtensionFeedAddRequest` to a shared app group container; the main app picks it up via `NSFilePresenter` file coordination.

### Safari Extension (macOS)

Injects JavaScript to detect the current page URL and offers a toolbar button to subscribe. Communicates via `SFSafariExtensionHandler` message passing.

### Widgets (iOS, SwiftUI)

Four widget types: Unread, Today, Starred (system medium/large), and a lock screen summary. Data flows from the main app via `WidgetDataEncoder` writing JSON to the app group container, read by `TimelineProvider` with a 30-minute refresh policy.

Deep links use `nnw://` scheme: `nnw://showunread?id={articleID}`, `nnw://showtoday`, `nnw://showstarred`.

### Siri Shortcuts

`AddWebFeedIntent` allows adding feeds via Siri or the Shortcuts app. Parameters: URL (required), account name, folder name.

### URL Schemes

- `feed:`, `feeds:` — standard feed subscription
- `netnewswire://theme/add?url={url}` — theme installation
- `nnw://show{unread,today,starred}` — widget deep links

## Concurrency Model

- **`@MainActor`**: Used pervasively on Account, Feed, Folder, Container, Node, all view controllers, and rendering code. Almost all app logic runs on the main thread.
- **Serial dispatch queues**: Database operations run on dedicated serial queues via `DatabaseQueue`, calling back on the main queue.
- **Actors**: `SyncDatabase` is an actor for thread-safe sync state.
- **Mutex**: `ArticleStatus` uses `Mutex<State>` for thread-safe read/starred properties. Database caches use `Mutex<Dictionary>`.
- **Task groups**: `AccountManager.refreshAll()` refreshes accounts in parallel via `withTaskGroup`.
- **Swift 6 strict concurrency**: The project compiles with `SWIFT_STRICT_CONCURRENCY`, warnings as errors, and upcoming features `NonisolatedNonsendingByDefault` and `InferIsolatedConformances`.

## Communication Patterns

**NotificationCenter** is the primary mechanism for loose coupling between components. Key notifications:

| Notification | Purpose |
|-------------|---------|
| `AccountRefreshDidBegin/DidFinish` | Refresh lifecycle |
| `AccountDidDownloadArticles` | New articles available |
| `StatusesDidChange` | Read/starred state changed |
| `AccountStateDidChange` | Account activated/deactivated |
| `UserDidAddAccount/DeleteAccount` | Account lifecycle |
| `ChildrenDidChange` | Feed/folder hierarchy modified |
| `UnreadCountDidChange` | Unread count updated |

All notifications are posted on the main queue. KVO is not used (explicitly prohibited in coding guidelines).

## Third-Party Dependencies

| Dependency | Usage | Platform |
|------------|-------|----------|
| [FMDB](https://github.com/ccgus/fmdb) | SQLite database access | Both |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | Application updates | macOS |
| [PLCrashReporter](https://github.com/microsoft/plcrashreporter) | Crash reporting | macOS |
| [Zip](https://github.com/marmelroy/Zip) | Theme file decompression | Both |
| [Tidemark](https://codeberg.org) | Markdown rendering (via RSMarkdown) | Both |

## Build Configuration

- **Swift version**: 6.2
- **Deployment targets**: macOS 15.0, iOS 26.0
- **Warnings as errors**: `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`
- **Test plans**: `NetNewsWire.xctestplan` (macOS), `NetNewsWire-iOS.xctestplan` (iOS)
- **Build scripts**: `buildscripts/build_and_test.sh` builds both targets and runs tests
- **API keys**: Managed via `buildscripts/updateSecrets.sh` (not in source control)
- **Code signing**: Configured via `SharedXcodeSettings/DeveloperSettings.xcconfig`

## Design Principles

From the project's coding guidelines, in priority order:

1. **No data loss** — the user's data is sacred
2. **No crashes** — never force-unwrap carelessly
3. **No other bugs**
4. **Fast performance** — no auto layout in table cells, profile with Instruments
5. **Developer productivity** — kindergarten-looking code, no showing off

All Swift classes are `final`. No subclassing (except unavoidable AppKit/UIKit subclasses). Protocols and delegates are preferred over inheritance. Model objects are plain structs, no Core Data.
