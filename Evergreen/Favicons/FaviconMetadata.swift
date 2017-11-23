//
//  Favicon.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/23/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit

final class FaviconMetadata {

	enum DiskStatus {
		case unknown, notOnDisk, onDisk
	}

	let faviconURL: String
	var lastDownloadAttemptDate: Date?
	var diskStatus = DiskStatus.unknown
	var image: NSImage?

	init?(faviconURL: String) {

		self.faviconURL = faviconURL
	}
}
