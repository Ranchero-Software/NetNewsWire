//
//  OPMLItem.swift
//  
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation
import os

public class OPMLItem {

	public let feedSpecifier: OPMLFeedSpecifier?

	public let attributes: [String: String]?
	public let titleFromAttributes: String?

	public var items: [OPMLItem]?
	public var isFolder: Bool {
		(items?.count ?? 0) > 0
	}

	init(attributes: [String: String]?) {

		self.titleFromAttributes = attributes?.opml_title ?? attributes?.opml_text
		self.attributes = attributes

		if let feedURL = attributes?.opml_xmlUrl {
			self.feedSpecifier = OPMLFeedSpecifier(title: self.titleFromAttributes, feedDescription: attributes?.opml_description, homePageURL: attributes?.opml_htmlUrl, feedURL: feedURL)
		} else {
			self.feedSpecifier = nil
		}
	}

	public func add(_ item: OPMLItem) {

		if items == nil {
			items = [OPMLItem]()
		}
		items?.append(item)
	}
}
