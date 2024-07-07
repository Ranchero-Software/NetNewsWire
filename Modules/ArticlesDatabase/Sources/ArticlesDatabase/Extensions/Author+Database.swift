//
//  Author+Database.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/8/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import Database
import Parser
import FMDB

// MARK: - DatabaseObject

extension Author {
	
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
	
	public static func authorsWithParsedAuthors(_ parsedAuthors: Set<ParsedAuthor>?) -> Set<Author>? {
		guard let parsedAuthors = parsedAuthors else {
			return nil
		}
		
		let authors = Set(parsedAuthors.compactMap { Author(parsedAuthor: $0) })
		return authors.isEmpty ? nil: authors
	}
}

extension Author: DatabaseObject {

	public var databaseID: String {
		return authorID
	}

	public func databaseDictionary() -> DatabaseDictionary? {
		var d: DatabaseDictionary = [DatabaseKey.authorID: authorID]
		if let name = name {
			d[DatabaseKey.name] = name
		}
		if let url = url {
			d[DatabaseKey.url] = url
		}
		if let avatarURL = avatarURL {
			d[DatabaseKey.avatarURL] = avatarURL
		}
		if let emailAddress = emailAddress {
			d[DatabaseKey.emailAddress] = emailAddress
		}
		return d
	}
}

