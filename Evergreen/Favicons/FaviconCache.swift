//
//  FaviconCache.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import Data

extension Notification.Name {

	static let FaviconDidDownload = Notification.Name("FaviconDidDownloadNotification")
}

final class FaviconCache {

	// MARK: - API

	func favicon(for feed: Feed) -> NSImage? {

		return nil
	}
}
