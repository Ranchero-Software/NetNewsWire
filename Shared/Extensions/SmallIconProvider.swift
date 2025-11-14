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

	@MainActor var smallIcon: IconImage? { get }
}

@MainActor extension Account: SmallIconProvider {
	var smallIcon: IconImage? {
		if let image = AppAssets.image(for: type) {
			return IconImage(image)
		}
		return nil
	}
}

@MainActor extension Feed: SmallIconProvider {

	var smallIcon: IconImage? {
		if let iconImage = FaviconDownloader.shared.favicon(for: self) {
			return iconImage
		}
		return FaviconGenerator.favicon(self)
	}
}

@MainActor extension Folder: SmallIconProvider {
	var smallIcon: IconImage? {
		AppAssets.mainFolderImage
	}
}
