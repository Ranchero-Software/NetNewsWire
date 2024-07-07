//
//  SearchTable.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Database
import Articles
import Parser
import FMDB

final class ArticleSearchInfo: Hashable {

	let articleID: String
	let title: String?
	let contentHTML: String?
	let contentText: String?
	let summary: String?
	let authorsNames: String?
	let searchRowID: Int?
	
	var preferredText: String {
		if let body = contentHTML, !body.isEmpty {
			return body
		}
		if let body = contentText, !body.isEmpty {
			return body
		}
		return summary ?? ""
	}

	lazy var bodyForIndex: String = {
		let s = preferredText.rsparser_stringByDecodingHTMLEntities()
		let sanitizedBody = s.strippingHTML().collapsingWhitespace

		if let authorsNames = authorsNames {
			return sanitizedBody.appending(" \(authorsNames)")
		} else {
			return sanitizedBody
		}
	}()

	init(articleID: String, title: String?, contentHTML: String?, contentText: String?, summary: String?, authorsNames: String?, searchRowID: Int?) {
		self.articleID = articleID
		self.title = title
		self.authorsNames = authorsNames
		self.contentHTML = contentHTML
		self.contentText = contentText
		self.summary = summary
		self.searchRowID = searchRowID
	}

	convenience init(article: Article) {
		let authorsNames: String?
		if let authors = article.authors {
			authorsNames = authors.compactMap({ $0.name }).joined(separator: " ")
		} else {
			authorsNames = nil
		}
		self.init(articleID: article.articleID, title: article.title, contentHTML: article.contentHTML, contentText: article.contentText, summary: article.summary, authorsNames: authorsNames, searchRowID: nil)
	}

	// MARK: Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(articleID)
	}

	// MARK: Equatable

	static func == (lhs: ArticleSearchInfo, rhs: ArticleSearchInfo) -> Bool {
		return lhs.articleID == rhs.articleID && lhs.title == rhs.title && lhs.contentHTML == rhs.contentHTML && lhs.contentText == rhs.contentText && lhs.summary == rhs.summary && lhs.authorsNames == rhs.authorsNames && lhs.searchRowID == rhs.searchRowID
	}
}

final class SearchTable {

	let name = DatabaseTableName.search

	/// Add to, or update, the search index for articles with specified IDs.
	func ensureIndexedArticles(articleIDs: Set<String>, database: FMDatabase) {

		guard let articleSearchInfos = fetchArticleSearchInfos(articleIDs: articleIDs, database: database) else {
			return
		}

		let unindexedArticles = articleSearchInfos.filter { $0.searchRowID == nil }
		performInitialIndexForArticles(unindexedArticles, database)

		let indexedArticles = articleSearchInfos.filter { $0.searchRowID != nil }
		updateIndexForArticles(indexedArticles, database)
	}

	/// Index new articles.
	func indexNewArticles(_ articles: Set<Article>, _ database: FMDatabase) {

		let articleSearchInfos = Set(articles.map{ ArticleSearchInfo(article: $0) })
		performInitialIndexForArticles(articleSearchInfos, database)
	}

	/// Index updated articles.
	func indexUpdatedArticles(_ articles: Set<Article>, _ database: FMDatabase) {

		ensureIndexedArticles(articleIDs: articles.articleIDs(), database: database)
	}
}

// MARK: - Private

private extension SearchTable {

	func performInitialIndexForArticles(_ articles: Set<ArticleSearchInfo>, _ database: FMDatabase) {

		for article in articles {
			performInitialIndex(article, database)
		}
	}

	func performInitialIndex(_ article: ArticleSearchInfo, _ database: FMDatabase) {
		
		let rowid = insert(article, database)
		database.updateRowsWithValue(rowid, valueKey: DatabaseKey.searchRowID, whereKey: DatabaseKey.articleID, equals: article.articleID, tableName: DatabaseTableName.articles)
	}

	func insert(_ article: ArticleSearchInfo, _ database: FMDatabase) -> Int {

		let rowDictionary: DatabaseDictionary = [DatabaseKey.body: article.bodyForIndex, DatabaseKey.title: article.title ?? ""]
		database.insertRow(rowDictionary, insertType: .normal, tableName: name)
		return Int(database.lastInsertRowId())
	}

	private struct SearchInfo: Hashable {
		let rowID: Int
		let title: String
		let body: String

		init(row: FMResultSet) {
			self.rowID = Int(row.longLongInt(forColumn: DatabaseKey.rowID))
			self.title = row.string(forColumn: DatabaseKey.title) ?? ""
			self.body = row.string(forColumn: DatabaseKey.body) ?? ""
		}

		// MARK: Hashable

		public func hash(into hasher: inout Hasher) {
			hasher.combine(rowID)
		}
	}

	func updateIndexForArticles(_ articles: Set<ArticleSearchInfo>, _ database: FMDatabase) {
		if articles.isEmpty {
			return
		}
		guard let searchInfos = fetchSearchInfos(articles, database) else {
			// The articles that get here have a non-nil searchRowID, and we should have found rows in the search table for them.
			// But we didn’t. Recover by doing an initial index.
			performInitialIndexForArticles(articles, database)
			return
		}
		let groupedSearchInfos = Dictionary(grouping: searchInfos, by: { $0.rowID })
		let searchInfosDictionary = groupedSearchInfos.mapValues { $0.first! }

		for article in articles {
			updateIndexForArticle(article, searchInfosDictionary, database)
		}
	}

	private func updateIndexForArticle(_ article: ArticleSearchInfo, _ searchInfosDictionary: [Int: SearchInfo], _ database: FMDatabase) {
		guard let searchRowID = article.searchRowID else {
			assertionFailure("Expected article.searchRowID, got nil")
			return
		}
		guard let searchInfo: SearchInfo = searchInfosDictionary[searchRowID] else {
			// Shouldn’t happen. The article has a searchRowID, but we didn’t find that row in the search table.
			// Easy to recover from: just do an initial index, and all’s well.
			performInitialIndex(article, database)
			return
		}

		let title = article.title ?? ""
		if title == searchInfo.title && article.bodyForIndex == searchInfo.body {
			return
		}

		var updateDictionary = DatabaseDictionary()
		if title != searchInfo.title {
			updateDictionary[DatabaseKey.title] = title
		}
		if article.bodyForIndex != searchInfo.body {
			updateDictionary[DatabaseKey.body] = article.bodyForIndex
		}
		database.updateRowsWithDictionary(updateDictionary, whereKey: DatabaseKey.rowID, equals: searchInfo.rowID, tableName: name)
	}

	private func fetchSearchInfos(_ articles: Set<ArticleSearchInfo>, _ database: FMDatabase) -> Set<SearchInfo>? {
		let searchRowIDs = articles.compactMap { $0.searchRowID }
		guard !searchRowIDs.isEmpty else {
			return nil
		}
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(searchRowIDs.count))!
		let sql = "select rowid, title, body from \(name) where rowid in \(placeholders);"
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: searchRowIDs) else {
			return nil
		}
		return resultSet.mapToSet { SearchInfo(row: $0) }
	}

	func fetchArticleSearchInfos(articleIDs: Set<String>, database: FMDatabase) -> Set<ArticleSearchInfo>? {

		let parameters = articleIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!

		guard let resultSet = database.executeQuery(articleSearchInfosQuery(with: placeholders), withArgumentsIn: parameters) else {
			return nil
		}

		let articleSearchInfo = resultSet.mapToSet { (row) -> ArticleSearchInfo? in
			let articleID = row.string(forColumn: DatabaseKey.articleID)!
			let title = row.string(forColumn: DatabaseKey.title)
			let contentHTML = row.string(forColumn: DatabaseKey.contentHTML)
			let contentText = row.string(forColumn: DatabaseKey.contentText)
			let summary = row.string(forColumn: DatabaseKey.summary)
			let authorsNames = row.string(forColumn: DatabaseKey.authors)

			let searchRowIDObject = row.object(forColumnName: DatabaseKey.searchRowID)
			var searchRowID: Int? = nil
			if searchRowIDObject != nil && !(searchRowIDObject is NSNull) {
				searchRowID = Int(row.longLongInt(forColumn: DatabaseKey.searchRowID))
			}

			return ArticleSearchInfo(articleID: articleID, title: title, contentHTML: contentHTML, contentText: contentText, summary: summary, authorsNames: authorsNames, searchRowID: searchRowID)
		}

		return articleSearchInfo
	}

	private func articleSearchInfosQuery(with placeholders: String) -> String {
		return """
		SELECT
			art.articleID,
			art.title,
			art.contentHTML,
			art.contentText,
			art.summary,
			art.searchRowID,
			(SELECT GROUP_CONCAT(name, ' ')
				FROM authorsLookup as autL
				JOIN authors as aut ON autL.authorID = aut.authorID
				WHERE art.articleID = autL.articleID
				GROUP BY autl.articleID) as authors
		FROM articles as art
		WHERE articleID in \(placeholders);
		"""
	}
}
