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

	var smallIcon: IconImage? { get }
}

extension Account: SmallIconProvider {
	var smallIcon: IconImage? {
		if let image = AppAssets.image(for: type) {
			return IconImage(image)
		}
		return nil
	}
}

extension WebFeed: SmallIconProvider {

	var smallIcon: IconImage? {
		if let iconImage = appDelegate.faviconDownloader.favicon(for: self) {
			return iconImage
		}
		return FaviconGenerator.favicon(self)
	}
}

extension Folder: SmallIconProvider {
	var smallIcon: IconImage? {
		AppAssets.masterFolderImage
	}
}
