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
	static let WebFeedSettingDidChange = Notification.Name(rawValue: "FeedSettingDidChangeNotification")
}

public extension WebFeed {

	static let WebFeedSettingUserInfoKey = "feedSetting"

	struct WebFeedSettingKey {
		public static let homePageURL = "homePageURL"
		public static let iconURL = "iconURL"
		public static let faviconURL = "faviconURL"
		public static let name = "name"
		public static let editedName = "editedName"
		public static let authors = "authors"
		public static let contentHash = "contentHash"
		public static let conditionalGetInfo = "conditionalGetInfo"
	}
}

extension WebFeed {

	func takeSettings(from parsedFeed: ParsedFeed) {
		iconURL = parsedFeed.iconURL
		faviconURL = parsedFeed.faviconURL
		homePageURL = parsedFeed.homePageURL
		name = parsedFeed.title
		authors = Author.authorsWithParsedAuthors(parsedFeed.authors)
	}

	func postFeedSettingDidChangeNotification(_ codingKey: WebFeedMetadata.CodingKeys) {
		let userInfo = [WebFeed.WebFeedSettingUserInfoKey: codingKey.stringValue]
		NotificationCenter.default.post(name: .WebFeedSettingDidChange, object: self, userInfo: userInfo)
	}
}

public extension Article {

	var account: Account? {
		// The force unwrapped shared instance was crashing Account.framework unit tests.
		guard let manager = AccountManager.shared else {
			return nil
		}
		return manager.existingAccount(with: accountID)
	}
	
	var webFeed: WebFeed? {
		return account?.existingWebFeed(withWebFeedID: webFeedID)
	}
}

