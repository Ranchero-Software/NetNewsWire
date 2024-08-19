//
//  OPMLItem.swift
//  
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation
import os

public struct OPMLItem: Sendable {

	public let feedSpecifier: OPMLFeedSpecifier

	public let attributes: [String: String]
	public let titleFromAttributes: String?

	public let isFolder: Bool
	public let items: [OPMLItem]?

	init?(attributes: [String : String], items: [OPMLItem]?) {

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
		
		self.items = items
		self.isFolder = (items?.count ?? 0) > 0
	}
}
