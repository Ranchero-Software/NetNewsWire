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
import Images

protocol SmallIconProvider {
	@MainActor var smallIcon: IconImage? { get }
}

@MainActor extension Account: SmallIconProvider {
	var smallIcon: IconImage? {
		let image = Assets.accountImage(type)
		return IconImage(image)
	}
}

@MainActor extension Feed: SmallIconProvider {
	var smallIcon: IconImage? {
		IconImageCache.shared.iconImage(for: self)
	}
}

@MainActor extension Folder: SmallIconProvider {
	var smallIcon: IconImage? {
		Assets.Images.mainFolder
	}
}
