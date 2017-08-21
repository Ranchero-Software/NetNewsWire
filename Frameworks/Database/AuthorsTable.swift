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
// CREATE TABLE if not EXISTS authors (authorID TEXT NOT NULL PRIMARY KEY, name TEXT, url TEXT, avatarURL TEXT, emailAddress TEXT);
// CREATE TABLE if not EXISTS authorLookup (authorID TEXT NOT NULL, articleID TEXT NOT NULL, PRIMARY KEY(authorID, articleID));


struct AuthorsTable: DatabaseTable {
	
	let name: String
	let databaseIDKey = DatabaseKey.authorID
	private let cache = DatabaseObjectCache()

	init(name: String) {

		self.name = name
	}
	
	// MARK: DatabaseTable Methods
	
	func objectWithRow(_ row: FMResultSet) -> DatabaseObject? {
	
		if let author = authorWithRow(row) {
			return author as DatabaseObject
		}
		return nil
	}
	
	func save(_ objects: [DatabaseObject], in database: FMDatabase) {
		// TODO
	}

}

private extension AuthorsTable {

	func authorWithRow(_ row: FMResultSet) -> Author? {

		guard let authorID = row.string(forColumn: DatabaseKey.authorID) else {
			return nil
		}

		if let cachedAuthor = cache[authorID] as? Author {
			return cachedAuthor
		}
		
		guard let author = Author(authorID: authorID, row: row) else {
			return nil
		}

		cache[authorID] = author
		return author
	}
}
