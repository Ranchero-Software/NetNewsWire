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

func markArticles(_ articles: Set<Article>, statusKey: String, flag: Bool) {
	
	let d: [String: Set<Article>] = accountAndArticlesDictionary(articles)
	
	d.keys.forEach { (accountID) in
		
		guard let accountArticles = d[accountID], let account = accountWithID(accountID) else {
			return
		}
		
		account.markArticles(accountArticles, statusKey: statusKey, flag: flag)
	}
}

private func accountAndArticlesDictionary(_ articles: Set<Article>) -> [String: Set<Article>] {
    
    var d = [String: Set<Article>]()
	
	articles.forEach { (article) in

		let accountID = article.accountID
		var articleSet: Set<Article> = d[accountID] ?? Set<Article>()
		articleSet.insert(article)
		d[accountID] = articleSet
	}

    return d
}

extension Article {
	
	var feed: Feed? {
		get {
			return account?.existingFeed(with: feedID)
		}
	}
	
	var status: ArticleStatus? {
		get {
			guard let status = account?.articleStatus(for: self) else {
				assertionFailure("Expected ArticleStatus for article.status.")
				return nil
			}
			return status
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
			return datePublished ?? dateModified ?? status?.dateArrived ?? Date.distantPast
		}
	}
	
	var read: Bool {
		get {
			if let status = status {
				return status.read
			}
			return false
		}
	}
}
