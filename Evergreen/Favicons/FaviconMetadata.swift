//
//  Favicon.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/23/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore

final class FaviconController {

	enum DiskStatus {
		case unknown, notOnDisk, onDisk
	}

	let faviconURL: String
	var lastDownloadAttemptDate: Date?
	var diskStatus = DiskStatus.unknown
	let diskCache: RSBinaryCache
	var image: NSImage?

	init?(faviconURL: String, _ diskCache: RSBinaryCache) {

		self.faviconURL = faviconURL
		self.diskCache = diskCache
		findFavicon()
	}
}

private extension FaviconController {

	func findFavicon() {

		readFromDisk { (image) in
			self.image = image
		}

	}

	func readFromDisk(_ callback: (NSImage?) -> Void) {

		if diskStatus == .notOnDisk {
			callback(nil)
			return
		}

	}

}
