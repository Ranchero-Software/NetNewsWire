//
//  ImageUtilities.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/19/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation

struct ImageUtilities {

	static func shouldUseNNWFeedIcon(with feedURL: URL) -> Bool {

		guard let host = feedURL.host() else {
			return false
		}

		if host == "nnw.ranchero.com" || host == "netnewswire.blog" {
			return true
		}
		if host != "ranchero.com" {
			return false
		}

		let absoluteString = feedURL.absoluteString
		if absoluteString == "https://ranchero.com/downloads/netnewswire-beta.xml" || absoluteString == "https://ranchero.com/downloads/netnewswire-release.xml" {
			return true
		}

		return false
	}
}

