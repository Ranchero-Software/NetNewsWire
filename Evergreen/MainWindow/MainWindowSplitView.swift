//
//  MainWindowSplitView.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/5/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa

class MainWindowSplitView: NSSplitView {

	private let splitViewDividerColor = NSColor(calibratedWhite: 0.8, alpha: 1.0)

	override var dividerColor: NSColor {
		get {
			return splitViewDividerColor
		}
	}
}
