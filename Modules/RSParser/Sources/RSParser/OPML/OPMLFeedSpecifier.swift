//
//  OPMLFeedSpecifier.swift
//  RSParser
//
//  Created by Brent Simmons on 4/20/26.
//

public struct OPMLFeedSpecifier: Sendable {

	public let title: String?
	public let feedDescription: String?
	public let homePageURL: String?
	public let feedURL: String

	public init(title: String?, feedDescription: String?, homePageURL: String?, feedURL: String) {
		self.title = title
		self.feedDescription = feedDescription
		self.homePageURL = homePageURL
		self.feedURL = feedURL
	}
}
