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

public final actor HTMLMetadataDatabase {

	@MainActor public static let shared: HTMLMetadataDatabase = {
		let databasePath = AppConfig.dataFolder
			.appendingPathComponent("HTMLMetadata.db").path
		return HTMLMetadataDatabase(databasePath: databasePath)
	}()

	public nonisolated let databasePath: String

	private let database: FMDatabase
	private var cache = [String: CachedRecord]()

	private struct CachedRecord {
		let record: HTMLMetadataRecord?  // nil for a failure-only entry with no metadata
		let lastChecked: Date
		let statusCode: Int

		/// True when the last contact returned a 4xx.
		var isPersistentFailure: Bool {
			(400...499).contains(statusCode)
		}
		/// True when the last contact failed before getting a response (DNS, TLS, network).
		var isTransientFailure: Bool {
			statusCode == 0
		}
		var isFailure: Bool {
			isPersistentFailure || isTransientFailure
		}
	}

	private static let tableCreationStatements = """
	CREATE TABLE IF NOT EXISTS metadata (url TEXT PRIMARY KEY NOT NULL, lastChecked REAL NOT NULL, statusCode INTEGER NOT NULL DEFAULT 200, favicons TEXT, appleTouchIcons TEXT, feedLinks TEXT, openGraphImages TEXT, twitterImageURL TEXT);
	"""

	/// 149 hours — prime number close to 6 days.
	private static let cacheExpirationHours = 149

	private static let maximumDaysWithoutCheck = 30
	private static let persistentFailureRetryDays = 11
	private static let transientFailureRetryHours = 5

	private init(databasePath: String) {
		self.databasePath = databasePath
		let database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		database.runCreateStatements(Self.tableCreationStatements)
		self.database = database

		NotificationCenter.default.addObserver(
			self, selector: #selector(handleAppDidGoToBackground(_:)),
			name: .appDidGoToBackground, object: nil
		)

		Task {
			await performStartupMaintenance()
		}
	}

	private func performStartupMaintenance() {
		removeExpiredEntries()
		database.vacuumIfNeeded()
	}

	public func vacuum() {
		database.vacuum()
	}

	@objc nonisolated func handleAppDidGoToBackground(_ notification: Notification) {
		Task {
			await emptyCache()
		}
	}

	/// Returns the entry, loading from disk if not in memory.
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

	/// Returns a non-expired success record, or nil.
	func cachedRecord(for url: String) -> HTMLMetadataRecord? {
		guard let cached = cachedOrFetched(url), !cached.isFailure, let record = cached.record else {
			return nil
		}
		guard Date().timeIntervalSince(cached.lastChecked) < TimeInterval(hours: Self.cacheExpirationHours) else {
			return nil
		}
		return record
	}

	/// Returns a success record regardless of expiration.
	func staleCachedRecord(for url: String) -> HTMLMetadataRecord? {
		guard let cached = cachedOrFetched(url), !cached.isFailure else {
			return nil
		}
		return cached.record
	}

	/// The date metadata was last successfully downloaded for this URL, or nil if there's no successful record.
	func lastDownloadDate(for url: String) -> Date? {
		guard let cached = cachedOrFetched(url), !cached.isFailure, cached.record != nil else {
			return nil
		}
		return cached.lastChecked
	}

	/// True if the last contact failed recently (4xx or transient).
	func recentlyFailed(for url: String) -> Bool {
		guard let cached = cachedOrFetched(url) else {
			return false
		}
		if cached.isPersistentFailure {
			return Date().timeIntervalSince(cached.lastChecked) < TimeInterval(days: Self.persistentFailureRetryDays)
		}
		if cached.isTransientFailure {
			return Date().timeIntervalSince(cached.lastChecked) < TimeInterval(hours: Self.transientFailureRetryHours)
		}
		return false
	}

	func save(_ record: HTMLMetadataRecord, statusCode: Int) {
		cache[record.url] = CachedRecord(record: record, lastChecked: Date(), statusCode: statusCode)
		HTMLMetadataTable.insertOrReplace(record: record, statusCode: statusCode, database: database)
	}

	/// Records a failure outcome. Accepts both 4xx and transient (statusCode 0).
	func noteFailure(url: String, statusCode: Int) {
		if cache[url]?.isFailure ?? true {
			cache[url] = CachedRecord(record: nil, lastChecked: Date(), statusCode: statusCode)
		}
		HTMLMetadataTable.noteFailure(url: url, statusCode: statusCode, database: database)
	}

	/// Records a pre-response failure (DNS, TLS, network).
	func noteTransientFailure(url: String) {
		noteFailure(url: url, statusCode: 0)
	}

	func emptyCache() {
		cache.removeAll()
	}

	func removeExpiredEntries() {
		let cutoff = Date().timeIntervalSince1970 - TimeInterval(days: Self.maximumDaysWithoutCheck)
		HTMLMetadataTable.removeExpired(olderThan: cutoff, database: database)
	}
}
