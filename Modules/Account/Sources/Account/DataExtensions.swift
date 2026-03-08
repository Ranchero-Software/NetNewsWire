//
//  DataExtensions.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import RSParser

public extension Notification.Name {
	static let feedSettingDidChange = Notification.Name(rawValue: "FeedSettingDidChangeNotification")
}

public extension Feed {
	static let SettingUserInfoKey = "feedSetting"

	enum SettingKey {
		case feedID
		case homePageURL
		case iconURL
		case faviconURL
		case editedName
		case authors
		case contentHash
		case newArticleNotificationsEnabled
		case readerViewAlwaysEnabled
		case conditionalGetInfo
		case conditionalGetInfoDate
		case cacheControlInfo
		case externalID
		case folderRelationship
		case lastCheckDate
	}
}

extension Feed {

	@MainActor func takeSettings(from parsedFeed: ParsedFeed) {
		iconURL = parsedFeed.iconURL
		faviconURL = parsedFeed.faviconURL
		homePageURL = parsedFeed.homePageURL
		name = parsedFeed.title
		authors = Author.authorsWithParsedAuthors(parsedFeed.authors)
	}

	func postFeedSettingDidChangeNotification(_ key: Feed.SettingKey) {
		let userInfo: [String: Feed.SettingKey] = [Feed.SettingUserInfoKey: key]
		NotificationCenter.default.post(name: .feedSettingDidChange, object: self, userInfo: userInfo)
	}
}

public extension Article {
	@MainActor var account: Account? {
		return AccountManager.shared.existingAccount(accountID: accountID)
	}

	@MainActor var feed: Feed? {
		return account?.existingFeed(withFeedID: feedID)
	}
}
