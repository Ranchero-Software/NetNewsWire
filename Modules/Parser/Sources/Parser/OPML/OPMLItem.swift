//
//  OPMLItem.swift
//  
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation
import os

class OPMLItem: @unchecked Sendable {

	public let feedSpecifier: OPMLFeedSpecifier

	public let attributes: [String: String]
	public let titleFromAttributes: String?

	public var items: [OPMLItem]?
	public var isFolder: Bool {
		items.count > 0
	}

	init?(attributes: [String : String]) {

		guard let feedURL = attributes.opml_xmlUrl, !feedURL.isEmpty else {
			return nil
		}

		let titleFromAttributes = {
			if let title = attributes.opml_title {
				return title
			}
			return attributes.opml_text
		}()
		self.titleFromAttributes = titleFromAttributes

		self.feedSpecifier = OPMLFeedSpecifier(title: titleFromAttributes, feedDescription: attributes.opml_description, homePageURL: attributes.opml_htmlUrl, feedURL: feedURL)

		self.attributes = attributes
	}

	func addItem(_ item: OPMLItem) {
		
		if items == nil {
			items = [OPMLItem]()
		}
		items?.append(item)
	}
}
