//
//  SmallIconProvider.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/16/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import Articles
import Account

protocol SmallIconProvider {

	var smallIcon: NSImage? { get }
}

extension Feed: SmallIconProvider {

	var smallIcon: NSImage? {
		if let image = appDelegate.faviconDownloader.favicon(for: self) {
			return image
		}
		return AppImages.genericFeedImage
	}
}

extension Folder: SmallIconProvider {

	var smallIcon: NSImage? {
		return NSImage(named: NSImage.Name.folder)
	}
}
