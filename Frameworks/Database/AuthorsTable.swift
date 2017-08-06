//
//  AuthorsTable.swift
//  Database
//
//  Created by Brent Simmons on 7/13/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Data

// article->authors is a many-to-many relationship.
// There’s a lookup table relating authorID and articleID.
//
// CREATE TABLE if not EXISTS authors (databaseID TEXT NOT NULL PRIMARY KEY, name TEXT, url TEXT, avatarURL TEXT, emailAddress TEXT);
// CREATE TABLE if not EXISTS authorLookup (authorID TEXT NOT NULL, articleID TEXT NOT NULL, PRIMARY KEY(authorID, articleID));


final class AuthorsTable: DatabaseTable {

	let name: String
	let queue: RSDatabaseQueue
	private let cache = ObjectCache<Author>(keyPathForID: \Author.databaseID)
	private var articleIDToAuthorsCache = [String: Set<Author>]()
	private var articleIDsWithNoAuthors = Set<String>()
	private let authorsLookupTable = LookupTable(name: DatabaseTableName.authorsLookup, primaryKey: DatabaseKey.authorID, foreignKey: DatabaseKey.articleID)

	init(name: String, queue: RSDatabaseQueue) {

		self.name = name
		self.queue = queue
	}

	func attachAuthors(_ articles: Set<Article>, _ database: FMDatabase) {

		attachCachedAuthors(articles)

		let articlesNeedingAuthors = articlesMissingAuthors(articles)
		if articlesNeedingAuthors.isEmpty {
			return
		}

		let articleIDs = Set(articlesNeedingAuthors.map { $0.databaseID })
		let authorTable = fetchAuthorsForArticleIDs(articleIDs, database)

		for article in articlesNeedingAuthors {

			let articleID = article.databaseID

			if let authors = authorTable?[articleID] {
				articleIDsWithNoAuthors.remove(articleID)
				article.authors = Array(authors)
			}
			else {
				articleIDsWithNoAuthors.insert(articleID)
			}
		}
	}
}

private extension AuthorsTable {

	func attachCachedAuthors(_ articles: Set<Article>) {

		for article in articles {
			if let authors = articleIDToAuthorsCache[article.databaseID] {
				article.authors = Array(authors)
			}
		}
	}

	func articlesMissingAuthors(_ articles: Set<Article>) -> Set<Article> {

		return articles.filter{ (article) -> Bool in

			if let _ = article.authors {
				return false
			}
			if articleIDsWithNoAuthors.contains(article.databaseID) {
				return false
			}

			return true
		}
	}

	func fetchAuthorsForArticleIDs(_ articleIDs: Set<String>, _ database: FMDatabase) -> [String: Set<Author>]? {

		let lookupValues = authorsLookupTable.fetchLookupValues(articleIDs, database: database)
		let authorIDs = Set(lookupValues.map { $0.primaryID })
		if authorIDs.isEmpty {
			return nil
		}

		guard let resultSet = selectRowsWhere(key: DatabaseKey.databaseID, inValues: Array(authorIDs), in: database) else {
			return nil
		}

		let authors = authorsWithResultSet(resultSet)
		if authors.isEmpty {
			return nil
		}

		return authorTableWithLookupValues(lookupValues)
	}

	func authorTableWithLookupValues(_ lookupValues: Set<LookupValue>) -> [String: Set<Author>] {

		var authorTable = [String: Set<Author>]()

		for lookupValue in lookupValues {

			let authorID = lookupValue.primaryID
			guard let author = cache[authorID] else {
				continue
			}

			let articleID = lookupValue.foreignID
			if authorTable[articleID] == nil {
				authorTable[articleID] = Set([author])
			}
			else {
				authorTable[articleID]!.insert(author)
			}
		}

		return authorTable
	}

	func authorsWithResultSet(_ resultSet: FMResultSet) -> Set<Author> {

		return resultSet.mapToSet(authorWithRow)
	}

	func authorWithRow(_ row: FMResultSet) -> Author? {

		guard let databaseID = row.string(forColumn: DatabaseKey.databaseID) else {
			return nil
		}

		if let cachedAuthor = cache[databaseID] {
			return cachedAuthor
		}
		
		guard let author = Author(databaseID: databaseID, row: row) else {
			return nil
		}

		cache[databaseID] = author
		return author
	}
}
