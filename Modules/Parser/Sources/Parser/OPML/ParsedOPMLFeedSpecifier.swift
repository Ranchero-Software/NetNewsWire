//
//  ParsedOPMLFeedSpecifier.swift
//
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

public struct ParsedOPMLFeedSpecifier: Sendable {

	public let title: String?
	public let feedDescription: String?
	public let homePageURL: String?
	public let feedURL: String

	init(_ opmlFeedSpecifier: OPMLFeedSpecifier) {

		self.title = opmlFeedSpecifier.title
		self.feedDescription = opmlFeedSpecifier.feedDescription
		self.homePageURL = opmlFeedSpecifier.homePageURL
		self.feedURL = opmlFeedSpecifier.feedURL
	}
}
