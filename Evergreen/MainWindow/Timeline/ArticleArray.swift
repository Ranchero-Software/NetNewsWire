//
//  ArticleArray.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/1/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Data

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

		return Set(indexes.flatMap{ (oneIndex) -> Article? in
			return articleAtRow(oneIndex)
		})
	}

	func indexesForArticleIDs(_ articleIDs: Set<String>) -> IndexSet {

		var indexes = IndexSet()

		articleIDs.forEach { (articleID) in
			let oneIndex = rowForArticleID(articleID)
			if oneIndex != NSNotFound {
				indexes.insert(oneIndex)
			}
		}

		return indexes
	}

	func sortedByDate() -> ArticleArray {

		return sorted(by: articleComparator)
	}

	func canMarkAllAsRead() -> Bool {

		for article in self {
			if !article.status.read {
				return true
			}
		}
		return false
	}
}

private extension Array where Element == Article {

	func rowForArticleID(_ articleID: String) -> Int {

		if let index = index(where: { $0.articleID == articleID }) {
			return index
		}

		return NSNotFound
	}

	func rowForArticle(_ article: Article) -> Int {

		return rowForArticleID(article.articleID)
	}

	// MARK: Sorting

	func articleComparator(_ article1: Article, article2: Article) -> Bool {

		return article1.logicalDatePublished > article2.logicalDatePublished
	}

}
