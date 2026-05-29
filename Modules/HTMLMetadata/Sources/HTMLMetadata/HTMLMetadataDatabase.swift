//
//  HTMLMetadataDatabase.swift
//  HTMLMetadata
//
//  Created by Brent Simmons on 4/6/26.
//

import Foundation
import RSCore
import RSDatabase
import RSDatabaseObjC

final actor HTMLMetadataDatabase {

	@MainActor static let shared: HTMLMetadataDatabase = {
		let databasePath = AppConfig.dataFolder
			.appendingPathComponent("HTMLMetadata.db").path
		return HTMLMetadataDatabase(databasePath: databasePath)
	}()

	private let database: FMDatabase
	private var cache = [String: CachedRecord]()

	private struct CachedRecord {
		let record: HTMLMetadataRecord?  // nil for a failure-only entry with no metadata
		let lastChecked: Date
		let statusCode: Int

		/// True when the last contact for this URL returned a 4xx — a dead or
		/// missing homepage we shouldn’t keep re-requesting.
		var isFailure: Bool {
			(400...499).contains(statusCode)
		}
	}

	private static let tableCreationStatements = """
	CREATE TABLE IF NOT EXISTS metadata (url TEXT PRIMARY KEY NOT NULL, lastChecked REAL NOT NULL, statusCode INTEGER NOT NULL DEFAULT 200, favicons TEXT, appleTouchIcons TEXT, feedLinks TEXT, openGraphImages TEXT, twitterImageURL TEXT);
	"""

	/// 73 hours — prime number close to 3 days.
	private static let cacheExpirationHours = 73

	/// Entries that haven't been checked in a number of days are deleted on init.
	private static let maximumDaysWithoutCheck = 30

	/// A homepage that returned a 4xx isn't retried until this many days pass.
	private static let failureRetryDays = 11

	private init(databasePath: String) {
		let database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		database.executeStatements("PRAGMA journal_mode = WAL;")
		database.runCreateStatements(Self.tableCreationStatements)
		self.database = database

		NotificationCenter.default.addObserver(
			self, selector: #selector(handleAppDidGoToBackground(_:)),
			name: .appDidGoToBackground, object: nil
		)

		// Run maintenance off the main thread (init may be evaluated there).
		Task {
			await performStartupMaintenance()
		}
	}

	private func performStartupMaintenance() {
		removeExpiredEntries()
		database.vacuumIfNeeded()
	}

	@objc nonisolated func handleAppDidGoToBackground(_ notification: Notification) {
		Task {
			await emptyCache()
		}
	}

	/// Returns the cached entry for a URL — in-memory if present, otherwise loaded
	/// from SQLite and cached. Returns nil only when there’s no row at all.
	private func cachedOrFetched(_ url: String) -> CachedRecord? {
		if let cached = cache[url] {
			return cached
		}

		guard let fetched = HTMLMetadataTable.fetchRecordAndLastCheckedDate(url: url, database: database) else {
			return nil
		}

		let cached = CachedRecord(record: fetched.record, lastChecked: fetched.lastChecked, statusCode: fetched.statusCode)
		cache[url] = cached
		return cached
	}

	/// Returns a non-expired, successfully-fetched record. Returns nil if there’s
	/// no record, it’s a failure entry, or it has expired.
	func cachedRecord(for url: String) -> HTMLMetadataRecord? {
		guard let cached = cachedOrFetched(url), !cached.isFailure, let record = cached.record else {
			return nil
		}
		guard Date().timeIntervalSince(cached.lastChecked) < TimeInterval(hours: Self.cacheExpirationHours) else {
			return nil
		}
		return record
	}

	/// Returns a successfully-fetched record regardless of expiration. Used for stale fallback.
	func staleCachedRecord(for url: String) -> HTMLMetadataRecord? {
		guard let cached = cachedOrFetched(url), !cached.isFailure else {
			return nil
		}
		return cached.record
	}

	/// True if the last contact for this URL was a recent 4xx, meaning we should
	/// skip re-downloading it for now.
	func recentlyFailed(for url: String) -> Bool {
		guard let cached = cachedOrFetched(url), cached.isFailure else {
			return false
		}
		return Date().timeIntervalSince(cached.lastChecked) < TimeInterval(days: Self.failureRetryDays)
	}

	func save(_ record: HTMLMetadataRecord, statusCode: Int) {
		cache[record.url] = CachedRecord(record: record, lastChecked: Date(), statusCode: statusCode)
		HTMLMetadataTable.insertOrReplace(record: record, statusCode: statusCode, database: database)
	}

	/// Records a 4xx outcome for a URL so we stop re-requesting it across launches.
	/// Mirrors the SQLite guard in HTMLMetadataTable.noteFailure: never downgrade a
	/// successful entry — keep serving its metadata. Only record the failure when
	/// there’s no successful entry to protect.
	func noteFailure(url: String, statusCode: Int) {
		if cache[url]?.isFailure ?? true {
			cache[url] = CachedRecord(record: nil, lastChecked: Date(), statusCode: statusCode)
		}
		HTMLMetadataTable.noteFailure(url: url, statusCode: statusCode, database: database)
	}

	func emptyCache() {
		cache.removeAll()
	}

	func removeExpiredEntries() {
		let cutoff = Date().timeIntervalSince1970 - TimeInterval(days: Self.maximumDaysWithoutCheck)
		HTMLMetadataTable.removeExpired(olderThan: cutoff, database: database)
	}
}
