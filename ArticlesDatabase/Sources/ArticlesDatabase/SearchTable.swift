//
//  SearchTable.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import RSDatabase
import RSDatabaseObjC
import Articles
import RSParser

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

final class SearchTable: DatabaseTable {

	let name = "search"
	private let queue: DatabaseQueue
	private weak var articlesTable: ArticlesTable?

	init(queue: DatabaseQueue, articlesTable: ArticlesTable) {
		self.queue = queue
		self.articlesTable = articlesTable
	}

	func ensureIndexedArticles(for articleIDs: Set<String>) {
		guard !articleIDs.isEmpty else {
			return
		}
		queue.runInTransaction { databaseResult in
			if let database = databaseResult.database {
				self.ensureIndexedArticles(articleIDs, database)
			}
		}
	}

	/// Add to, or update, the search index for articles with specified IDs.
	func ensureIndexedArticles(_ articleIDs: Set<String>, _ database: FMDatabase) {
		guard let articlesTable = articlesTable else {
			return
		}
		guard let articleSearchInfos = articlesTable.fetchArticleSearchInfos(articleIDs, in: database) else {
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
		ensureIndexedArticles(articles.articleIDs(), database)
	}
}

// MARK: - Private

private extension SearchTable {

	func performInitialIndexForArticles(_ articles: Set<ArticleSearchInfo>, _ database: FMDatabase) {
		articles.forEach { performInitialIndex($0, database) }
	}

	func performInitialIndex(_ article: ArticleSearchInfo, _ database: FMDatabase) {
		let rowid = insert(article, database)
		articlesTable?.updateRowsWithValue(rowid, valueKey: DatabaseKey.searchRowID, whereKey: DatabaseKey.articleID, matches: [article.articleID], database: database)
	}

	func insert(_ article: ArticleSearchInfo, _ database: FMDatabase) -> Int {
		let rowDictionary: DatabaseDictionary = [DatabaseKey.body: article.bodyForIndex, DatabaseKey.title: article.title ?? ""]
		insertRow(rowDictionary, insertType: .normal, in: database)
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

		articles.forEach { (article) in
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
		updateRowsWithDictionary(updateDictionary, whereKey: DatabaseKey.rowID, matches: searchInfo.rowID, database: database)
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
}
