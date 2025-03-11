//
//  CacheCleaner.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 11/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import os.log
import RSWeb

struct CacheCleaner {

	static let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CacheCleaner")

	static func purgeIfNecessary() {

		guard let flushDate = AppDefaults.lastImageCacheFlushDate else {
			AppDefaults.lastImageCacheFlushDate = Date()
			return
		}

		// If the image disk cache hasn't been flushed for 3 days and the network is available, delete it
		if flushDate.addingTimeInterval(3600 * 24 * 3) < Date() {
			if let reachability = try? Reachability(hostname: "apple.com") {
				if reachability.connection != .unavailable {

					let tempDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
						.appendingPathComponent((Bundle.main.infoDictionary!["CFBundleIdentifier"]! as! String), isDirectory: true)

					for tempItem in ["Favicons", "Images", "FeedIcons"] {
						let tempPath = tempDir.appendingPathComponent(tempItem)

						do {
							os_log(.info, log: self.log, "Removing cache file: %@", tempPath.absoluteString)
							try FileManager.default.removeItem(at: tempPath)
						} catch {
							os_log(.error, log: self.log, "Could not delete cache file: %@", error.localizedDescription)
						}
					}

					AppDefaults.lastImageCacheFlushDate = Date()

				}
			}
		}

	}

}
