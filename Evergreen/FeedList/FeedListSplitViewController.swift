//
//  FeedListSplitViewController.swift
//  Evergreen
//
//  Created by Brent Simmons on 12/27/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa
import DB5

final class FeedListSplitViewController: NSSplitViewController {

	@IBOutlet var sidebarSplitViewItem: NSSplitViewItem!
	@IBOutlet var timelineSplitViewItem: NSSplitViewItem!

	private var sidebarView: NSView {
		return sidebarSplitViewItem.viewController.view
	}

	private var timelineView: NSView {
		return timelineSplitViewItem.viewController.view
	}

	override func viewDidLoad() {

		super.viewDidLoad()

		sidebarView.translatesAutoresizingMaskIntoConstraints = false
		timelineView.translatesAutoresizingMaskIntoConstraints = false
		
		sidebarSplitViewItem.preferredThicknessFraction = NSSplitViewItem.unspecifiedDimension
		sidebarSplitViewItem.canCollapse = false
		timelineSplitViewItem.preferredThicknessFraction = NSSplitViewItem.unspecifiedDimension
		timelineSplitViewItem.canCollapse = false

		let sidebarMinimumThickness = appDelegate.currentTheme.float(forKey: "FeedDirectory.sidebar.minimumThickness")
		sidebarSplitViewItem.minimumThickness = sidebarMinimumThickness
		let sidebarMaximumThickness = appDelegate.currentTheme.float(forKey: "FeedDirectory.sidebar.maximumThickness")
		timelineSplitViewItem.maximumThickness = sidebarMaximumThickness

		let sidebarWidth = appDelegate.currentTheme.float(forKey: "FeedDirectory.sidebar.initialWidth")
		splitView.setPosition(sidebarWidth, ofDividerAt: 0)

		let constraints = timelineView.constraintsAffectingLayout(for: .horizontal)
		print(constraints)
	}

	// MARK: - NSSplitViewDelegate

	override func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {

		super.splitView(splitView, canCollapseSubview: subview)
		let constraints = timelineView.constraintsAffectingLayout(for: .horizontal)
		print(constraints)
	return false
	}

	override func splitView(_ splitView: NSSplitView, shouldCollapseSubview subview: NSView, forDoubleClickOnDividerAt dividerIndex: Int) -> Bool {

		super.splitView(splitView, shouldCollapseSubview: view, forDoubleClickOnDividerAt: dividerIndex)
		let constraints = timelineView.constraintsAffectingLayout(for: .horizontal)
		print(constraints)
		return false
	}

	override func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {

		super.splitView(splitView, shouldHideDividerAt: dividerIndex)
		let constraints = timelineView.constraintsAffectingLayout(for: .horizontal)
		print(constraints)
		return false
	}
}
