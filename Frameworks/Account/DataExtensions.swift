//
//  DataExtensions.swift
//  Account
//
//  Created by Brent Simmons on 10/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import RSParser

public extension Notification.Name {
	static let FeedSettingDidChange = Notification.Name(rawValue: "FeedSettingDidChangeNotification")
}

public extension Feed {

	public static let FeedSettingUserInfoKey = "feedSetting"

	public struct FeedSettingKey {
		static let homePageURL = "homePageURL"
		static let iconURL = "iconURL"
		static let faviconURL = "faviconURL"
		static let name = "name"
		static let editedName = "editedName"
		static let authors = "authors"
		static let contentHash = "contentHash"
		static let conditionalGetInfo = "conditionalGetInfo"
	}
}

extension Feed {

	func takeSettings(from parsedFeed: ParsedFeed) {
		iconURL = parsedFeed.iconURL
		faviconURL = parsedFeed.faviconURL
		homePageURL = parsedFeed.homePageURL
		name = parsedFeed.title
		authors = Author.authorsWithParsedAuthors(parsedFeed.authors)
	}

	func postFeedSettingDidChangeNotification(_ codingKey: FeedMetadata.CodingKeys) {
		let userInfo = [Feed.FeedSettingUserInfoKey: codingKey.stringValue]
		NotificationCenter.default.post(name: .FeedSettingDidChange, object: self, userInfo: userInfo)
	}
}

public extension Article {

	var account: Account? {
		return AccountManager.shared.existingAccount(with: accountID)
	}
	
	var feed: Feed? {
		return account?.existingFeed(with: feedID)
	}
}

