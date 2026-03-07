//
//  FeedSettings.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/7/26
//

import Foundation
import RSWeb
import Articles

@MainActor final class FeedSettings {
	private let feedURL: String
	let feedID: String
	private let database: FeedSettingsDatabase
	weak var feed: Feed?

	var homePageURL: String? {
		didSet {
			if homePageURL != oldValue {
				database.setString(homePageURL, for: feedURL, column: .homePageURL)
				postSettingDidChange(.homePageURL)
			}
		}
	}

	var iconURL: String? {
		didSet {
			if iconURL != oldValue {
				database.setString(iconURL, for: feedURL, column: .iconURL)
				postSettingDidChange(.iconURL)
			}
		}
	}

	var faviconURL: String? {
		didSet {
			if faviconURL != oldValue {
				database.setString(faviconURL, for: feedURL, column: .faviconURL)
				postSettingDidChange(.faviconURL)
			}
		}
	}

	var editedName: String? {
		didSet {
			if editedName != oldValue {
				database.setString(editedName, for: feedURL, column: .editedName)
				postSettingDidChange(.editedName)
			}
		}
	}

	var contentHash: String? {
		didSet {
			if contentHash != oldValue {
				database.setString(contentHash, for: feedURL, column: .contentHash)
				postSettingDidChange(.contentHash)
			}
		}
	}

	var newArticleNotificationsEnabled = false {
		didSet {
			if newArticleNotificationsEnabled != oldValue {
				database.setBool(newArticleNotificationsEnabled, for: feedURL, column: .newArticleNotificationsEnabled)
				postSettingDidChange(.newArticleNotificationsEnabled)
			}
		}
	}

	var readerViewAlwaysEnabled = false {
		didSet {
			if readerViewAlwaysEnabled != oldValue {
				database.setBool(readerViewAlwaysEnabled, for: feedURL, column: .readerViewAlwaysEnabled)
				postSettingDidChange(.readerViewAlwaysEnabled)
			}
		}
	}

	var authors: [Author]? {
		didSet {
			if authors != oldValue {
				database.setAuthors(authors, for: feedURL)
				postSettingDidChange(.authors)
			}
		}
	}

	var conditionalGetInfo: HTTPConditionalGetInfo? {
		didSet {
			if conditionalGetInfo != oldValue {
				database.setConditionalGetInfo(conditionalGetInfo, for: feedURL)
				postSettingDidChange(.conditionalGetInfo)
				if conditionalGetInfo == nil {
					conditionalGetInfoDate = nil
				} else {
					conditionalGetInfoDate = Date()
				}
			}
		}
	}

	var conditionalGetInfoDate: Date? {
		didSet {
			if conditionalGetInfoDate != oldValue {
				database.setDate(conditionalGetInfoDate, for: feedURL, column: .conditionalGetInfoDate)
				postSettingDidChange(.conditionalGetInfoDate)
			}
		}
	}

	var cacheControlInfo: CacheControlInfo? {
		didSet {
			if cacheControlInfo != oldValue {
				database.setCacheControlInfo(cacheControlInfo, for: feedURL)
				postSettingDidChange(.cacheControlInfo)
			}
		}
	}

	var externalID: String? {
		didSet {
			if externalID != oldValue {
				database.setString(externalID, for: feedURL, column: .externalID)
				postSettingDidChange(.externalID)
			}
		}
	}

	// Folder Name: Sync Service Relationship ID
	var folderRelationship: [String: String]? {
		didSet {
			if folderRelationship != oldValue {
				database.setFolderRelationship(folderRelationship, for: feedURL)
				postSettingDidChange(.folderRelationship)
			}
		}
	}

	/// Last time an attempt was made to read the feed.
	/// (Not necessarily a successful attempt.)
	var lastCheckDate: Date? {
		didSet {
			if lastCheckDate != oldValue {
				database.setDate(lastCheckDate, for: feedURL, column: .lastCheckDate)
				postSettingDidChange(.lastCheckDate)
			}
		}
	}

	/// Create from database row (bulk load at startup).
	init(feedURL: String, row: FeedSettingsDatabase.Row, database: FeedSettingsDatabase) {
		self.feedURL = feedURL
		self.database = database
		self.feedID = row.feedID
		self.homePageURL = row.homePageURL
		self.iconURL = row.iconURL
		self.faviconURL = row.faviconURL
		self.editedName = row.editedName
		self.contentHash = row.contentHash
		self.newArticleNotificationsEnabled = row.newArticleNotificationsEnabled
		self.readerViewAlwaysEnabled = row.readerViewAlwaysEnabled
		self.authors = row.authors
		self.conditionalGetInfo = row.conditionalGetInfo
		self.conditionalGetInfoDate = row.conditionalGetInfoDate
		self.cacheControlInfo = row.cacheControlInfo
		self.externalID = row.externalID
		self.folderRelationship = row.folderRelationship
		self.lastCheckDate = row.lastCheckDate
	}

	/// Create for a new feed not yet in the database.
	init(feedURL: String, feedID: String, database: FeedSettingsDatabase) {
		self.feedURL = feedURL
		self.database = database
		self.feedID = feedID
		database.ensureFeedExists(feedURL, feedID: feedID)
	}

	private func postSettingDidChange(_ key: Feed.SettingKey) {
		feed?.postFeedSettingDidChangeNotification(key)
	}
}
