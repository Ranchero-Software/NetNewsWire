//
//  ParsedItem.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct ParsedItem {

	public let uniqueID: String?
	public let url: String?
	public let externalURL: String?
	public let title: String?
	public let contentHTML: String?
	public let contentText: String?
	public let summary: String?
	public let imageURL: String?
	public let bannerImageURL: String?
	public let datePublished: Date?
	public let dateModified: Date?
	public let authors: [ParsedAuthor]?
	public let tags: [String]?
	public let attachments: [ParsedAttachment]?
}
