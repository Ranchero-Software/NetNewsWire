//
//  ArticleArray.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/1/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles

typealias ArticleArray = [Article]

extension Array where Element == Article {

	func articleAtRow(_ row: Int) -> Article? {

		if row < 0 || row == NSNotFound || row > count - 1 {
			return nil
		}
		return self[row]
	}

	func rowOfNextUnreadArticle(_ selectedRow: Int) -> Int? {

		if isEmpty {
			return nil
		}

		var rowIndex = selectedRow
		while(true) {

			rowIndex = rowIndex + 1
			if rowIndex >= count {
				break
			}
			let article = articleAtRow(rowIndex)!
			if !article.status.read {
				return rowIndex
			}
		}

		return nil
	}

	func articlesForIndexes(_ indexes: IndexSet) -> Set<Article> {

		return Set(indexes.compactMap{ (oneIndex) -> Article? in
			return articleAtRow(oneIndex)
		})
	}

	func sortedByDate(_ sortDirection: ComparisonResult) -> ArticleArray {

		let articles = sorted { (article1, article2) -> Bool in
			if sortDirection == .orderedDescending {
				return article1.logicalDatePublished > article2.logicalDatePublished
			}
			return article1.logicalDatePublished < article2.logicalDatePublished
		}
		
		return articles
	}

	func canMarkAllAsRead() -> Bool {

		return anyArticleIsUnread()
	}

	func anyArticlePassesTest(_ test: ((Article) -> Bool)) -> Bool {

		for article in self {
			if test(article) {
				return true
			}
		}
		return false
	}

	func anyArticleIsRead() -> Bool {

		return anyArticlePassesTest { $0.status.read }
	}

	func anyArticleIsUnread() -> Bool {

		return anyArticlePassesTest { !$0.status.read }
	}

	func anyArticleIsStarred() -> Bool {

		return anyArticlePassesTest { $0.status.starred }
	}

	func anyArticleIsUnstarred() -> Bool {

		return anyArticlePassesTest { !$0.status.starred }
	}

	func unreadArticles() -> [Article]? {

		let articles = self.filter{ !$0.status.read }
		return articles.isEmpty ? nil : articles
	}

	func representSameArticlesInSameOrder(as otherArticles: [Article]) -> Bool {
		if self.count != otherArticles.count {
			return false
		}
		var i = 0
		for article in self {
			let otherArticle = otherArticles[i]
			if article.account != otherArticle.account || article.articleID != otherArticle.articleID {
				return false
			}
			i += 1
		}
		return true
	}
}

