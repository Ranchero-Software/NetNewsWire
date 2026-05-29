//
//  ImageMetadataDatabase.swift
//  Images
//
//  Created by Brent Simmons on 5/28/26.
//

import Foundation
import RSCore
import RSDatabase
import RSDatabaseObjC

/// Per-URL image metadata: discovered URLs and failure tracking.
@MainActor public final class ImageMetadataDatabase {

	public static let shared = ImageMetadataDatabase()

	public static let failureRetryDays = 5
	private static let failureRetentionDays = 33

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
		let queue = DatabaseQueue(databasePath: databasePath)
		try? queue.runCreateStatements(Self.tableCreationStatements)
		self.queue = queue

		loadCachesFromDatabase()

		let cutoff = Date().timeIntervalSince1970 - TimeInterval(days: Self.failureRetentionDays)
		queue.runInDatabase { result in
			guard let database = try? result.get() else {
				return
			}
			DownloadFailureTable.removeExpired(olderThan: cutoff, database: database)
			database.vacuumIfNeeded()
		}
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
		queue.runInDatabase { result in
			guard let database = try? result.get() else {
				return
			}
			HomePageFaviconTable.save(homePageURL: homePageURL, faviconURL: faviconURL, database: database)
		}
	}

	// MARK: - FeedIconURL

	public func iconURL(forFeedURL feedURL: String) -> String? {
		feedURLToIconURL[feedURL]
	}

	public func saveFeedIconURL(feedURL: String, iconURL: String) {
		feedURLToIconURL[feedURL] = iconURL
		queue.runInDatabase { result in
			guard let database = try? result.get() else {
				return
			}
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
		queue.runInDatabase { result in
			guard let database = try? result.get() else {
				return
			}
			DownloadFailureTable.save(url: url, statusCode: statusCode, database: database)
		}
	}

	public func clearFailure(url: String) {
		guard failureDates.removeValue(forKey: url) != nil else {
			return
		}
		queue.runInDatabase { result in
			guard let database = try? result.get() else {
				return
			}
			DownloadFailureTable.clear(url: url, database: database)
		}
	}
}

private extension ImageMetadataDatabase {

	func loadCachesFromDatabase() {
		nonisolated(unsafe) var homePageRecords = [HomePageFaviconRecord]()
		nonisolated(unsafe) var feedIcons = [String: String]()
		nonisolated(unsafe) var failures = [String: Date]()

		queue.runInDatabaseSync { result in
			guard let database = try? result.get() else {
				return
			}
			homePageRecords = HomePageFaviconTable.fetchAll(database: database)
			feedIcons = FeedIconURLTable.fetchAll(database: database)
			failures = DownloadFailureTable.fetchAll(database: database)
		}

		for record in homePageRecords {
			if let faviconURL = record.faviconURL {
				homePageToFaviconURL[record.homePageURL] = faviconURL
			} else {
				homePagesWithNoFavicon.insert(record.homePageURL)
			}
		}
		feedURLToIconURL = feedIcons
		failureDates = failures
	}
}
