//
//  Author+Database.swift
//  Database
//
//  Created by Brent Simmons on 7/8/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Data
import RSDatabase
import RSParser

extension Author {

	static func authorsWithParsedAuthors(_ parsedAuthors: Set<ParsedAuthor>?) -> Set<Author>? {

		assert(!Thread.isMainThread)
		
		guard let parsedAuthors = parsedAuthors else {
			return nil
		}

		let authors = Set(parsedAuthors.flatMap { authorWithParsedAuthor($0) })
		return authors.isEmpty ? nil : authors
	}
	
	static func authorWithRow(_ row: FMResultSet) -> Author? {
		
		guard let authorID = row.string(forColumn: DatabaseKey.authorID) else {
			return nil
		}
		
		if let cachedAuthor = cachedAuthor(authorID) {
			return cachedAuthor
		}
		
		guard let author = Author(authorID: authorID, row: row) else {
			return nil
		}
		
		cacheAuthor(author)
		return author
	}
}

// MARK: - DatabaseObject

extension Author: DatabaseObject {
	
	public var databaseID: String {
		get {
			return authorID
		}
	}
}

// MARK: - Private

private extension Author {
	
	init?(authorID: String, row: FMResultSet) {
		
		let name = row.string(forColumn: DatabaseKey.name)
		let url = row.string(forColumn: DatabaseKey.url)
		let avatarURL = row.string(forColumn: DatabaseKey.avatarURL)
		let emailAddress = row.string(forColumn: DatabaseKey.emailAddress)
		
		self.init(authorID: authorID, name: name, url: url, avatarURL: avatarURL, emailAddress: emailAddress)
	}
	
	init?(parsedAuthor: ParsedAuthor) {
		
		self.init(authorID: nil, name: parsedAuthor.name, url: parsedAuthor.url, avatarURL: parsedAuthor.avatarURL, emailAddress: parsedAuthor.emailAddress)
	}
	
	static func authorWithParsedAuthor(_ parsedAuthor: ParsedAuthor) -> Author? {
		
		if let author = Author(parsedAuthor: parsedAuthor) {
			if let authorFromCache = cachedAuthor(author.authorID) {
				return authorFromCache
			}
			cacheAuthor(author)
			return author
		}
		
		return nil
	}
	
	// The authorCache isn’t because we need uniquing — it’s just to cut down
	// on the number of Author instances, since they would be frequently duplicated.
	// (That is, a given feed might have 10 or 20 or whatever of the same Author.)
	
	private static var authorCache = [String: Author]() //queue-only
	
	static func cachedAuthor(_ authorID: String) -> Author? {
		
		assert(!Thread.isMainThread)
		return authorCache[authorID]
	}
	
	static func cacheAuthor(_ author: Author) {
		
		assert(!Thread.isMainThread)
		authorCache[author.authorID] = author
	}
}

