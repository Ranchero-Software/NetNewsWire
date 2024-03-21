//
//  NSToolbar+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

public extension NSToolbar {

	func existingItem(withIdentifier identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
		return items.first(where: {$0.itemIdentifier == identifier})
	}
}
#endif
