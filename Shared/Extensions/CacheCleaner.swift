//
//  CacheCleaner.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 11/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import os.log

struct CacheCleaner {

	static let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CacheCleaner")

	static func purgeIfNecessary() {

		guard let flushDate = AppDefaults.shared.lastImageCacheFlushDate else {
			AppDefaults.shared.lastImageCacheFlushDate = Date()
			return
		}
		
		// If the image disk cache hasn't been flushed for 3 days and the network is available, delete it
		if flushDate.addingTimeInterval(3600 * 24 * 3) < Date() {
			if let reachability = try? Reachability(hostname: "apple.com") {
				if reachability.connection != .unavailable {

					let tempDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
					let faviconsFolderURL = tempDir.appendingPathComponent("Favicons")
					let imagesFolderURL = tempDir.appendingPathComponent("Images")
					let feedURLToIconURL = tempDir.appendingPathComponent("FeedURLToIconURLCache.plist")
					let homePageToIconURL = tempDir.appendingPathComponent("HomePageToIconURLCache.plist")
					let homePagesWithNoIconURL = tempDir.appendingPathComponent("HomePagesWithNoIconURLCache.plist")

					for tempItem in [faviconsFolderURL, imagesFolderURL, feedURLToIconURL, homePageToIconURL, homePagesWithNoIconURL] {
						do {
							os_log(.info, log: self.log, "Removing cache file: %@", tempItem.absoluteString)
							try FileManager.default.removeItem(at: tempItem)
						} catch {
							os_log(.error, log: self.log, "Could not delete cache file: %@", error.localizedDescription)
						}
					}
					
					AppDefaults.shared.lastImageCacheFlushDate = Date()
					
				}
			}
		}
		
	}
	
}
