//
//  FeedSettingsImporter.swift
//  Account
//
//  Created by Brent Simmons on 3/6/26.
//

import Foundation
import os
import Articles

/// One-time import from FeedMetadata.plist into FeedSettingsDatabase.
@MainActor struct FeedSettingsImporter {
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FeedSettingsImporter")

	static func importIfNeeded(dataFolder: String, database: FeedSettingsDatabase) {
		let plistPath = (dataFolder as NSString).appendingPathComponent("FeedMetadata.plist")
		guard FileManager.default.fileExists(atPath: plistPath) else {
			return
		}

		// If the database already has rows, import has already been done.
		guard database.isEmpty else {
			return
		}

		Self.logger.info("FeedSettingsImporter: importing FeedMetadata.plist")

		guard let data = FileManager.default.contents(atPath: plistPath) else {
			Self.logger.error("FeedSettingsImporter: unable to read FeedMetadata.plist")
			return
		}

		guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
			Self.logger.error("FeedSettingsImporter: unable to deserialize FeedMetadata.plist")
			return
		}

		// The top-level dictionary is keyed by feedURL.
		// Each value is a dictionary of feed properties (Codable-encoded).
		for (feedURL, value) in plist {
			guard let feedDict = value as? [String: Any] else {
				continue
			}
			importFeed(feedURL: feedURL, feedDict: feedDict, database: database)
		}

		Self.logger.info("FeedSettingsImporter: finished importing FeedMetadata.plist")
	}

	private static func importFeed(feedURL: String, feedDict: [String: Any], database: FeedSettingsDatabase) {
		var row = [FeedSettingsDatabase.Column: Any]()

		row[.feedID] = feedDict["feedID"] as? String ?? feedURL

		row[.homePageURL] = feedDict["homePageURL"] as? String
		row[.iconURL] = feedDict["iconURL"] as? String
		row[.faviconURL] = feedDict["faviconURL"] as? String
		row[.editedName] = feedDict["editedName"] as? String
		row[.contentHash] = feedDict["contentHash"] as? String

		// externalID is coded as "subscriptionID" in the plist
		row[.externalID] = feedDict["subscriptionID"] as? String

		if let isNotify = feedDict["isNotifyAboutNewArticles"] as? Bool {
			row[.newArticleNotificationsEnabled] = isNotify
		}
		if let isExtractor = feedDict["isArticleExtractorAlwaysOn"] as? Bool {
			row[.readerViewAlwaysEnabled] = isExtractor
		}

		// conditionalGetInfo is Codable-encoded as a dictionary with lastModified and etag
		if let conditionalGetDict = feedDict["conditionalGetInfo"] as? [String: String] {
			row[.conditionalGetInfoLastModified] = conditionalGetDict["lastModified"]
			row[.conditionalGetInfoEtag] = conditionalGetDict["etag"]
		}

		// conditionalGetInfoDate is a Date encoded by PropertyListEncoder
		if let conditionalGetInfoDate = feedDict["conditionalGetInfoDate"] as? Date {
			row[.conditionalGetInfoDate] = conditionalGetInfoDate.timeIntervalSinceReferenceDate
		}

		// cacheControlInfo is Codable-encoded as a dictionary with dateCreated and maxAge
		if let cacheDict = feedDict["cacheControlInfo"] as? [String: Any] {
			if let dateCreated = cacheDict["dateCreated"] as? Date, let maxAge = cacheDict["maxAge"] as? Double {
				row[.cacheControlInfoDateCreated] = dateCreated.timeIntervalSinceReferenceDate
				row[.cacheControlInfoMaxAge] = maxAge
			}
		}

		// authors is Codable-encoded — an array of author dictionaries
		// Re-encode as JSON for storage
		if let authorsArray = feedDict["authors"] as? [[String: Any]] {
			if let authorsData = try? JSONSerialization.data(withJSONObject: authorsArray) {
				if let authors = try? JSONDecoder().decode([Author].self, from: authorsData) {
					row[.authors] = Set(authors).json()
				}
			}
		}

		// folderRelationship is [String: String]
		if let folderRelationship = feedDict["folderRelationship"] as? [String: String] {
			if let data = try? JSONSerialization.data(withJSONObject: folderRelationship), let jsonString = String(data: data, encoding: .utf8) {
				row[.folderRelationship] = jsonString
			}
		}

		// lastCheckDate is a Date encoded by PropertyListEncoder
		if let lastCheckDate = feedDict["lastCheckDate"] as? Date {
			row[.lastCheckDate] = lastCheckDate.timeIntervalSinceReferenceDate
		}

		database.insertRow(feedURL, row)
	}
}
