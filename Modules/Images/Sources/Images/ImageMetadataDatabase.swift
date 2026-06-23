//
//  ImageMetadataDatabase.swift
//  Images
//
//  Created by Brent Simmons on 5/28/26.
//

import Foundation
import os
import RSCore
import RSDatabase
import RSDatabaseObjC

/// Per-URL image metadata: discovered URLs and failure tracking.
@MainActor public final class ImageMetadataDatabase {

	public static let shared = ImageMetadataDatabase()

	public static let failureRetryDays = 5
	private static let failureRetentionDays = 33

	public let databasePath: String

	nonisolated static private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ImageMetadataDatabase")

	private let queue: DatabaseQueue

	private var homePageToFaviconURL = [String: String]()
	private var homePagesWithNoFavicon = Set<String>()
	private var feedURLToIconURL = [String: String]()
	private var failureDates = [String: Date]()

	private static let tableCreationStatements = """
	CREATE TABLE IF NOT EXISTS downloadFailure (url TEXT PRIMARY KEY NOT NULL, statusCode INTEGER, lastChecked REAL NOT NULL);
	CREATE TABLE IF NOT EXISTS homePageFavicon (homePageURL TEXT PRIMARY KEY NOT NULL, faviconURL TEXT, lastChecked REAL NOT NULL);
	CREATE TABLE IF NOT EXISTS feedIconURL (feedURL TEXT PRIMARY KEY NOT NULL, iconURL TEXT NOT NULL, lastChecked REAL NOT NULL);
	"""

	private init() {
		let databasePath = AppConfig.dataFolder
			.appendingPathComponent("ImageMetadata.db").path
		self.databasePath = databasePath
		let queue = DatabaseQueue(databasePath: databasePath)
		queue.runCreateStatements(Self.tableCreationStatements)
		self.queue = queue

		loadCachesFromDatabase()

		let cutoff = Date().timeIntervalSince1970 - TimeInterval(days: Self.failureRetentionDays)
		queue.runInDatabase { database in
			DownloadFailureTable.removeExpired(olderThan: cutoff, database: database)
			database.vacuumIfNeeded()
		}
	}

	// MARK: - Vacuum

	public func vacuum() async {
		await queue.vacuum()
	}

	// MARK: - HomePageFavicon

	public func faviconURL(forHomePageURL homePageURL: String) -> String? {
		homePageToFaviconURL[homePageURL]
	}

	public func homePageHasNoFavicon(_ homePageURL: String) -> Bool {
		homePagesWithNoFavicon.contains(homePageURL)
	}

	public func saveHomePageFavicon(homePageURL: String, faviconURL: String?) {
		if let faviconURL {
			homePageToFaviconURL[homePageURL] = faviconURL
			homePagesWithNoFavicon.remove(homePageURL)
		} else {
			homePagesWithNoFavicon.insert(homePageURL)
			homePageToFaviconURL.removeValue(forKey: homePageURL)
		}
		queue.runInDatabase { database in
			HomePageFaviconTable.save(homePageURL: homePageURL, faviconURL: faviconURL, database: database)
		}
	}

	// MARK: - FeedIconURL

	public func iconURL(forFeedURL feedURL: String) -> String? {
		feedURLToIconURL[feedURL]
	}

	public func saveFeedIconURL(feedURL: String, iconURL: String) {
		feedURLToIconURL[feedURL] = iconURL
		queue.runInDatabase { database in
			FeedIconURLTable.save(feedURL: feedURL, iconURL: iconURL, database: database)
		}
	}

	// MARK: - DownloadFailure

	public func recentlyFailed(url: String) -> Bool {
		guard let lastFailure = failureDates[url] else {
			return false
		}
		return Date().timeIntervalSince(lastFailure) < TimeInterval(days: Self.failureRetryDays)
	}

	public func recordFailure(url: String, statusCode: Int?) {
		failureDates[url] = Date()
		queue.runInDatabase { database in
			DownloadFailureTable.save(url: url, statusCode: statusCode, database: database)
		}
	}

	public func clearFailure(url: String) {
		guard failureDates.removeValue(forKey: url) != nil else {
			return
		}
		queue.runInDatabase { database in
			DownloadFailureTable.clear(url: url, database: database)
		}
	}
}

private extension ImageMetadataDatabase {

	func loadCachesFromDatabase() {
		nonisolated(unsafe) var homePageRecords = [HomePageFaviconRecord]()
		nonisolated(unsafe) var feedIcons = [String: String]()
		nonisolated(unsafe) var failures = [String: Date]()
		nonisolated(unsafe) var homePageDuration: TimeInterval = 0
		nonisolated(unsafe) var feedIconDuration: TimeInterval = 0
		nonisolated(unsafe) var failureDuration: TimeInterval = 0

		let totalStart = Date()
		queue.runInDatabaseSync { database in
			var stepStart = Date()
			homePageRecords = HomePageFaviconTable.fetchAll(database: database)
			homePageDuration = Date().timeIntervalSince(stepStart)

			stepStart = Date()
			feedIcons = FeedIconURLTable.fetchAll(database: database)
			feedIconDuration = Date().timeIntervalSince(stepStart)

			stepStart = Date()
			failures = DownloadFailureTable.fetchAll(database: database)
			failureDuration = Date().timeIntervalSince(stepStart)
		}
		let totalDuration = Date().timeIntervalSince(totalStart)

		for record in homePageRecords {
			if let faviconURL = record.faviconURL {
				homePageToFaviconURL[record.homePageURL] = faviconURL
			} else {
				homePagesWithNoFavicon.insert(record.homePageURL)
			}
		}
		feedURLToIconURL = feedIcons
		failureDates = failures

		Self.logger.info("Initial fetches: homePageFavicon \(homePageRecords.count) rows in \(homePageDuration) seconds, feedIconURL \(feedIcons.count) rows in \(feedIconDuration) seconds, downloadFailure \(failures.count) rows in \(failureDuration) seconds, total \(totalDuration) seconds")
	}
}
