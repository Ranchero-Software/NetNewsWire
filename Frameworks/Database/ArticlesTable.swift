//
//  ArticlesTable.swift
//  Evergreen
//
//  Created by Brent Simmons on 5/9/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Data

final class ArticlesTable: DatabaseTable {

	let name: String

	init(name: String) {

		self.name = name
	}
	
	private let cachedArticles: NSMapTable<NSString, Article> = NSMapTable.weakToWeakObjects()
	
	func uniquedArticles(_ fetchedArticles: Set<Article>, statusesManager: StatusesManager) -> Set<Article> {
		
		var articles = Set<Article>()
		
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
		
		statusesManager.attachCachedStatuses(articles)
		
		return articles
	}
	
	func cachedArticle(_ articleID: String) -> Article? {
		
		return cachedArticles.object(forKey: articleID as NSString)
	}
	
	func cacheArticle(_ article: Article) {
		
		cachedArticles.setObject(article, forKey: article.articleID as NSString)
	}
	
	func cacheArticles(_ articles: Set<Article>) {
		
		articles.forEach { cacheArticle($0) }
	}
}
