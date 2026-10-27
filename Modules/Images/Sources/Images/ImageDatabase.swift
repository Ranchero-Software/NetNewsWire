//
//  ImageDatabase.swift
//  Images
//
//  Created by Brent Simmons on 5/28/26.
//

import Foundation
import os
import RSCore
import RSDatabase
import RSDatabaseObjC
import RSParser

/// Per-URL image metadata: discovered URLs, failure tracking, and the copies `DownloadedImageCache` stores.
/// Also thumbnails found in article HTML, which aren’t loaded into memory at init, since there’s a row per article.
@MainActor public final class ImageDatabase {

	public static let shared = ImageDatabase()

	public static let failureRetryDays = 5
	private static let failureRetentionDays = 33

	public let databasePath: String

	nonisolated static private let logger = Logger(subsystem: Logger.nnwSubsystem, category: "ImageDatabase")

	private let queue: DatabaseQueue

	private var homePageToFaviconURL = [String: String]()
	private var homePagesWithNoFavicon = Set<String>()
	private var feedURLToIconURL = [String: String]()
	private var failureDates = [String: Date]()
	private var urlsUnsuitableForThumbnails = Set<String>()

	private static let tableCreationStatements = """
	CREATE TABLE IF NOT EXISTS downloadFailure (url TEXT PRIMARY KEY NOT NULL, statusCode INTEGER, lastChecked REAL NOT NULL);
	CREATE TABLE IF NOT EXISTS homePageFavicon (homePageURL TEXT PRIMARY KEY NOT NULL, faviconURL TEXT, lastChecked REAL NOT NULL);
	CREATE TABLE IF NOT EXISTS feedIconURL (feedURL TEXT PRIMARY KEY NOT NULL, iconURL TEXT NOT NULL, lastChecked REAL NOT NULL);
	CREATE TABLE IF NOT EXISTS articleThumbnailURLs (articleID TEXT PRIMARY KEY NOT NULL, thumbnailURLs TEXT, lastChecked REAL NOT NULL);
	CREATE TABLE IF NOT EXISTS downloadedImage (url TEXT PRIMARY KEY NOT NULL, byteCount INTEGER NOT NULL, pixelWidth INTEGER, pixelHeight INTEGER, lastAccessed REAL NOT NULL, etag TEXT, lastModified TEXT, nextCheck REAL NOT NULL);
	"""

	private convenience init() {
		self.init(databasePath: AppConfig.dataFolder.appendingPathComponent("ImageMetadata.db").path)
	}

	init(databasePath: String) {
		self.databasePath = databasePath
		let queue = DatabaseQueue(databasePath: databasePath)
		queue.runCreateStatements(Self.tableCreationStatements)
		self.queue = queue

		loadCachesFromDatabase()

		let cutoff = Date().timeIntervalSince1970 - TimeInterval(days: Self.failureRetentionDays)
		queue.runInDatabase { database in
			DownloadFailureTable.removeExpired(olderThan: cutoff, database: database)
			// Expiring rows means articles get rechecked, in case their HTML changed.
			ArticleThumbnailTable.removeExpired(olderThan: cutoff, database: database)
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

	// MARK: - ArticleThumbnail

	func fetchArticleThumbnails(articleIDs: [String]) async -> [ArticleThumbnailRecord] {
		await withCheckedContinuation { continuation in
			queue.runInDatabase { database in
				continuation.resume(returning: ArticleThumbnailTable.fetch(articleIDs: articleIDs, database: database))
			}
		}
	}

	func saveArticleThumbnails(_ records: [ArticleThumbnailRecord]) {
		queue.runInTransaction { database in
			ArticleThumbnailTable.save(records, database: database)
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

	// MARK: - DownloadedImage

	/// True when the stored copy is too small, too narrow, or unreadable by ImageIO.
	/// It may still be a fine feed icon.
	public func isUnsuitableForThumbnail(url: String) -> Bool {
		urlsUnsuitableForThumbnails.contains(url)
	}

	func saveDownloadedImage(_ record: DownloadedImageRecord) {
		if Self.isSuitableForThumbnail(record.pixelSize) {
			urlsUnsuitableForThumbnails.remove(record.url)
		} else {
			urlsUnsuitableForThumbnails.insert(record.url)
		}
		queue.runInDatabase { database in
			DownloadedImageTable.save(record, database: database)
		}
	}

	func saveDownloadedImageAccessDate(url: String) {
		queue.runInDatabase { database in
			DownloadedImageTable.saveAccessDate(url: url, database: database)
		}
	}

	func fetchDownloadedImageValidation(url: String) async -> DownloadedImageValidation? {
		await withCheckedContinuation { continuation in
			queue.runInDatabase { database in
				continuation.resume(returning: DownloadedImageTable.fetchValidation(url: url, database: database))
			}
		}
	}

	func saveDownloadedImageNextCheck(url: String, nextCheck: Date) {
		queue.runInDatabase { database in
			DownloadedImageTable.saveNextCheck(url: url, nextCheck: nextCheck, database: database)
		}
	}

	func fetchDownloadedImageUsageByLeastRecentAccess() async -> [DownloadedImageUsage] {
		await withCheckedContinuation { continuation in
			queue.runInDatabase { database in
				continuation.resume(returning: DownloadedImageTable.fetchUsageByLeastRecentAccess(database: database))
			}
		}
	}

	func deleteDownloadedImages(urls: [String]) {
		guard !urls.isEmpty else {
			return
		}
		urlsUnsuitableForThumbnails.subtract(urls)
		queue.runInTransaction { database in
			DownloadedImageTable.delete(urls: urls, database: database)
		}
	}
}

private extension ImageDatabase {

	static func isSuitableForThumbnail(_ pixelSize: (width: Int, height: Int)?) -> Bool {
		guard let pixelSize else {
			return false
		}
		return SignificantImageFilter.hasSignificantDimensions(width: pixelSize.width, height: pixelSize.height)
	}

	func loadCachesFromDatabase() {
		nonisolated(unsafe) var homePageRecords = [HomePageFaviconRecord]()
		nonisolated(unsafe) var feedIcons = [String: String]()
		nonisolated(unsafe) var failures = [String: Date]()
		nonisolated(unsafe) var pixelSizes = [(url: String, pixelSize: (width: Int, height: Int)?)]()
		nonisolated(unsafe) var homePageDuration: TimeInterval = 0
		nonisolated(unsafe) var feedIconDuration: TimeInterval = 0
		nonisolated(unsafe) var failureDuration: TimeInterval = 0
		nonisolated(unsafe) var pixelSizeDuration: TimeInterval = 0

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

			stepStart = Date()
			pixelSizes = DownloadedImageTable.fetchPixelSizes(database: database)
			pixelSizeDuration = Date().timeIntervalSince(stepStart)
		}
		let totalDuration = Date().timeIntervalSince(totalStart)

		for record in homePageRecords {
			if let faviconURL = record.faviconURL {
				homePageToFaviconURL[record.homePageURL] = faviconURL
			} else if Date().timeIntervalSince(record.lastChecked) < TimeInterval(days: Self.failureRetryDays) {
				// A no-favicon verdict expires after failureRetryDays, so the homepage gets rechecked.
				homePagesWithNoFavicon.insert(record.homePageURL)
			}
		}
		feedURLToIconURL = feedIcons
		failureDates = failures
		urlsUnsuitableForThumbnails = Set(pixelSizes.filter { !Self.isSuitableForThumbnail($0.pixelSize) }.map(\.url))

		Self.logger.info("Initial fetches: homePageFavicon \(homePageRecords.count) rows in \(homePageDuration) seconds, feedIconURL \(feedIcons.count) rows in \(feedIconDuration) seconds, downloadFailure \(failures.count) rows in \(failureDuration) seconds, downloadedImage \(pixelSizes.count) rows in \(pixelSizeDuration) seconds, total \(totalDuration) seconds")
	}
}
