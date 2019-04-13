//
//  FaviconURLFinder.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/20/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSParser

// The favicon URL may be specified in the head section of the home page.

struct FaviconURLFinder {

	static func findFaviconURL(_ homePageURL: String, _ callback: @escaping (String?) -> Void) {

		guard let _ = URL(string: homePageURL) else {
			callback(nil)
			return
		}

		HTMLMetadataDownloader.downloadMetadata(for: homePageURL) { (htmlMetadata) in
			callback(htmlMetadata?.faviconLink)
		}
	}
}

