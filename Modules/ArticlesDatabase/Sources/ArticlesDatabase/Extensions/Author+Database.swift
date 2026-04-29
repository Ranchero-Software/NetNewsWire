//
//  Author+Database.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/8/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import RSParser

extension Author {

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
