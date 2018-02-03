//
//  TimelineCellLayout.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSTextDrawing
import RSCore

struct TimelineCellLayout {
	
	let width: CGFloat
	let height: CGFloat
	let feedNameRect: NSRect
	let dateRect: NSRect
	let titleRect: NSRect
	let unreadIndicatorRect: NSRect
	let avatarImageRect: NSRect
	let paddingBottom: CGFloat
	
	init(width: CGFloat, feedNameRect: NSRect, dateRect: NSRect, titleRect: NSRect, unreadIndicatorRect: NSRect, avatarImageRect: NSRect, paddingBottom: CGFloat) {
		
		self.width = width
		self.feedNameRect = feedNameRect
		self.dateRect = dateRect
		self.titleRect = titleRect
		self.unreadIndicatorRect = unreadIndicatorRect
		self.avatarImageRect = avatarImageRect
		self.paddingBottom = paddingBottom
		
		var height = max(0, feedNameRect.maxY)
		height = max(height, dateRect.maxY)
		height = max(height, titleRect.maxY)
		height = max(height, unreadIndicatorRect.maxY)
		height = max(height, avatarImageRect.maxY)
		height += paddingBottom
		self.height = height
	}
}

private func rectForDate(_ cellData: TimelineCellData, _ width: CGFloat, _ appearance: TimelineCellAppearance, _ titleRect: NSRect) -> NSRect {
	
	let renderer = RSSingleLineRenderer(attributedTitle: cellData.attributedDateString)
	var r = NSZeroRect
	r.size = renderer.size

	r.origin.y = NSMaxY(titleRect) + appearance.titleBottomMargin
	r.origin.x = appearance.boxLeftMargin
	
	r.size.width = min(width - (r.origin.x + appearance.cellPadding.right), r.size.width)
	r.size.width = max(r.size.width, 0.0)

	return r
}

private func rectForFeedName(_ cellData: TimelineCellData, _ width: CGFloat, _ appearance: TimelineCellAppearance, _ dateRect: NSRect) -> NSRect {
	
	if !cellData.showFeedName {
		return NSZeroRect
	}

	let renderer = RSSingleLineRenderer(attributedTitle: cellData.attributedFeedName)
	var r = NSZeroRect
	r.size = renderer.size
	r.origin.y = NSMaxY(dateRect) + appearance.titleBottomMargin
	r.origin.x = appearance.boxLeftMargin
	
	r.size.width = max(0, width - (r.origin.x + appearance.cellPadding.right))
	
	return r
}

//private func rectForFavicon(_ cellData: TimelineCellData, _ appearance: TimelineCellAppearance, _ feedNameRect: NSRect, _ unreadIndicatorRect: NSRect) -> NSRect {
//	
//	guard let _ = cellData.favicon, cellData.showFeedName else {
//		return NSZeroRect
//	}
//	
//	var r = NSZeroRect
//	r.size = appearance.faviconSize
//	r.origin.y = feedNameRect.origin.y
//	
//	r = RSRectCenteredHorizontallyInRect(r, unreadIndicatorRect)
//	
//	return r
//}

private func rectsForTitle(_ cellData: TimelineCellData, _ width: CGFloat, _ appearance: TimelineCellAppearance) -> (NSRect, NSRect) {
	
	var r = NSZeroRect
	r.origin.x = appearance.boxLeftMargin
	r.origin.y = appearance.cellPadding.top

	let textWidth = width - (r.origin.x + appearance.cellPadding.right)
	let renderer = RSMultiLineRenderer(attributedTitle: cellData.attributedTitle)

	let measurements = renderer.measurements(forWidth: textWidth)
	r.size = NSSize(width: textWidth, height: CGFloat(measurements.height))
	r.size.width = max(r.size.width, 0.0)

	var rline1 = r
	rline1.size.height = CGFloat(measurements.heightOfFirstLine)
	
	return (r, rline1)
}

private func rectForUnreadIndicator(_ cellData: TimelineCellData, _ appearance: TimelineCellAppearance, _ titleLine1Rect: NSRect) -> NSRect {
	
	var r = NSZeroRect
	r.size = NSSize(width: appearance.unreadCircleDimension, height: appearance.unreadCircleDimension)
	r.origin.x = appearance.cellPadding.left
	r = RSRectCenteredVerticallyInRect(r, titleLine1Rect)
	
	return r
}

private func rectForAvatar(_ cellData: TimelineCellData, _ appearance: TimelineCellAppearance, _ titleLine1Rect: NSRect) -> NSRect {

	var r = NSRect.zero
	if !cellData.showAvatar {
		return r
	}
	r.size = appearance.avatarSize
	r.origin.x = appearance.cellPadding.left + appearance.unreadCircleDimension + appearance.unreadCircleMarginRight
	r.origin.y = titleLine1Rect.minY + appearance.avatarAdjustmentTop

	return r
}

func timelineCellLayout(_ width: CGFloat, cellData: TimelineCellData, appearance: TimelineCellAppearance) -> TimelineCellLayout {

	let (titleRect, titleLine1Rect) = rectsForTitle(cellData, width, appearance)
	let dateRect = rectForDate(cellData, width, appearance, titleRect)
	let feedNameRect = rectForFeedName(cellData, width, appearance, dateRect)
	let unreadIndicatorRect = rectForUnreadIndicator(cellData, appearance, titleLine1Rect)
//	let faviconRect = rectForFavicon(cellData, appearance, feedNameRect, unreadIndicatorRect)
	let avatarImageRect = rectForAvatar(cellData, appearance, titleLine1Rect)

	return TimelineCellLayout(width: width, feedNameRect: feedNameRect, dateRect: dateRect, titleRect: titleRect, unreadIndicatorRect: unreadIndicatorRect, avatarImageRect: avatarImageRect, paddingBottom: appearance.cellPadding.bottom)
}

func timelineCellHeight(_ width: CGFloat, cellData: TimelineCellData, appearance: TimelineCellAppearance) -> CGFloat {
	
	let layout = timelineCellLayout(width, cellData: cellData, appearance: appearance)
	return layout.height
}
