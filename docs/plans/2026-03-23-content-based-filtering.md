# Content-Based Article Filtering - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Auto-mark articles as read based on per-feed keyword filters (keyword present or absent).

**Architecture:** Add an `ArticleFilter` model stored as JSON in the existing `feedSettings` database. After new articles are saved during feed refresh, evaluate each against its feed's filters and mark matching articles as read via the existing `updateAsync(articles:statusKey:flag:)` path.

**Tech Stack:** Swift, SQLite (FMDB), existing Account/Articles modules

---

### Task 1: ArticleFilter Model

**Files:**
- Create: `Modules/Account/Sources/Account/ArticleFilter.swift`

ArticleFilter is a Codable struct with a keyword and match type (contains / doesNotContain). It evaluates against Article text fields (title, contentHTML, contentText, summary, author names). Case-insensitive matching.

### Task 2: FeedSettingsDatabase Storage

**Files:**
- Modify: `Modules/Account/Sources/Account/FeedSettingsDatabase.swift`

Add `articleFilters TEXT` column (JSON-encoded array). Add to Column enum, Row struct, tableCreationStatements, row(from:) parser, and a setter method. Add ALTER TABLE migration for existing databases.

### Task 3: FeedSettings + Feed Properties

**Files:**
- Modify: `Modules/Account/Sources/Account/FeedSettings.swift`
- Modify: `Modules/Account/Sources/Account/Feed.swift`
- Modify: `Modules/Account/Sources/Account/DataExtensions.swift`

Add `articleFilters: [ArticleFilter]?` property to FeedSettings (with didSet persistence), Feed (delegating to settings), and a new SettingKey case.

### Task 4: Filter Application in Account

**Files:**
- Modify: `Modules/Account/Sources/Account/Account.swift`

Add `applyArticleFilters(to:)` method. Call it in both `updateAsync(feedID:parsedItems:)` and `updateAsync(feedIDsAndItems:defaultRead:)` after articles are saved, before notifications.

### Task 5: Unit Tests

**Files:**
- Create: `Modules/Account/Tests/AccountTests/ArticleFilterTests.swift`

Test filter matching logic: contains/doesNotContain, case insensitivity, author matching, empty filters, multiple filters.
