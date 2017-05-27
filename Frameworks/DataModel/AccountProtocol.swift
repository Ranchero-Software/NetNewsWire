//
//  AccountProtocol.swift
//  Evergreen
//
//  Created by Brent Simmons on 4/17/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol Account: class, Folder {

	var identifier: String {get}
	var type: String {get}
	var refreshInProgress: Bool {get}
	
	init(settingsFile: String, dataFolder: String, identifier: String)

	func refreshAll()

	func markArticles(_ articles: NSSet, statusKey: ArticleStatusKey, flag: Bool)

	func hasFeedWithURLString(_: String) -> Bool
	
	func importOPML(_: Any)

	func fetchArticles(for: [AnyObject]) -> [Article]
}

public extension Account {

	func hasFeedWithURLString(_ urlString: String) -> Bool {

		if let _ = existingFeedWithURL(urlString) {
			return true
		}
		return false
	}

	public func postArticleStatusesDidChangeNotification(_ articles: NSSet) {
		
		NotificationCenter.default.post(name: .ArticleStatusesDidChange, object: self, userInfo: [articlesKey: articles])
	}
}
