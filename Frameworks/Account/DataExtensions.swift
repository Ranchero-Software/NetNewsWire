//
//  DataExtensions.swift
//  Account
//
//  Created by Brent Simmons on 10/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Data

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

public extension Set where Element == Article {
    
    public func feeds() -> Set<Feed> {
        return Set(flatMap { $0.feed })
    }
    
    public func statuses() -> Set<ArticleStatus> {
        return Set(map { $0.articleStatus })
    }
}
