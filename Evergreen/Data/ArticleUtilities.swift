//
//  ArticleUtilities.swift
//  Evergreen
//
//  Created by Brent Simmons on 7/25/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Data
import Account

// These handle multiple accounts.

func markArticles(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) {
	
	let d: [String: Set<Article>] = accountAndArticlesDictionary(articles)
	
	for (accountID, accountArticles) in d {
		
		guard let account = AccountManager.shared.existingAccount(with: accountID) else {
			return
		}
		
		account.markArticles(accountArticles, statusKey: statusKey, flag: flag)
	}
}

private func accountAndArticlesDictionary(_ articles: Set<Article>) -> [String: Set<Article>] {
	
	let d = Dictionary(grouping: articles, by: { $0.accountID })
	return d.mapValues{ Set($0) }
}

extension Article {
	
	var feed: Feed? {
		get {
			return account?.existingFeed(with: feedID)
		}
	}
	
	var preferredLink: String? {
		get {
			return url ?? externalURL
		}
	}
	
	var body: String? {
		get {
			return contentHTML ?? contentText ?? summary
		}
	}
	
	var logicalDatePublished: Date {
		get {
			return datePublished ?? dateModified ?? status.dateArrived
		}
	}
}
