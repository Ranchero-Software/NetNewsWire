//
//  DataExtensions.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import RSCore
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
		case lastResponseCode
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

	/// The URL that relative URLs in the article’s HTML resolve against: the article’s link,
	/// else the feed’s home page, else the feed. Nil unless http or https.
	@MainActor var baseURL: URL? {
		guard let urlString = URL.encodeSpacesIfNeeded(rawLink)?.absoluteString ?? rawLink ?? feed?.homePageURL ?? feed?.url, var urlComponents = URLComponents(string: urlString) else {
			return nil
		}

		// Can’t use url-with-fragment as base URL. The webview won’t load. See scripting.com/rss.xml for example.
		urlComponents.fragment = nil
		guard let url = urlComponents.url, url.scheme == "http" || url.scheme == "https" else {
			return nil
		}
		return url
	}
}
