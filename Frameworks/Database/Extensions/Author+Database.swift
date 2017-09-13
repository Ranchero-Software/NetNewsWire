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
	
	init?(row: FMResultSet) {

		let authorID = row.string(forColumn: DatabaseKey.authorID)
		let name = row.string(forColumn: DatabaseKey.name)
		let url = row.string(forColumn: DatabaseKey.url)
		let avatarURL = row.string(forColumn: DatabaseKey.avatarURL)
		let emailAddress = row.string(forColumn: DatabaseKey.emailAddress)
		
		self.init(authorID: authorID, name: name, url: url, avatarURL: avatarURL, emailAddress: emailAddress)
	}
	
	init?(parsedAuthor: ParsedAuthor) {
		
		self.init(authorID: nil, name: parsedAuthor.name, url: parsedAuthor.url, avatarURL: parsedAuthor.avatarURL, emailAddress: parsedAuthor.emailAddress)
	}
}

