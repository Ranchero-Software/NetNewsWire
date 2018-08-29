//
//  FeedListSplitViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/28/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit

class FeedListSplitViewController: NSSplitViewController {

	override func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {

		return false
	}

	override func splitView(_ splitView: NSSplitView, shouldCollapseSubview subview: NSView, forDoubleClickOnDividerAt index: Int) -> Bool {

		return false
	}

	override func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {

		return false
	}
}
