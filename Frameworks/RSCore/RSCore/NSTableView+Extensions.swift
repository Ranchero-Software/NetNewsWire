//
//  NSTableView+Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 9/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa

public extension NSTableView {

	var selectionIsEmpty: Bool {
		get {
			return selectedRowIndexes.startIndex == selectedRowIndexes.endIndex
		}
	}
}
