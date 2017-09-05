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

	static func authorsWithParsedAuthors(_ parsedAuthors: [ParsedAuthor]?) -> Set<Author>? {

		guard let parsedAuthors = parsedAuthors else {
			return nil
		}

		let authors = parsedAuthors.flatMap { Author(parsedAuthor: $0) }
		return authors.isEmpty ? nil : Set(authors)
	}
}

extension Author: DatabaseObject {
	
	public var databaseID: String {
		get {
			return authorID
		}
	}
}
