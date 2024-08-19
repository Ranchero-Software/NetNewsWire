//
//  ParsedOPMLDocument.swift
//
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

public final class ParsedOPMLDocument: Sendable {

	public let title: String?
	public let url: String?
	public let items: [ParsedOPMLItem]?

	init(opmlDocument: OPMLDocument) {

		self.title = opmlDocument.title
		self.url = opmlDocument.url

		self.items = opmlDocument.items.map { opmlItem in
			ParsedOPMLItem(opmlItem: opmlItem)
		}
	}
}
