//
//  MinifluxModels.swift
//  Account
//
//  Created by Ingmar Stein on 6/18/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// MARK: - Feeds

struct MinifluxFeed: Decodable, Sendable {
	let id: Int
	let title: String
	let feedURL: String
	let siteURL: String?
	let category: MinifluxCategory?
	let icon: MinifluxFeedIcon?
	let crawler: Bool?
	let disabled: Bool?
	let fetchViaProxy: Bool?
	let scraperRules: String?
	let rewriteRules: String?
	let blocklistRules: String?
	let keeplistRules: String?
	let userAgent: String?
	let username: String?
	let password: String?
	let ignoreHTTPCache: Bool?
	let checkedAt: String?
	let etagHeader: String?
	let lastModifiedHeader: String?
	let parsingErrorCount: Int?
	let parsingErrorMessage: String?

	enum CodingKeys: String, CodingKey {
		case id
		case title
		case feedURL = "feed_url"
		case siteURL = "site_url"
		case category
		case icon
		case crawler
		case disabled
		case fetchViaProxy = "fetch_via_proxy"
		case scraperRules = "scraper_rules"
		case rewriteRules = "rewrite_rules"
		case blocklistRules = "blocklist_rules"
		case keeplistRules = "keeplist_rules"
		case userAgent = "user_agent"
		case username
		case password
		case ignoreHTTPCache = "ignore_http_cache"
		case checkedAt = "checked_at"
		case etagHeader = "etag_header"
		case lastModifiedHeader = "last_modified_header"
		case parsingErrorCount = "parsing_error_count"
		case parsingErrorMessage = "parsing_error_message"
	}
}

struct MinifluxFeedIcon: Decodable, Sendable {
	let feedID: Int
	let iconID: Int

	enum CodingKeys: String, CodingKey {
		case feedID = "feed_id"
		case iconID = "icon_id"
	}
}

struct MinifluxCreateFeedResult: Decodable, Sendable {
	let feedID: Int

	enum CodingKeys: String, CodingKey {
		case feedID = "feed_id"
	}
}

// MARK: - Categories

struct MinifluxCategory: Decodable, Sendable {
	let id: Int
	let title: String
	let userID: Int?
	let hideGlobally: Bool?
	let totalUnread: Int?
	let feedCount: Int?

	enum CodingKeys: String, CodingKey {
		case id
		case title
		case userID = "user_id"
		case hideGlobally = "hide_globally"
		case totalUnread = "total_unread"
		case feedCount = "feed_count"
	}
}

struct MinifluxCreateCategoryResult: Decodable, Sendable {
	let id: Int
}

// MARK: - Entries

struct MinifluxEntry: Decodable, Sendable {
	let id: Int
	let userID: Int?
	let title: String
	let url: String?
	let content: String
	let author: String?
	let publishedAt: String
	let createdAt: String
	let status: String
	let starred: Bool?
	let readingTime: Int?
	let hash: String?
	let shareCode: String?
	let enclosures: [MinifluxEnclosure]?
	let feed: MinifluxEntryFeed
	let tags: [String]?

	enum CodingKeys: String, CodingKey {
		case id
		case userID = "user_id"
		case title
		case url
		case content
		case author
		case publishedAt = "published_at"
		case createdAt = "created_at"
		case status
		case starred
		case readingTime = "reading_time"
		case hash
		case shareCode = "share_code"
		case enclosures
		case feed
		case tags
	}
}

struct MinifluxEntryFeed: Decodable, Sendable {
	let id: Int
	let title: String
	let feedURL: String?
	let siteURL: String?

	enum CodingKeys: String, CodingKey {
		case id
		case title
		case feedURL = "feed_url"
		case siteURL = "site_url"
	}
}

struct MinifluxEnclosure: Decodable, Sendable {
	let id: Int
	let userID: Int
	let entryID: Int
	let url: String
	let mimeType: String
	let size: Int?

	enum CodingKeys: String, CodingKey {
		case id
		case userID = "user_id"
		case entryID = "entry_id"
		case url
		case mimeType = "mime_type"
		case size
	}
}

struct MinifluxEntriesResult: Decodable, Sendable {
	let total: Int
	let entries: [MinifluxEntry]
}

// MARK: - Version

struct MinifluxVersion: Decodable, Sendable {
	let version: String
	let commit: String?
	let buildDate: String?

	enum CodingKeys: String, CodingKey {
		case version
		case commit
		case buildDate = "build_date"
	}

	/// Compares this version against a minimum required version string like "2.3.2".
	func isAtLeast(_ minVersion: String) -> Bool {
		let this = version.split(separator: ".").compactMap { Int($0) }
		let other = minVersion.split(separator: ".").compactMap { Int($0) }
		let maxLen = max(this.count, other.count)
		for i in 0..<maxLen {
			let a = i < this.count ? this[i] : 0
			let b = i < other.count ? other[i] : 0
			if a < b { return false }
			if a > b { return true }
		}
		return true
	}
}

// MARK: - Entry IDs (v2.3.2+)

struct MinifluxEntryIDsResult: Decodable, Sendable {
	let total: Int
	let entryIDs: [Int]

	enum CodingKeys: String, CodingKey {
		case total
		case entryIDs = "entry_ids"
	}
}

// MARK: - User

struct MinifluxUser: Decodable, Sendable {
	let id: Int
	let username: String
	let isAdmin: Bool?
	let theme: String?
	let language: String?
	let timezone: String?
	let entryDirection: String?
	let entriesPerPage: Int?
	let keyboardShortcuts: Bool?
	let showReadingTime: Bool?
	let entrySwipe: Bool?
	let gestureNav: Bool?
	let externalFontHosts: String?
	let stylesheet: String?
	let googleReader: Bool?
	let doubleTap: Bool?

	enum CodingKeys: String, CodingKey {
		case id
		case username
		case isAdmin = "is_admin"
		case theme
		case language
		case timezone
		case entryDirection = "entry_direction"
		case entriesPerPage = "entries_per_page"
		case keyboardShortcuts = "keyboard_shortcuts"
		case showReadingTime = "show_reading_time"
		case entrySwipe = "entry_swipe"
		case gestureNav = "gesture_nav"
		case externalFontHosts = "external_font_hosts"
		case stylesheet
		case googleReader = "google_reader"
		case doubleTap = "double_tap"
	}
}

// MARK: - Discover

struct MinifluxDiscoverResult: Decodable, Sendable {
	let url: String
	let title: String
	let type: String
}

// MARK: - Batch Entry Update

struct MinifluxBatchEntryUpdate: Encodable, Sendable {
	let entryIDs: [Int]
	let status: String

	enum CodingKeys: String, CodingKey {
		case entryIDs = "entry_ids"
		case status
	}
}

// MARK: - Error

struct MinifluxError: Decodable, Sendable {
	let errorMessage: String

	enum CodingKeys: String, CodingKey {
		case errorMessage = "error_message"
	}
}
