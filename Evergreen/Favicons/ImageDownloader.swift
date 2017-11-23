//
//  FaviconImageDownloader.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/23/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import RSWeb
import RSCore

// Downloads using cache. Enforces a minimum time interval between attempts.

final class ImageDownloader {

	private var urlsBeingDownloaded = Set<String>()
	private var lastAttemptDates = [String: Date]()
	private let minimumAttemptInterval: TimeInterval = 5 * 60
	
	func downloadImage(_ url: String, _ callback: @escaping (NSImage?) -> Void) {

		guard shouldDownloadImage(url) else {
			callback(nil)
			return
		}

		urlsBeingDownloaded.insert(url)
		lastAttemptDates[url] = Date()

		downloadUsingCache(url) { (data, response, error) in

			urlsBeingDownloaded.remove(url)

			if let data = data, let response = response, response.statusIsOK, error == nil {
				NSImage.rs_image(with: data, imageResultBlock: callback)
				return
			}
			callback(nil)
		}
	}
}

private extension ImageDownload {

	func shouldDownloadImage(_ url: String) -> Bool {

		if urlsBeingDownloaded.contains(url) {
			return false
		}
		if let lastAttemptDate = lastAttemptDates[url], Date().timeIntervalSince(lastAttemptDate) < minimumAttemptInterval {
			return false
		}

		return true
	}
}
