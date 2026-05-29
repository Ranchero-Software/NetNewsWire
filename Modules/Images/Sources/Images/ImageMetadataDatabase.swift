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
public actor ImageMetadataDatabase {

	@MainActor public static let shared: ImageMetadataDatabase = {
		let databasePath = AppConfig.dataFolder
			.appendingPathComponent("ImageMetadata.db").path
		return ImageMetadataDatabase(databasePath: databasePath)
	}()

	private static let failureRetentionDays = 33

	private let database: FMDatabase

	private static let tableCreationStatements = """
	CREATE TABLE IF NOT EXISTS downloadFailure (url TEXT PRIMARY KEY NOT NULL, statusCode INTEGER, lastChecked REAL NOT NULL);
	CREATE TABLE IF NOT EXISTS homePageFavicon (homePageURL TEXT PRIMARY KEY NOT NULL, faviconURL TEXT, lastChecked REAL NOT NULL);
	CREATE TABLE IF NOT EXISTS feedIconURL (feedURL TEXT PRIMARY KEY NOT NULL, iconURL TEXT NOT NULL, lastChecked REAL NOT NULL);
	"""

	private init(databasePath: String) {
		let database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		database.executeStatements("PRAGMA journal_mode = WAL;")
		database.runCreateStatements(Self.tableCreationStatements)
		self.database = database

		Task {
			await performStartupMaintenance()
		}
	}

	// MARK: - HomePageFavicon

	public func allHomePageFavicons() -> [HomePageFaviconRecord] {
		HomePageFaviconTable.fetchAll(database: database)
	}

	public func saveHomePageFavicon(homePageURL: String, faviconURL: String?) {
		HomePageFaviconTable.save(homePageURL: homePageURL, faviconURL: faviconURL, database: database)
	}

	// MARK: - FeedIconURL

	public func allFeedIconURLs() -> [String: String] {
		FeedIconURLTable.fetchAll(database: database)
	}

	public func saveFeedIconURL(feedURL: String, iconURL: String) {
		FeedIconURLTable.save(feedURL: feedURL, iconURL: iconURL, database: database)
	}

	// MARK: - DownloadFailure

	public func allDownloadFailures() -> [String: Date] {
		DownloadFailureTable.fetchAll(database: database)
	}

	public func recordDownloadFailure(url: String, statusCode: Int?) {
		DownloadFailureTable.save(url: url, statusCode: statusCode, database: database)
	}

	public func clearDownloadFailure(url: String) {
		DownloadFailureTable.clear(url: url, database: database)
	}
}

private extension ImageMetadataDatabase {

	func performStartupMaintenance() {
		let cutoff = Date().timeIntervalSince1970 - TimeInterval(days: Self.failureRetentionDays)
		DownloadFailureTable.removeExpired(olderThan: cutoff, database: database)
		database.vacuumIfNeeded()
	}
}
