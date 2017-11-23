//
//  SeekingFavicon.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/23/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

extension Notification.Name {

	static let SeekingFaviconDidFindFaviconURL = Notification.Name("SeekingFaviconDidFindFaviconURLNotification")
	static let SeekingFaviconDidNotFindFaviconURL = Notification.Name("SeekingFaviconDidNotFindFaviconURLNotification")
}

final class SeekingFavicon {

	// At first, when looking for a favicon, we only know the homePageURL.
	// The faviconURL may be specified by metadata in the home page,
	// or it might be at /favicon.ico,
	// or it might not exist (or be unfindable, which is the same thing).

	let homePageURL: String
	let defaultFaviconURL: String // /favicon.ico
	var didAttemptToLookAtHomePageMetadata = false
	var foundFaviconURL: String?

	var shouldUseDefaultFaviconURL: Bool {

		return didAttemptToLookAtHomePageMetadata && foundFaviconURL == nil
	}

	private static let localeForLowercasing = Locale(identifier: "en_US")

	init?(homePageURL: String) {

		guard let url = URL(string: homePageURL), let scheme = url.scheme, let host = url.host else {
			return nil
		}

		self.homePageURL = homePageURL
		self.defaultFaviconURL = "\(scheme)://\(host)/favicon.ico".lowercased(with: SeekingFavicon.localeForLowercasing)

		findFaviconURL()
	}
}

private extension SeekingFavicon {

	func findFaviconURL() {

		FaviconURLFinder.findFaviconURL(homePageURL) { (faviconURL) in

			self.didAttemptToLookAtHomePageMetadata = true
			self.foundFaviconURL = faviconURL

			if let _ = faviconURL {
				NotificationCenter.default.post(name: .SeekingFaviconDidFindFaviconURL, object: self)
			}
			else {
				NotificationCenter.default.post(name: .SeekingFaviconDidNotFindFaviconURL, object: self)
			}
		}
	}
}
