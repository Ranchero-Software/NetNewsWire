//
//  NSOutlineView+Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 9/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa

public extension NSOutlineView {

	var selectedItems: [AnyObject] {
		get {

			if selectionIsEmpty {
				return [AnyObject]()
			}

			return selectedRowIndexes.flatMap { (oneIndex) -> AnyObject? in
				return item(atRow: oneIndex) as AnyObject
			}
		}
	}
}
