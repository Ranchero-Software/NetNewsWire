//
//  FeedListSplitViewDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 12/27/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa
import DB5
import RSCore

final class FeedListSplitViewDelegate: NSObject, NSSplitViewDelegate {

	@IBOutlet weak var sidebarView: NSView?
	@IBOutlet weak var timelineView: NSView?
	@IBOutlet weak var splitView: NSSplitView?
	let sidebarMinimumThickness: CGFloat
	let sidebarMaximumThickness: CGFloat
	let sidebarBestWidth: CGFloat
	let timelineMinimumThickness: CGFloat

	override init() {

		sidebarMinimumThickness = appDelegate.currentTheme.float(forKey: "FeedDirectory.sidebar.minimumThickness")
		sidebarMaximumThickness = appDelegate.currentTheme.float(forKey: "FeedDirectory.sidebar.maximumThickness")
		sidebarBestWidth = appDelegate.currentTheme.float(forKey: "FeedDirectory.sidebar.bestWidth")
		timelineMinimumThickness = appDelegate.currentTheme.float(forKey: "FeedDirectory.timeline.minimumThickness")

		super.init()
	}

//	override func awakeFromNib() {
//
//		let highestAllowedPriority = NSLayoutConstraint.Priority(rawValue: NSLayoutConstraint.Priority.dragThatCannotResizeWindow.rawValue - 1)
//		splitView?.setHoldingPriority(highestAllowedPriority, forSubviewAt: 0)
//		splitView?.setHoldingPriority(.defaultLow, forSubviewAt: 1)
//	}

	// MARK: - NSSplitViewDelegate

	func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {

		return false
	}

	func splitView(_ splitView: NSSplitView, shouldCollapseSubview subview: NSView, forDoubleClickOnDividerAt dividerIndex: Int) -> Bool {

		return false
	}

	func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {

		return false
	}

	func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {

		return sidebarMinimumThickness
	}

	func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {

		return sidebarMaximumThickness
	}

	func splitView(_ splitView: NSSplitView, constrainSplitPosition proposedPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {

		if proposedPosition < sidebarMinimumThickness {
			return sidebarMinimumThickness
		}

		// If proposedPosition makes timeline too small, then adjust.
		let proposedTimelineWidth = proposedTimelineThickness(splitView, proposedPosition)
		if proposedTimelineWidth < timelineMinimumThickness {
			return min(sidebarMaximumThickness, proposedPosition - (timelineMinimumThickness - proposedTimelineWidth))
		}

		if proposedPosition > sidebarMaximumThickness {
			return sidebarMaximumThickness
		}

		return proposedPosition
	}

//	func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
//
//		guard let sidebarView = sidebarView, let timelineView = timelineView else {
//			assertionFailure("Expected sidebarView and timelineView as non-nil, but at least one is nil.")
//			return true
//		}
//
//		if view === sidebarView {
//			if timelineView.frame.width <= timelineMinimumThickness {
//				return true
//			}
//			return false
//		}
//
//		return true
//	}

	func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {

		guard let sidebarView = sidebarView, let timelineView = timelineView else {
			assertionFailure("Expected sidebarView and timelineView as non-nil, but at least one is nil.")
			return
		}

		let splitViewFrame = splitView.frame
		let splitViewWidth = splitViewFrame.width
		let dividerThickness = splitView.dividerThickness

		var sidebarViewFrame = sidebarView.frame
		sidebarViewFrame.size.height = splitViewFrame.height
		var timelineViewFrame = timelineView.frame
		timelineViewFrame.size.height = splitViewFrame.height

		sidebarViewFrame.size.width = max(sidebarViewFrame.width, sidebarMinimumThickness)
		sidebarViewFrame.size.width = ceil(min(sidebarViewFrame.width, sidebarMaximumThickness))
		timelineViewFrame.size.width = floor(min(timelineViewFrame.width, timelineMinimumThickness))

		let totalProposedWidth = sidebarViewFrame.width + dividerThickness + timelineViewFrame.width
		let difference = splitViewWidth - totalProposedWidth
		if difference < 0 {
			timelineViewFrame.size.width += difference
			if timelineViewFrame.width < 0 {
				timelineViewFrame.size.width = 0
				sidebarViewFrame.size.width += difference
			}
		}

		sidebarView.rs_setFrameIfNotEqual(sidebarViewFrame)
		timelineView.rs_setFrameIfNotEqual(timelineViewFrame)
	}
}

private extension FeedListSplitViewDelegate {

	func proposedTimelineThickness(_ splitView: NSSplitView, _ proposedPosition: CGFloat) -> CGFloat {

		return (splitView.frame.width - splitView.dividerThickness) - proposedPosition
	}

}
