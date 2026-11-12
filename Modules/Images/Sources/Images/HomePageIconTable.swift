//
//  HomePageIconTable.swift
//  Images
//
//  Created by Brent Simmons on 5/28/26.
//

import Foundation
import RSDatabase
import RSDatabaseObjC

/// `iconURL` is `nil` when the home page’s metadata specifies no icon.
struct HomePageIconRecord: Sendable {
	let homePageURL: String
	let iconURL: String?
	let lastChecked: Date
}

struct HomePageIconTable {

	static let name = "homePageIcon"

	private struct Column {
		static let homePageURL = "homePageURL"
		static let iconURL = "iconURL"
		static let lastChecked = "lastChecked"
	}

	static func fetchAll(database: FMDatabase) -> [HomePageIconRecord] {
		var results = [HomePageIconRecord]()
		guard let resultSet = database.executeQuery("SELECT \(Column.homePageURL), \(Column.iconURL), \(Column.lastChecked) FROM \(name);", withArgumentsIn: []) else {
			return results
		}
		defer {
			resultSet.close()
		}
		while resultSet.next() {
			guard let homePageURL = resultSet.string(forColumn: Column.homePageURL) else {
				continue
			}
			let iconURL = resultSet.string(forColumn: Column.iconURL)
			let lastChecked = Date(timeIntervalSince1970: resultSet.double(forColumn: Column.lastChecked))
			results.append(HomePageIconRecord(homePageURL: homePageURL, iconURL: iconURL, lastChecked: lastChecked))
		}
		return results
	}

	static func save(homePageURL: String, iconURL: String?, database: FMDatabase) {
		let dictionary: DatabaseDictionary = [
			Column.homePageURL: homePageURL,
			Column.iconURL: iconURL as Any,
			Column.lastChecked: Date().timeIntervalSince1970
		]
		database.insertRow(dictionary, insertType: .orReplace, tableName: name)
	}
}
