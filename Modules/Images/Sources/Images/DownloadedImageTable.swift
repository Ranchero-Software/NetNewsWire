//
//  DownloadedImageTable.swift
//  Images
//
//  Created by Brent Simmons on 10/26/26.
//

import Foundation
import RSCore
import RSWeb
import RSDatabase
import RSDatabaseObjC

/// A copy stored by `DownloadedImageCache`. `pixelSize` is nil when ImageIO can’t read the image.
struct DownloadedImageRecord: Sendable {
	let url: String
	let pixelSize: (width: Int, height: Int)?
	let conditionalGetInfo: HTTPConditionalGetInfo?
	let nextCheck: Date
}

/// What `DownloadedImageCache` needs to check with the server whether a copy is current.
struct DownloadedImageValidation: Sendable {
	let nextCheck: Date
	let conditionalGetInfo: HTTPConditionalGetInfo?
}

/// What `DownloadedImageCache` needs to choose images to remove.
struct DownloadedImageUsage: Sendable {
	let url: String
	let lastAccessed: Date
}

/// One row per copy stored by `DownloadedImageCache`.
struct DownloadedImageTable {

	static let name = "downloadedImage"

	private struct Column {
		static let url = "url"
		static let pixelWidth = "pixelWidth"
		static let pixelHeight = "pixelHeight"
		static let lastAccessed = "lastAccessed"
		static let etag = "etag"
		static let lastModified = "lastModified"
		static let nextCheck = "nextCheck"
	}

	/// Keeps each query under the database’s limit on parameters.
	private static let maximumURLsPerQuery = 500

	/// Every row’s URL and pixel size. `pixelSize` is nil when ImageIO couldn’t read the image.
	static func fetchPixelSizes(database: FMDatabase) -> [(url: String, pixelSize: (width: Int, height: Int)?)] {
		var results = [(url: String, pixelSize: (width: Int, height: Int)?)]()
		guard let resultSet = database.executeQuery("SELECT \(Column.url), \(Column.pixelWidth), \(Column.pixelHeight) FROM \(name);", withArgumentsIn: []) else {
			return results
		}
		defer {
			resultSet.close()
		}
		while resultSet.next() {
			guard let url = resultSet.string(forColumn: Column.url) else {
				continue
			}
			var pixelSize: (width: Int, height: Int)?
			if !resultSet.columnIsNull(Column.pixelWidth) && !resultSet.columnIsNull(Column.pixelHeight) {
				pixelSize = (width: resultSet.long(forColumn: Column.pixelWidth), height: resultSet.long(forColumn: Column.pixelHeight))
			}
			results.append((url: url, pixelSize: pixelSize))
		}
		return results
	}

	/// Least recently accessed first. Nil when the query fails.
	static func fetchUsageByLeastRecentAccess(database: FMDatabase) -> [DownloadedImageUsage]? {
		var results = [DownloadedImageUsage]()
		guard let resultSet = database.executeQuery("SELECT \(Column.url), \(Column.lastAccessed) FROM \(name) ORDER BY \(Column.lastAccessed);", withArgumentsIn: []) else {
			return nil
		}
		defer {
			resultSet.close()
		}
		while resultSet.next() {
			guard let url = resultSet.string(forColumn: Column.url) else {
				continue
			}
			let lastAccessed = Date(timeIntervalSince1970: resultSet.double(forColumn: Column.lastAccessed))
			results.append(DownloadedImageUsage(url: url, lastAccessed: lastAccessed))
		}
		return results
	}

	static func fetchValidation(url: String, database: FMDatabase) -> DownloadedImageValidation? {
		guard let resultSet = database.selectRowsWhere(key: Column.url, equalsAnyValue: [url], tableName: name) else {
			return nil
		}
		defer {
			resultSet.close()
		}
		guard resultSet.next() else {
			return nil
		}
		let nextCheck = Date(timeIntervalSince1970: resultSet.double(forColumn: Column.nextCheck))
		let conditionalGetInfo = HTTPConditionalGetInfo(lastModified: resultSet.string(forColumn: Column.lastModified), etag: resultSet.string(forColumn: Column.etag))
		return DownloadedImageValidation(nextCheck: nextCheck, conditionalGetInfo: conditionalGetInfo)
	}

	static func saveNextCheck(url: String, nextCheck: Date, database: FMDatabase) {
		database.updateRowsWithValue(nextCheck.timeIntervalSince1970, valueKey: Column.nextCheck, whereKey: Column.url, equals: url, tableName: name)
	}

	static func saveAccessDate(url: String, database: FMDatabase) {
		database.updateRowsWithValue(Date().timeIntervalSince1970, valueKey: Column.lastAccessed, whereKey: Column.url, equals: url, tableName: name)
	}

	static func delete(urls: [String], database: FMDatabase) {
		for urlsChunk in urls.chunked(into: maximumURLsPerQuery) {
			database.deleteRowsWhere(key: Column.url, equalsAnyValue: urlsChunk, tableName: name)
		}
	}

	static func save(_ record: DownloadedImageRecord, database: FMDatabase) {
		let dictionary: DatabaseDictionary = [
			Column.url: record.url,
			Column.pixelWidth: record.pixelSize?.width as Any,
			Column.pixelHeight: record.pixelSize?.height as Any,
			Column.lastAccessed: Date().timeIntervalSince1970,
			Column.etag: record.conditionalGetInfo?.etag as Any,
			Column.lastModified: record.conditionalGetInfo?.lastModified as Any,
			Column.nextCheck: record.nextCheck.timeIntervalSince1970
		]
		database.insertRow(dictionary, insertType: .orReplace, tableName: name)
	}
}
