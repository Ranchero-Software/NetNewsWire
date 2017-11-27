//
//  DataExtensions.swift
//  Account
//
//  Created by Brent Simmons on 10/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Data
import RSParser

public extension Notification.Name {

	public static let FeedSettingDidChange = Notification.Name(rawValue: "FeedSettingDidChangeNotification")
}

public extension Feed {

	public var account: Account? {
		get {
			return AccountManager.shared.existingAccount(with: accountID)
		}
	}
	
	public func fetchArticles() -> Set<Article> {
	
		guard let account = account else {
			assertionFailure("Expected feed.account.")
			return Set<Article>()
		}
		return account.fetchArticles(for: self)
	}

	public func takeSettings(from parsedFeed: ParsedFeed) {

		var didChangeAtLeastOneSetting = false

		if iconURL != parsedFeed.iconURL {
			iconURL = parsedFeed.iconURL
			didChangeAtLeastOneSetting = true
		}
		if faviconURL != parsedFeed.faviconURL {
			faviconURL = parsedFeed.faviconURL
			didChangeAtLeastOneSetting = true
		}
		if homePageURL != parsedFeed.homePageURL {
			homePageURL = parsedFeed.homePageURL
			didChangeAtLeastOneSetting = true
		}
		if name != parsedFeed.title {
			name = parsedFeed.title
			didChangeAtLeastOneSetting = true
		}

		if didChangeAtLeastOneSetting {
			NotificationCenter.default.post(name: .FeedSettingDidChange, object: self)
		}
	}
}

public extension Article {

	public var account: Account? {
		get {
			return AccountManager.shared.existingAccount(with: accountID)
		}
	}
	
	public var feed: Feed? {
		get {
			return account?.existingFeed(with: feedID)
		}
	}
}

