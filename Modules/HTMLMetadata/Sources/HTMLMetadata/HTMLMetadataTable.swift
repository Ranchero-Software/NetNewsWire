//
//  HTMLMetadataTable.swift
//  HTMLMetadata
//
//  Created by Brent Simmons on 4/6/26.
//

import Foundation
import RSDatabase
import RSDatabaseObjC

struct HTMLMetadataTable {

	static let name = "metadata"

	private struct Column {
		static let url = "url"
		static let lastChecked = "lastChecked"
		static let lastStatusCode = "lastStatusCode"
		static let favicons = "favicons"
		static let appleTouchIcons = "appleTouchIcons"
		static let feedLinks = "feedLinks"
		static let openGraphImages = "openGraphImages"
		static let twitterImageURL = "twitterImageURL"
	}

	static func insertOrReplace(record: HTMLMetadataRecord, statusCode: Int, database: FMDatabase) {
		let dictionary: DatabaseDictionary = [
			Column.url: record.url,
			Column.lastChecked: Date().timeIntervalSince1970,
			Column.lastStatusCode: statusCode,
			Column.favicons: jsonString(record.favicons) as Any,
			Column.appleTouchIcons: jsonString(record.appleTouchIcons) as Any,
			Column.feedLinks: jsonString(record.feedLinks) as Any,
			Column.openGraphImages: jsonString(record.openGraphImages) as Any,
			Column.twitterImageURL: record.twitterImageURL as Any
		]
		database.insertRow(dictionary, insertType: .orReplace, tableName: name)
	}

	static func fetchRecordAndLastCheckedDate(url: String, database: FMDatabase) -> (record: HTMLMetadataRecord, lastChecked: Date, statusCode: Int)? {
		guard let resultSet = database.rs_selectSingleRowWhereKey(Column.url, equalsValue: url, tableName: name) else {
			return nil
		}
		defer {
			resultSet.close()
		}

		guard let record = record(from: resultSet) else {
			return nil
		}

		let lastChecked = Date(timeIntervalSince1970: resultSet.double(forColumn: Column.lastChecked))
		let statusCode = resultSet.long(forColumn: Column.lastStatusCode)
		return (record, lastChecked, statusCode)
	}

	/// Records a 4xx outcome for a URL: inserts a failure marker, or updates an
	/// existing failure row's status and date. The `WHERE` guard preserves rows
	/// that hold a successful (2xx) fetch, so a transient 4xx never erases good
	/// cached metadata.
	static func noteFailure(url: String, statusCode: Int, database: FMDatabase) {
		let sql = "INSERT INTO \(name) (\(Column.url), \(Column.lastChecked), \(Column.lastStatusCode)) VALUES (?, ?, ?) ON CONFLICT(\(Column.url)) DO UPDATE SET \(Column.lastChecked) = excluded.\(Column.lastChecked), \(Column.lastStatusCode) = excluded.\(Column.lastStatusCode) WHERE \(Column.lastStatusCode) >= 400;"
		database.executeUpdate(sql, withArgumentsIn: [url, Date().timeIntervalSince1970, statusCode])
	}

	static func removeExpired(olderThan cutoff: TimeInterval, database: FMDatabase) {
		let sql = "DELETE FROM \(name) WHERE \(Column.lastChecked) < ?;"
		database.executeUpdate(sql, withArgumentsIn: [cutoff])
	}
}

// MARK: - Private

private extension HTMLMetadataTable {

	static func record(from row: FMResultSet) -> HTMLMetadataRecord? {
		guard let url = row.string(forColumn: Column.url) else {
			return nil
		}

		let favicons: [HTMLMetadataRecord.Favicon] =
			decoded(row.string(forColumn: Column.favicons)) ?? []
		let appleTouchIcons: [HTMLMetadataRecord.AppleTouchIcon] =
			decoded(row.string(forColumn: Column.appleTouchIcons)) ?? []
		let feedLinks: [HTMLMetadataRecord.FeedLink] =
			decoded(row.string(forColumn: Column.feedLinks)) ?? []
		let openGraphImages: [HTMLMetadataRecord.OpenGraphImage] =
			decoded(row.string(forColumn: Column.openGraphImages)) ?? []
		let twitterImageURL = row.string(forColumn: Column.twitterImageURL)

		return HTMLMetadataRecord(
			url: url,
			favicons: favicons,
			appleTouchIcons: appleTouchIcons,
			feedLinks: feedLinks,
			openGraphImages: openGraphImages,
			twitterImageURL: twitterImageURL
		)
	}

	static func jsonString<T: Encodable>(_ value: T) -> String? {
		guard let data = try? JSONEncoder().encode(value) else {
			return nil
		}
		return String(data: data, encoding: .utf8)
	}

	static func decoded<T: Decodable>(_ jsonString: String?) -> T? {
		guard let jsonString, let data = jsonString.data(using: .utf8) else {
			return nil
		}
		return try? JSONDecoder().decode(T.self, from: data)
	}
}
