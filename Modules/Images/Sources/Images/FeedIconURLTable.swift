//
//  FeedIconURLTable.swift
//  Images
//
//  Created by Brent Simmons on 5/28/26.
//

import Foundation
import RSDatabase
import RSDatabaseObjC

struct FeedIconURLTable {

	static let name = "feedIconURL"

	private struct Column {
		static let feedURL = "feedURL"
		static let iconURL = "iconURL"
		static let lastChecked = "lastChecked"
	}

	static func fetchAll(database: FMDatabase) -> [String: String] {
		var results = [String: String]()
		guard let resultSet = database.executeQuery("SELECT \(Column.feedURL), \(Column.iconURL) FROM \(name);", withArgumentsIn: []) else {
			return results
		}
		defer {
			resultSet.close()
		}
		while resultSet.next() {
			guard let feedURL = resultSet.string(forColumn: Column.feedURL),
				  let iconURL = resultSet.string(forColumn: Column.iconURL) else {
				continue
			}
			results[feedURL] = iconURL
		}
		return results
	}

	static func save(feedURL: String, iconURL: String, database: FMDatabase) {
		let dictionary: DatabaseDictionary = [
			Column.feedURL: feedURL,
			Column.iconURL: iconURL,
			Column.lastChecked: Date().timeIntervalSince1970
		]
		database.insertRow(dictionary, insertType: .orReplace, tableName: name)
	}
}
