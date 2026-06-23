//
//  HomePageFaviconTable.swift
//  Images
//
//  Created by Brent Simmons on 5/28/26.
//

import Foundation
import RSDatabase
import RSDatabaseObjC

/// `faviconURL` is `nil` when the homepage has no usable favicon.
public struct HomePageFaviconRecord: Sendable {
	public let homePageURL: String
	public let faviconURL: String?
}

struct HomePageFaviconTable {

	static let name = "homePageFavicon"

	private struct Column {
		static let homePageURL = "homePageURL"
		static let faviconURL = "faviconURL"
		static let lastChecked = "lastChecked"
	}

	static func fetchAll(database: FMDatabase) -> [HomePageFaviconRecord] {
		var results = [HomePageFaviconRecord]()
		guard let resultSet = database.executeQuery("SELECT \(Column.homePageURL), \(Column.faviconURL) FROM \(name);", withArgumentsIn: []) else {
			return results
		}
		defer {
			resultSet.close()
		}
		while resultSet.next() {
			guard let homePageURL = resultSet.string(forColumn: Column.homePageURL) else {
				continue
			}
			let faviconURL = resultSet.string(forColumn: Column.faviconURL)
			results.append(HomePageFaviconRecord(homePageURL: homePageURL, faviconURL: faviconURL))
		}
		return results
	}

	static func save(homePageURL: String, faviconURL: String?, database: FMDatabase) {
		let dictionary: DatabaseDictionary = [
			Column.homePageURL: homePageURL,
			Column.faviconURL: faviconURL as Any,
			Column.lastChecked: Date().timeIntervalSince1970
		]
		database.insertRow(dictionary, insertType: .orReplace, tableName: name)
	}
}
