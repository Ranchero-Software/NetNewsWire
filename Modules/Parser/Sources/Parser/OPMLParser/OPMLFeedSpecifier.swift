//
//  OPMLFeedSpecifier.swift
//  
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

public struct OPMLFeedSpecifier: Sendable {

	public let title: String?
	public let feedDescription: String?
	public let homePageURL: String?
	public let feedURL: String

	init(title: String?, feedDescription: String?, homePageURL: String?, feedURL: String) {

		if String.isEmptyOrNil(title) {
			self.title = nil
		} else {
			self.title = title
		}

		if String.isEmptyOrNil(feedDescription) {
			self.feedDescription = nil
		} else {
			self.feedDescription = feedDescription
		}

		if String.isEmptyOrNil(homePageURL) {
			self.homePageURL = nil
		} else {
			self.homePageURL = homePageURL
		}

		self.feedURL = feedURL
	}
}
