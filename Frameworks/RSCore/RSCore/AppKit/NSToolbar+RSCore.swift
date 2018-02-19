//
//  NSToolbar+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import AppKit

public extension NSToolbar {

	public func existingItem(withIdentifier identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {

		return items.firstElementPassingTest{ $0.itemIdentifier == identifier }
	}
}
