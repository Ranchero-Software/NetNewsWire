//
//  ArticleThumbnailTable.swift
//  Images
//
//  Created by Brent Simmons on 10/25/26.
//

import Foundation
import RSCore
import RSDatabase
import RSDatabaseObjC

/// The result of looking for a thumbnail in an article’s HTML.
/// `thumbnailURL` is nil when the HTML has no usable image.
struct ArticleThumbnailRecord: Sendable, Equatable {
	let articleID: String
	let thumbnailURL: String?
}

/// Thumbnails found in article HTML. Rows exist only for articles whose HTML was parsed.
struct ArticleThumbnailTable {

	static let name = "articleThumbnail"

	private struct Column {
		static let articleID = "articleID"
		static let thumbnailURL = "thumbnailURL"
		static let lastChecked = "lastChecked"
	}

	/// Keeps each query under the database’s limit on parameters.
	private static let maximumArticleIDsPerQuery = 500

	static func fetch(articleIDs: [String], database: FMDatabase) -> [ArticleThumbnailRecord] {
		var results = [ArticleThumbnailRecord]()
		for articleIDsChunk in articleIDs.chunked(into: maximumArticleIDsPerQuery) {
			guard let resultSet = database.selectRowsWhere(key: Column.articleID, equalsAnyValue: articleIDsChunk, tableName: name) else {
				continue
			}
			while resultSet.next() {
				guard let articleID = resultSet.string(forColumn: Column.articleID) else {
					continue
				}
				results.append(ArticleThumbnailRecord(articleID: articleID, thumbnailURL: resultSet.string(forColumn: Column.thumbnailURL)))
			}
			resultSet.close()
		}
		return results
	}

	static func save(_ records: [ArticleThumbnailRecord], database: FMDatabase) {
		let lastChecked = Date().timeIntervalSince1970
		for record in records {
			let dictionary: DatabaseDictionary = [
				Column.articleID: record.articleID,
				Column.thumbnailURL: record.thumbnailURL as Any,
				Column.lastChecked: lastChecked
			]
			database.insertRow(dictionary, insertType: .orReplace, tableName: name)
		}
	}

	/// Removes rows whose `lastChecked` predates the cutoff. Cutoff is Unix epoch seconds.
	static func removeExpired(olderThan cutoff: TimeInterval, database: FMDatabase) {
		let sql = "DELETE FROM \(name) WHERE \(Column.lastChecked) < ?;"
		database.executeUpdate(sql, withArgumentsIn: [cutoff])
	}
}
