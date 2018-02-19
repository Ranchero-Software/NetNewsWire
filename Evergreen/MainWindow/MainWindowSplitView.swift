//
//  MainWindowSplitView.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/5/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit

class MainWindowSplitView: NSSplitView {
	
	private let splitViewDividerColor = NSColor(calibratedWhite: 0.60, alpha: 1.0)
	
	override var dividerColor: NSColor {
		return splitViewDividerColor
	}
}
