//
//  LocalArticleCache.swift
//  Evergreen
//
//  Created by Brent Simmons on 5/9/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

final class LocalArticleCache {
	
	private var cachedArticles: NSMapTable<NSString, LocalArticle> = NSMapTable.weakToWeakObjects()
//	private var cachedArticles = [String: LocalArticle]()
//	fileprivate var articlesByFeedID = [String: Set<LocalArticle>]()
	private let statusesManager: LocalStatusesManager
	
	init(statusesManager: LocalStatusesManager) {
		
		self.statusesManager = statusesManager
	}
	
	func uniquedArticles(_ fetchedArticles: Set<LocalArticle>) -> Set<LocalArticle> {
		
		var articles = Set<LocalArticle>()
		
		for oneArticle in fetchedArticles {
			
			assert(oneArticle.status != nil)
			
			if let existingArticle = cachedArticle(oneArticle.articleID) {
				articles.insert(existingArticle)
			}
			else {
				cacheArticle(oneArticle)
				articles.insert(oneArticle)
			}
		}
		
		statusesManager.attachCachedUniqueStatuses(articles)
		
		return articles
	}
	
	func cachedArticle(_ articleID: String) -> LocalArticle? {
		
		return cachedArticles.object(forKey: articleID as NSString)
//		return cachedArticles[articleID]
	}
	
	func cacheArticle(_ article: LocalArticle) {
		
		cachedArticles.setObject(article, forKey: article.articleID as NSString)
//		cachedArticles[article.articleID] = article
//		addToCachedArticlesForFeedID(Set([article]))
	}
	
	func cacheArticles(_ articles: Set<LocalArticle>) {
		
		articles.forEach { cacheArticle($0) }
//		addToCachedArticlesForFeedID(articles)
	}
	
//	func cachedArticlesForFeedID(_ feedID: String) -> Set<LocalArticle>? {
//		
//		return articlesByFeedID[feedID]
//	}
}

//private extension LocalArticleCache {
//	
//	func addToCachedArticlesForFeedID(_ feedID: String, _ articles: Set<LocalArticle>) {
//		
//		if let cachedArticles = cachedArticlesForFeedID(feedID) {
//			replaceCachedArticlesForFeedID(feedID, cachedArticles.union(articles))
//		}
//		else {
//			replaceCachedArticlesForFeedID(feedID, articles)
//		}
//	}
//	
//	func addToCachedArticlesForFeedID(_ articles: Set<LocalArticle>) {
//		
//		for oneArticle in articles {
//			addToCachedArticlesForFeedID(oneArticle.feedID, Set([oneArticle]))
//		}
//	}
//	
//	func replaceCachedArticlesForFeedID(_ feedID: String, _ articles: Set<LocalArticle>) {
//		
//		articlesByFeedID[feedID] = articles
//	}
//	
//}
