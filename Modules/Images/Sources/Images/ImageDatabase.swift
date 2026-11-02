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
@MainActor public final class ImageDatabase {

	public static let shared = ImageDatabase()

	private static let failureRetryDays = 5

	public let databasePath: String

	nonisolated static private let logger = Logger(subsystem: Logger.nnwSubsystem, category: "ImageDatabase")

	private let queue: DatabaseQueue

	private var homePageToFaviconURL = [String: String]()
	private var homePagesWithNoFavicon = Set<String>()
	private var feedURLToIconURL = [String: String]()
	private var failureDates = [String: Date]()
	private var urlsUnsuitableForThumbnails = Set<String>()

	private static let tableCreationStatements = """
	CREATE TABLE IF NOT EXISTS downloadFailure (url TEXT PRIMARY KEY NOT NULL, lastChecked REAL NOT NULL);
	CREATE TABLE IF NOT EXISTS homePageFavicon (homePageURL TEXT PRIMARY KEY NOT NULL, faviconURL TEXT, lastChecked REAL NOT NULL);
	CREATE TABLE IF NOT EXISTS feedIconURL (feedURL TEXT PRIMARY KEY NOT NULL, iconURL TEXT NOT NULL);
	CREATE TABLE IF NOT EXISTS downloadedImage (url TEXT PRIMARY KEY NOT NULL, pixelWidth INTEGER, pixelHeight INTEGER, lastAccessed REAL NOT NULL, etag TEXT, lastModified TEXT, nextCheck REAL NOT NULL);
	"""

	/// Development builds created this table.
	nonisolated private static let dropArticleThumbnailTableStatement = "DROP TABLE IF EXISTS articleThumbnailURLs;"

	private static let databaseFileName = "Images.db"
	private static let legacyDatabaseFileName = "ImageMetadata.db"

	/// Tables and columns imported from ImageMetadata.db, which shipped before Images.db replaced it.
	nonisolated private static let legacyTableColumns = [
		(table: "downloadFailure", columns: "url, lastChecked"),
		(table: "homePageFavicon", columns: "homePageURL, faviconURL, lastChecked"),
		(table: "feedIconURL", columns: "feedURL, iconURL")
	]

	private convenience init() {
		self.init(databasePath: AppConfig.dataFolder.appendingPathComponent(Self.databaseFileName).path, legacyDatabasePath: AppConfig.dataFolder.appendingPathComponent(Self.legacyDatabaseFileName).path)
	}

	init(databasePath: String, legacyDatabasePath: String? = nil) {
		self.databasePath = databasePath
		let queue = DatabaseQueue(databasePath: databasePath, journalMode: .wal)
		queue.runCreateStatements(Self.tableCreationStatements)
		self.queue = queue

		if let legacyDatabasePath, FileManager.default.fileExists(atPath: legacyDatabasePath) {
			queue.runInDatabaseSync { database in
				Self.importLegacyDatabase(path: legacyDatabasePath, database: database)
			}
			// Deleted even if the import failed: the data can be rebuilt, and this keeps the import to one run.
			Self.deleteLegacyDatabase(path: legacyDatabasePath)
		}

		loadCachesFromDatabase()

		let failureCutoff = Date().timeIntervalSince1970 - TimeInterval(days: Self.failureRetryDays)
		queue.runInDatabase { database in
			DownloadFailureTable.removeExpired(olderThan: failureCutoff, database: database)
			database.executeStatements(Self.dropArticleThumbnailTableStatement)
			database.checkpoint()
		}
	}

	// MARK: - Vacuum

	/// A WAL checkpoint, since this database is in WAL mode.
	public func vacuum() async {
		await queue.checkpoint()
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

	public func recordFailure(url: String) {
		failureDates[url] = Date()
		queue.runInDatabase { database in
			DownloadFailureTable.save(url: url, database: database)
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

	func fetchDownloadedImageUsageByLeastRecentAccess() async -> [DownloadedImageUsage]? {
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

	nonisolated static func importLegacyDatabase(path: String, database: FMDatabase) {
		guard database.executeUpdate("ATTACH DATABASE ? AS legacy", withArgumentsIn: [path]) else {
			logger.error("Could not attach legacy database: \(database.lastErrorMessage() ?? "unknown", privacy: .public)")
			return
		}

		// ATTACH and DETACH can’t run inside a transaction.
		database.beginTransaction()
		for (table, columns) in legacyTableColumns {
			if database.executeUpdate("INSERT OR IGNORE INTO main.\(table) (\(columns)) SELECT \(columns) FROM legacy.\(table)", withArgumentsIn: []) {
				let rowCount = database.changes()
				logger.info("Imported \(rowCount) rows into \(table, privacy: .public) from legacy database")
			} else {
				logger.error("Could not import \(table, privacy: .public) from legacy database: \(database.lastErrorMessage() ?? "unknown", privacy: .public)")
			}
		}
		database.commit()

		database.executeStatements("DETACH DATABASE legacy;")
	}

	static func deleteLegacyDatabase(path: String) {
		do {
			try FileManager.default.removeItem(atPath: path)
		} catch {
			logger.error("Could not delete legacy database \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
		}
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
