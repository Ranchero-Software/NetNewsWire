//
//  DownloadedImageTable.swift
//  Images
//
//  Created by Brent Simmons on 10/26/26.
//

import Foundation
import RSWeb
import RSDatabase
import RSDatabaseObjC

/// A copy stored by `DownloadedImageCache`. `pixelSize` is nil when ImageIO can’t read the image.
struct DownloadedImageRecord: Sendable {
	let url: String
	let byteCount: Int
	let pixelSize: (width: Int, height: Int)?
	let conditionalGetInfo: HTTPConditionalGetInfo?
}

/// One row per copy stored by `DownloadedImageCache`.
struct DownloadedImageTable {

	static let name = "downloadedImage"

	private struct Column {
		static let url = "url"
		static let byteCount = "byteCount"
		static let pixelWidth = "pixelWidth"
		static let pixelHeight = "pixelHeight"
		static let lastAccessed = "lastAccessed"
		static let etag = "etag"
		static let lastModified = "lastModified"
	}

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

	static func save(_ record: DownloadedImageRecord, database: FMDatabase) {
		let dictionary: DatabaseDictionary = [
			Column.url: record.url,
			Column.byteCount: record.byteCount,
			Column.pixelWidth: record.pixelSize?.width as Any,
			Column.pixelHeight: record.pixelSize?.height as Any,
			Column.lastAccessed: Date().timeIntervalSince1970,
			Column.etag: record.conditionalGetInfo?.etag as Any,
			Column.lastModified: record.conditionalGetInfo?.lastModified as Any
		]
		database.insertRow(dictionary, insertType: .orReplace, tableName: name)
	}
}
