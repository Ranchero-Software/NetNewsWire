//
//  MainWindowSplitView.swift
//  Rainier
//
//  Created by Brent Simmons on 2/5/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa

private let splitViewDividerColor = NSColor(calibratedWhite: 0.8, alpha: 1.0)

class MainWindowSplitView: NSSplitView {

	override var dividerColor: NSColor {
		get {
			return splitViewDividerColor
		}
	}
}
