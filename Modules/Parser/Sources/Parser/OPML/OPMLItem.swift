//
//  OPMLItem.swift
//  
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation
import os

class OPMLItem: @unchecked Sendable {

	public let feedSpecifier: ParsedOPMLFeedSpecifier

	public let attributes: [String: String]
	public let titleFromAttributes: String?

	public var items: [OPMLItem]?
	public var isFolder: Bool {
		items.count > 0
	}

	init(attributes: [String : String]?) {

		self.titleFromAttributes = attributes.opml_title ?? attributes.opml_text
		self.attributes = attributes

		self.feedSpecifier = ParsedOPMLFeedSpecifier(title: self.titleFromAttributes, feedDescription: attributes.opml_description, homePageURL: attributes.opml_htmlUrl, feedURL: attributes.opml_xmlUrl)

	}

	func addItem(_ item: OPMLItem) {
		
		if items == nil {
			items = [OPMLItem]()
		}
		items?.append(item)
	}
}
