//
//  DownloadFailureTable.swift
//  Images
//
//  Created by Brent Simmons on 5/28/26.
//

import Foundation
import RSDatabase
import RSDatabaseObjC

/// Per-URL download-failure tracking.
struct DownloadFailureTable {

	static let name = "downloadFailure"

	private struct Column {
		static let url = "url"
		static let lastChecked = "lastChecked"
		static let statusCode = "statusCode"
	}

	/// Returns all failures as `url : lastFailureDate`.
	static func fetchAll(database: FMDatabase) -> [String: Date] {
		var results = [String: Date]()
		guard let resultSet = database.executeQuery("SELECT \(Column.url), \(Column.lastChecked) FROM \(name);", withArgumentsIn: []) else {
			return results
		}
		defer {
			resultSet.close()
		}
		while resultSet.next() {
			guard let url = resultSet.string(forColumn: Column.url) else {
				continue
			}
			let lastChecked = Date(timeIntervalSince1970: resultSet.double(forColumn: Column.lastChecked))
			results[url] = lastChecked
		}
		return results
	}

	static func save(url: String, statusCode: Int?, database: FMDatabase) {
		let dictionary: DatabaseDictionary = [
			Column.url: url,
			Column.lastChecked: Date().timeIntervalSince1970,
			Column.statusCode: statusCode as Any
		]
		database.insertRow(dictionary, insertType: .orReplace, tableName: name)
	}

	static func clear(url: String, database: FMDatabase) {
		database.deleteRowsWhere(key: Column.url, equals: url, tableName: name)
	}

	/// Removes rows whose `lastChecked` predates the cutoff. Cutoff is Unix epoch seconds.
	static func removeExpired(olderThan cutoff: TimeInterval, database: FMDatabase) {
		let sql = "DELETE FROM \(name) WHERE \(Column.lastChecked) < ?;"
		database.executeUpdate(sql, withArgumentsIn: [cutoff])
	}
}
