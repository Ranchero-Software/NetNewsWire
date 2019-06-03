//
//  SmallIconProvider.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/16/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import Account
import RSCore

protocol SmallIconProvider {

	var smallIcon: RSImage? { get }
}

extension Feed: SmallIconProvider {

	var smallIcon: RSImage? {
		if let image = appDelegate.faviconDownloader.favicon(for: self) {
			return image
		}
		#if os(macOS)
		return AppAssets.genericFeedImage
		#else
		return FaviconGenerator.favicon(self)
		#endif
	}
}

extension Folder: SmallIconProvider {

	var smallIcon: RSImage? {
		#if os(macOS)
		return RSImage(named: NSImage.folderName)
		#else
		return AppAssets.masterFolderImage
		#endif
	}
	
}
