//
//  Article+Database.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import RSDatabaseObjC
import Articles
import RSParser

extension Article {

	convenience init?(accountID: String, row: FMResultSet, status: ArticleStatus) {
		guard let articleID = row.swiftString(forColumn: DatabaseKey.articleID) else {
			assertionFailure("Expected articleID.")
			return nil
		}
		guard let feedID = row.swiftString(forColumn: DatabaseKey.feedID) else {
			assertionFailure("Expected feedID.")
			return nil
		}
		guard let uniqueID = row.swiftString(forColumn: DatabaseKey.uniqueID) else {
			assertionFailure("Expected uniqueID.")
			return nil
		}

		let title = row.swiftString(forColumn: DatabaseKey.title)
		let contentHTML = row.swiftString(forColumn: DatabaseKey.contentHTML)
		let contentText = row.swiftString(forColumn: DatabaseKey.contentText)
		let markdown = row.swiftString(forColumn: DatabaseKey.markdown)
		let url = row.swiftString(forColumn: DatabaseKey.url)
		let externalURL = row.swiftString(forColumn: DatabaseKey.externalURL)
		let summary = row.swiftString(forColumn: DatabaseKey.summary)
		let imageURL = row.swiftString(forColumn: DatabaseKey.imageURL)
		let datePublished = row.date(forColumn: DatabaseKey.datePublished)
		let dateModified = row.date(forColumn: DatabaseKey.dateModified)
		let authors = Self.authorsFromRow(row)

		self.init(accountID: accountID, articleID: articleID, feedID: feedID, uniqueID: uniqueID, title: title, contentHTML: contentHTML, contentText: contentText, markdown: markdown, url: url, externalURL: externalURL, summary: summary, imageURL: imageURL, datePublished: datePublished, dateModified: dateModified, authors: authors, status: status)
	}

	private static func authorsFromRow(_ row: FMResultSet) -> Set<Author>? {
		guard let json = row.swiftString(forColumn: DatabaseKey.authors), !json.isEmpty, let data = json.data(using: .utf8) else {
			return nil
		}
		return Author.authorsWithJSON(data)
	}

	convenience init(parsedItem: ParsedItem, maximumDateAllowed: Date, accountID: String, feedID: String, status: ArticleStatus) {
		let authors = Author.authorsWithParsedAuthors(parsedItem.authors)

		// Deal with future datePublished and dateModified dates.
		var datePublished = parsedItem.datePublished
		if datePublished == nil {
			datePublished = parsedItem.dateModified
		}
		if datePublished != nil, datePublished! > maximumDateAllowed {
			datePublished = nil
		}

		var dateModified = parsedItem.dateModified
		if dateModified != nil, dateModified! > maximumDateAllowed {
			dateModified = nil
		}

		self.init(accountID: accountID, articleID: parsedItem.syncServiceID, feedID: feedID, uniqueID: parsedItem.uniqueID, title: parsedItem.title, contentHTML: parsedItem.contentHTML, contentText: parsedItem.contentText, markdown: parsedItem.markdown, url: parsedItem.url, externalURL: parsedItem.externalURL, summary: parsedItem.summary, imageURL: parsedItem.imageURL, datePublished: datePublished, dateModified: dateModified, authors: authors, status: status)
	}

	private func addPossibleStringChangeWithKeyPath(_ comparisonKeyPath: KeyPath<Article, String?>, _ otherArticle: Article, _ key: String, _ dictionary: inout DatabaseDictionary) {
		if self[keyPath: comparisonKeyPath] != otherArticle[keyPath: comparisonKeyPath] {
			dictionary[key] = self[keyPath: comparisonKeyPath] ?? ""
		}
	}

	func changesFrom(_ existingArticle: Article) -> DatabaseDictionary? {
		if self == existingArticle {
			return nil
		}

		var d = DatabaseDictionary()
		if uniqueID != existingArticle.uniqueID {
			d[DatabaseKey.uniqueID] = uniqueID
		}

		addPossibleStringChangeWithKeyPath(\Article.title, existingArticle, DatabaseKey.title, &d)
		addPossibleStringChangeWithKeyPath(\Article.contentHTML, existingArticle, DatabaseKey.contentHTML, &d)
		addPossibleStringChangeWithKeyPath(\Article.contentText, existingArticle, DatabaseKey.contentText, &d)
		addPossibleStringChangeWithKeyPath(\Article.rawLink, existingArticle, DatabaseKey.url, &d)
		addPossibleStringChangeWithKeyPath(\Article.rawExternalLink, existingArticle, DatabaseKey.externalURL, &d)
		addPossibleStringChangeWithKeyPath(\Article.summary, existingArticle, DatabaseKey.summary, &d)
		addPossibleStringChangeWithKeyPath(\Article.rawImageLink, existingArticle, DatabaseKey.imageURL, &d)

		if authors != existingArticle.authors {
			if let authors, !authors.isEmpty, let json = authors.json() {
				d[DatabaseKey.authors] = json
			} else {
				d[DatabaseKey.authors] = ""
			}
		}

		// If updated versions of dates are nil, and we have existing dates, keep the existing dates.
		// This is data that’s good to have, and it’s likely that a feed removing dates is doing so in error.
		if datePublished != existingArticle.datePublished {
			if let updatedDatePublished = datePublished {
				d[DatabaseKey.datePublished] = updatedDatePublished
			}
		}
		if dateModified != existingArticle.dateModified {
			if let updatedDateModified = dateModified {
				d[DatabaseKey.dateModified] = updatedDateModified
			}
		}

		return d.count < 1 ? nil : d
	}

//	static func articlesWithParsedItems(_ parsedItems: Set<ParsedItem>, _ accountID: String, _ feedID: String, _ statusesDictionary: [String: ArticleStatus]) -> Set<Article> {
//		let maximumDateAllowed = Date().addingTimeInterval(60 * 60 * 24) // Allow dates up to about 24 hours ahead of now
//		return Set(parsedItems.map{ Article(parsedItem: $0, maximumDateAllowed: maximumDateAllowed, accountID: accountID, feedID: feedID, status: statusesDictionary[$0.articleID]!) })
//	}

	private static func _maximumDateAllowed() -> Date {
		return Date().addingTimeInterval(60 * 60 * 24) // Allow dates up to about 24 hours ahead of now
	}

	static func articlesWithFeedIDsAndItems(_ feedIDsAndItems: [String: Set<ParsedItem>], _ accountID: String, _ statusesDictionary: [String: ArticleStatus]) -> Set<Article> {
		let maximumDateAllowed = _maximumDateAllowed()
		var feedArticles = Set<Article>()
		for (feedID, parsedItems) in feedIDsAndItems {
			for parsedItem in parsedItems {
				let status = statusesDictionary[parsedItem.articleID]!
				let article = Article(parsedItem: parsedItem, maximumDateAllowed: maximumDateAllowed, accountID: accountID, feedID: feedID, status: status)
				feedArticles.insert(article)
			}
		}
		return feedArticles
	}

	static func articlesWithParsedItems(_ parsedItems: Set<ParsedItem>, _ feedID: String, _ accountID: String, _ statusesDictionary: [String: ArticleStatus]) -> Set<Article> {
		let maximumDateAllowed = _maximumDateAllowed()
		return Set(parsedItems.map { Article(parsedItem: $0, maximumDateAllowed: maximumDateAllowed, accountID: accountID, feedID: feedID, status: statusesDictionary[$0.articleID]!) })
	}
}

extension Article {

	func databaseDictionary() -> DatabaseDictionary {
		var d = DatabaseDictionary()

		d[DatabaseKey.articleID] = articleID
		d[DatabaseKey.feedID] = feedID
		d[DatabaseKey.uniqueID] = uniqueID

		if let title = title {
			d[DatabaseKey.title] = title
		}
		if let contentHTML = contentHTML {
			d[DatabaseKey.contentHTML] = contentHTML
		}
		if let contentText = contentText {
			d[DatabaseKey.contentText] = contentText
		}
		if let markdown = markdown {
			d[DatabaseKey.markdown] = markdown
		}
		if let rawLink = rawLink {
			d[DatabaseKey.url] = rawLink
		}
		if let rawExternalLink = rawExternalLink {
			d[DatabaseKey.externalURL] = rawExternalLink
		}
		if let summary = summary {
			d[DatabaseKey.summary] = summary
		}
		if let rawImageLink = rawImageLink {
			d[DatabaseKey.imageURL] = rawImageLink
		}
		if let datePublished = datePublished {
			d[DatabaseKey.datePublished] = datePublished
		}
		if let dateModified = dateModified {
			d[DatabaseKey.dateModified] = dateModified
		}
		if let authors, !authors.isEmpty, let json = authors.json() {
			d[DatabaseKey.authors] = json
		}
		return d
	}
}

extension Set where Element == Article {

	func statuses() -> Set<ArticleStatus> {
		return Set<ArticleStatus>(map { $0.status })
	}

	func dictionary() -> [String: Article] {
		var d = [String: Article]()
		for article in self {
			d[article.articleID] = article
		}
		return d
	}

	func databaseDictionaries() -> [DatabaseDictionary] {
		return self.map { $0.databaseDictionary() }
	}
}
