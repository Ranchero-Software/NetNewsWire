//
//  AppDelegate+Shared.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/15/24.
//  Copyright © 2024 Ranchero Software. All rights reserved.
//

import Foundation
import Images
import ParserObjC

extension AppDelegate: FaviconDownloaderDelegate, FeedIconDownloaderDelegate {

	var appIconImage: IconImage? {
		IconImage.appIcon
	}

	func downloadMetadata(_ url: String) async throws -> RSHTMLMetadata? {

		await HTMLMetadataDownloader.downloadMetadata(for: url)
	}
}
