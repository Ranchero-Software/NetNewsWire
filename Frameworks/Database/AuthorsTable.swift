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


struct AuthorsTable: DatabaseTable {
	
	let name: String
	private let cache = ObjectCache<Author>(keyPathForID: \Author.databaseID)

	init(name: String) {

		self.name = name
	}
	
	// MARK: DatabaseTable Methods
	
	func fetchObjectsWithIDs(_ databaseIDs: Set<String>, in database: FMDatabase) -> [DatabaseObject] {
		
		
	}
	
	func save(_ objects: [DatabaseObject], in database: FMDatabase) {
		<#code#>
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

	func articlesNeedingAuthors(_ articles: Set<Article>) -> Set<Article> {

		// If article.authors is nil and article is not known to have zero authors, include it in the set.
		let articlesWithNoAuthors = articles.withNilProperty(\Article.authors)
		return Set(articlesWithNoAuthors.filter { !articleIDsWithNoAuthors.contains($0.databaseID) })
	}

	func fetchAuthorsForArticleIDs(_ articleIDs: Set<String>, _ database: FMDatabase) -> [String: Set<Author>]? {

		let lookupTableDictionary = authorsLookupTable.fetchLookupTableDictionary(articleIDs, database)
		let authorIDs = authorsLookupTable.primaryIDsInLookupTableDictionary(lookupTableDictionary)
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
