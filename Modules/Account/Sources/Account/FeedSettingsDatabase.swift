//
//  FeedSettingsDatabase.swift
//  Account
//
//  Created by Brent Simmons on 3/6/26.
//

import Foundation
import os
import RSCore
import RSDatabase
import RSDatabaseObjC
import RSWeb
import Articles

final class FeedSettingsDatabase: Sendable {
	enum Column: String {
		case feedID
		case homePageURL
		case iconURL
		case faviconURL
		case editedName
		case contentHash
		case newArticleNotificationsEnabled
		case readerViewAlwaysEnabled
		case authors
		case conditionalGetInfoLastModified
		case conditionalGetInfoEtag
		case conditionalGetInfoDate
		case cacheControlInfoDateCreated
		case cacheControlInfoMaxAge
		case externalID
		case folderRelationship
		case lastCheckDate
		case articleFilters
	}

	struct Row {
		let feedID: String
		let homePageURL: String?
		let iconURL: String?
		let faviconURL: String?
		let editedName: String?
		let contentHash: String?
		let newArticleNotificationsEnabled: Bool
		let readerViewAlwaysEnabled: Bool
		let authors: [Author]?
		let conditionalGetInfo: HTTPConditionalGetInfo?
		let conditionalGetInfoDate: Date?
		let cacheControlInfo: CacheControlInfo?
		let externalID: String?
		let folderRelationship: [String: String]?
		let lastCheckDate: Date?
		let articleFilters: [ArticleFilter]?
	}

	nonisolated(unsafe) private let database: FMDatabase // Used on serial dispatch queue only
	private let serialDispatchQueue: DispatchQueue
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FeedSettingsDatabase")

	init(databasePath: String) {
		self.serialDispatchQueue = DispatchQueue(label: "FeedSettingsDatabase")
		self.database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		serialDispatchQueue.sync { [database] in
			database.executeStatements("PRAGMA journal_mode = WAL;")
			database.runCreateStatements(Self.tableCreationStatements)
			Self.addArticleFiltersColumnIfNeeded(database)
		}
		if !Platform.isRunningUnitTests {
			vacuum()
		}
	}

	func vacuum() {
		serialDispatchQueue.async {
			self.database.vacuum()
		}
	}

	var isEmpty: Bool {
		serialDispatchQueue.sync {
			guard let resultSet = self.database.executeQuery("SELECT 1 FROM feedSettings LIMIT 1;", withArgumentsIn: []) else {
				return true
			}
			defer {
				resultSet.close()
			}
			return !resultSet.next()
		}
	}

	// MARK: - Feed Existence

	func ensureFeedExists(_ feedURL: String, feedID: String) {
		serialDispatchQueue.async {
			self.database.executeUpdate("INSERT OR IGNORE INTO feedSettings (feedURL, feedID) VALUES (?, ?);", withArgumentsIn: [feedURL, feedID])
		}
	}

	// MARK: - Insert Row

	func insertRow(_ feedURL: String, _ columnValues: [Column: Any]) {
		var dictionary = DatabaseDictionary()
		dictionary["feedURL"] = feedURL
		for (column, value) in columnValues {
			dictionary[column.rawValue] = value
		}
		nonisolated(unsafe) let capturedDictionary = dictionary
		serialDispatchQueue.async {
			self.database.insertRow(capturedDictionary, insertType: .orReplace, tableName: "feedSettings")
		}
	}

	// MARK: - Fetch Rows

	func allRows() -> [String: Row] {
		serialDispatchQueue.sync {
			guard let resultSet = self.database.executeQuery("SELECT * FROM feedSettings;", withArgumentsIn: []) else {
				return [:]
			}
			defer {
				resultSet.close()
			}

			var rows = [String: Row]()
			while resultSet.next() {
				if let feedURL = resultSet.string(forColumn: "feedURL") {
					rows[feedURL] = self.row(from: resultSet)
				}
			}
			return rows
		}
	}

	// MARK: - String

	func setString(_ value: String?, for feedURL: String, column: Column) {
		let name = column.rawValue
		serialDispatchQueue.async {
			if let value {
				self.database.executeUpdate("UPDATE feedSettings SET \(name) = ? WHERE feedURL = ?;", withArgumentsIn: [value, feedURL])
			} else {
				self.database.executeUpdate("UPDATE feedSettings SET \(name) = NULL WHERE feedURL = ?;", withArgumentsIn: [feedURL])
			}
		}
	}

	// MARK: - Bool

	func setBool(_ value: Bool, for feedURL: String, column: Column) {
		let name = column.rawValue
		serialDispatchQueue.async {
			self.database.executeUpdate("UPDATE feedSettings SET \(name) = ? WHERE feedURL = ?;", withArgumentsIn: [value, feedURL])
		}
	}

	// MARK: - Date

	func setDate(_ value: Date?, for feedURL: String, column: Column) {
		let name = column.rawValue
		serialDispatchQueue.async {
			if let value {
				self.database.executeUpdate("UPDATE feedSettings SET \(name) = ? WHERE feedURL = ?;", withArgumentsIn: [value.timeIntervalSinceReferenceDate, feedURL])
			} else {
				self.database.executeUpdate("UPDATE feedSettings SET \(name) = NULL WHERE feedURL = ?;", withArgumentsIn: [feedURL])
			}
		}
	}

	// MARK: - Compound Types

	func setConditionalGetInfo(_ info: HTTPConditionalGetInfo?, for feedURL: String) {
		serialDispatchQueue.async {
			if let info {
				self.database.executeUpdate("UPDATE feedSettings SET conditionalGetInfoLastModified = ?, conditionalGetInfoEtag = ? WHERE feedURL = ?;", withArgumentsIn: [info.lastModified as Any, info.etag as Any, feedURL])
			} else {
				self.database.executeUpdate("UPDATE feedSettings SET conditionalGetInfoLastModified = NULL, conditionalGetInfoEtag = NULL WHERE feedURL = ?;", withArgumentsIn: [feedURL])
			}
		}
	}

	func setCacheControlInfo(_ info: CacheControlInfo?, for feedURL: String) {
		serialDispatchQueue.async {
			if let info {
				self.database.executeUpdate("UPDATE feedSettings SET cacheControlInfoDateCreated = ?, cacheControlInfoMaxAge = ? WHERE feedURL = ?;", withArgumentsIn: [info.dateCreated.timeIntervalSinceReferenceDate, info.maxAge, feedURL])
			} else {
				self.database.executeUpdate("UPDATE feedSettings SET cacheControlInfoDateCreated = NULL, cacheControlInfoMaxAge = NULL WHERE feedURL = ?;", withArgumentsIn: [feedURL])
			}
		}
	}

	func setAuthors(_ authors: [Author]?, for feedURL: String) {
		serialDispatchQueue.async {
			if let authors {
				let jsonString = Set(authors).json()
				self.database.executeUpdate("UPDATE feedSettings SET authors = ? WHERE feedURL = ?;", withArgumentsIn: [jsonString as Any, feedURL])
			} else {
				self.database.executeUpdate("UPDATE feedSettings SET authors = NULL WHERE feedURL = ?;", withArgumentsIn: [feedURL])
			}
		}
	}

	func setArticleFilters(_ filters: [ArticleFilter]?, for feedURL: String) {
		serialDispatchQueue.async {
			if let filters {
				if let jsonString = filters.json() {
					self.database.executeUpdate("UPDATE feedSettings SET articleFilters = ? WHERE feedURL = ?;", withArgumentsIn: [jsonString, feedURL])
				}
			} else {
				self.database.executeUpdate("UPDATE feedSettings SET articleFilters = NULL WHERE feedURL = ?;", withArgumentsIn: [feedURL])
			}
		}
	}

	func setFolderRelationship(_ relationship: [String: String]?, for feedURL: String) {
		serialDispatchQueue.async {
			if let relationship {
				if let data = try? JSONSerialization.data(withJSONObject: relationship), let jsonString = String(data: data, encoding: .utf8) {
					self.database.executeUpdate("UPDATE feedSettings SET folderRelationship = ? WHERE feedURL = ?;", withArgumentsIn: [jsonString, feedURL])
				}
			} else {
				self.database.executeUpdate("UPDATE feedSettings SET folderRelationship = NULL WHERE feedURL = ?;", withArgumentsIn: [feedURL])
			}
		}
	}

	// MARK: - Cleanup on launch

	func deleteSettingsForFeedsNotIn(_ feedURLs: Set<String>) {
		guard !feedURLs.isEmpty else {
			return
		}

		let feedURLsArray = Array(feedURLs)
		serialDispatchQueue.async {
			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedURLsArray.count))!
			let sql = "DELETE FROM feedSettings WHERE feedURL NOT IN \(placeholders);"
			self.database.executeUpdate(sql, withArgumentsIn: feedURLsArray)

			#if DEBUG
			let numberOfRowChanges: Int32 = self.database.changes()
			if numberOfRowChanges > 0 {
				Self.logger.info("FeedSettingsDatabase: deleteSettingsForFeedsNotIn: deleted \(numberOfRowChanges) orphaned feed settings")
			}
			#endif
		}
	}
}

// MARK: - Private

private extension FeedSettingsDatabase {

	static let tableCreationStatements = """
	CREATE TABLE IF NOT EXISTS feedSettings (feedURL TEXT PRIMARY KEY, feedID TEXT NOT NULL DEFAULT '', homePageURL TEXT, iconURL TEXT, faviconURL TEXT, editedName TEXT, contentHash TEXT, newArticleNotificationsEnabled INTEGER NOT NULL DEFAULT 0, readerViewAlwaysEnabled INTEGER NOT NULL DEFAULT 0, authors TEXT, conditionalGetInfoLastModified TEXT, conditionalGetInfoEtag TEXT, conditionalGetInfoDate REAL, cacheControlInfoDateCreated REAL, cacheControlInfoMaxAge REAL, externalID TEXT, folderRelationship TEXT, lastCheckDate REAL, articleFilters TEXT);
	"""

	static func addArticleFiltersColumnIfNeeded(_ database: FMDatabase) {
		if let resultSet = database.executeQuery("SELECT * FROM feedSettings LIMIT 1;", withArgumentsIn: []) {
			if let columnMap = resultSet.columnNameToIndexMap, columnMap["articlefilters"] == nil {
				database.executeStatements("ALTER TABLE feedSettings ADD COLUMN articleFilters TEXT;")
			}
			resultSet.close()
		}
	}

	func row(from resultSet: FMResultSet) -> Row {
		let lastModified = resultSet.string(forColumn: Column.conditionalGetInfoLastModified.rawValue)
		let etag = resultSet.string(forColumn: Column.conditionalGetInfoEtag.rawValue)

		var conditionalGetInfoDate: Date?
		if !resultSet.columnIsNull(Column.conditionalGetInfoDate.rawValue) {
			conditionalGetInfoDate = Date(timeIntervalSinceReferenceDate: resultSet.double(forColumn: Column.conditionalGetInfoDate.rawValue))
		}

		var cacheControlInfo: CacheControlInfo?
		if !resultSet.columnIsNull(Column.cacheControlInfoDateCreated.rawValue) && !resultSet.columnIsNull(Column.cacheControlInfoMaxAge.rawValue) {
			let dateCreated = Date(timeIntervalSinceReferenceDate: resultSet.double(forColumn: Column.cacheControlInfoDateCreated.rawValue))
			let maxAge = resultSet.double(forColumn: Column.cacheControlInfoMaxAge.rawValue)
			cacheControlInfo = CacheControlInfo(dateCreated: dateCreated, maxAge: maxAge)
		}

		var authors: [Author]?
		if let authorsJSON = resultSet.string(forColumn: Column.authors.rawValue) {
			if let authorsSet = Author.authorsWithJSON(authorsJSON) {
				authors = Array(authorsSet)
			}
		}

		var folderRelationship: [String: String]?
		if let folderJSON = resultSet.string(forColumn: Column.folderRelationship.rawValue) {
			if let data = folderJSON.data(using: .utf8) {
				folderRelationship = try? JSONSerialization.jsonObject(with: data) as? [String: String]
			}
		}

		var lastCheckDate: Date?
		if !resultSet.columnIsNull(Column.lastCheckDate.rawValue) {
			lastCheckDate = Date(timeIntervalSinceReferenceDate: resultSet.double(forColumn: Column.lastCheckDate.rawValue))
		}

		var articleFilters: [ArticleFilter]?
		if let filtersJSON = resultSet.string(forColumn: Column.articleFilters.rawValue) {
			articleFilters = [ArticleFilter].filtersWithJSON(filtersJSON)
		}

		return Row(
			feedID: resultSet.string(forColumn: Column.feedID.rawValue) ?? "",
			homePageURL: resultSet.string(forColumn: Column.homePageURL.rawValue),
			iconURL: resultSet.string(forColumn: Column.iconURL.rawValue),
			faviconURL: resultSet.string(forColumn: Column.faviconURL.rawValue),
			editedName: resultSet.string(forColumn: Column.editedName.rawValue),
			contentHash: resultSet.string(forColumn: Column.contentHash.rawValue),
			newArticleNotificationsEnabled: resultSet.bool(forColumn: Column.newArticleNotificationsEnabled.rawValue),
			readerViewAlwaysEnabled: resultSet.bool(forColumn: Column.readerViewAlwaysEnabled.rawValue),
			authors: authors,
			conditionalGetInfo: HTTPConditionalGetInfo(lastModified: lastModified, etag: etag),
			conditionalGetInfoDate: conditionalGetInfoDate,
			cacheControlInfo: cacheControlInfo,
			externalID: resultSet.string(forColumn: Column.externalID.rawValue),
			folderRelationship: folderRelationship,
			lastCheckDate: lastCheckDate,
			articleFilters: articleFilters
		)
	}
}
