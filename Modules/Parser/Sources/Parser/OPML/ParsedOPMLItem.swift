//
//  File.swift
//  
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

public struct ParsedOPMLItem: Sendable {

	public let feedSpecifier: ParsedOPMLFeedSpecifier?

	public let attributes: [String: String]?
	public let title: String?

	public var items: [ParsedOPMLItem]?
	public var isFolder: Bool

	init(opmlItem: OPMLItem) {

		self.feedSpecifier = ParsedOPMLFeedSpecifier(opmlItem.feedSpecifier)
		self.attributes = opmlItem.attributes
		self.title = opmlItem.title

		self.items = opmlItem.items.map { opmlItem in
			ParsedOPMLItem(opmlItem: opmlItem)
		}
		self.isFolder = (self.items?.count ?? 0) > 0
	}
}
