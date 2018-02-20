//
//  TimelineCellLayout.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore

struct TimelineCellLayout {
	
	let width: CGFloat
	let height: CGFloat
	let feedNameRect: NSRect
	let dateRect: NSRect
	let titleRect: NSRect
	let unreadIndicatorRect: NSRect
	let starRect: NSRect
	let avatarImageRect: NSRect
	let paddingBottom: CGFloat
	
	init(width: CGFloat, feedNameRect: NSRect, dateRect: NSRect, titleRect: NSRect, unreadIndicatorRect: NSRect, starRect: NSRect, avatarImageRect: NSRect, paddingBottom: CGFloat) {
		
		self.width = width
		self.feedNameRect = feedNameRect
		self.dateRect = dateRect
		self.titleRect = titleRect
		self.unreadIndicatorRect = unreadIndicatorRect
		self.starRect = starRect
		self.avatarImageRect = avatarImageRect
		self.paddingBottom = paddingBottom

		self.height = [feedNameRect, dateRect, titleRect, unreadIndicatorRect, avatarImageRect].maxY() + paddingBottom
	}

	init(width: CGFloat, cellData: TimelineCellData, appearance: TimelineCellAppearance) {

		var textBoxRect = TimelineCellLayout.rectForTextBox(appearance, cellData, width)

		let titleRect = TimelineCellLayout.rectForTitle(textBoxRect, cellData)
		let dateRect = TimelineCellLayout.rectForDate(textBoxRect, titleRect, appearance, cellData)
		let feedNameRect = TimelineCellLayout.rectForFeedName(textBoxRect, dateRect, appearance, cellData)

		textBoxRect.size.height = ceil([titleRect, dateRect, feedNameRect].maxY() - textBoxRect.origin.y)
		let avatarImageRect = TimelineCellLayout.rectForAvatar(cellData, appearance, textBoxRect, width)
		let unreadIndicatorRect = TimelineCellLayout.rectForUnreadIndicator(appearance, titleRect)
		let starRect = TimelineCellLayout.rectForStar(appearance, unreadIndicatorRect)

		let paddingBottom = appearance.cellPadding.bottom

		self.init(width: width, feedNameRect: feedNameRect, dateRect: dateRect, titleRect: titleRect, unreadIndicatorRect: unreadIndicatorRect, starRect: starRect, avatarImageRect: avatarImageRect, paddingBottom: paddingBottom)
	}

	static func height(for width: CGFloat, cellData: TimelineCellData, appearance: TimelineCellAppearance) -> CGFloat {

		let layout = TimelineCellLayout(width: width, cellData: cellData, appearance: appearance)
		return layout.height
	}
}

// MARK: - Calculate Rects

private extension TimelineCellLayout {

	static func rectForTextBox(_ appearance: TimelineCellAppearance, _ cellData: TimelineCellData, _ width: CGFloat) -> NSRect {

		// Returned height is a placeholder. Not needed when this is calculated.

		let textBoxOriginX = appearance.cellPadding.left + appearance.unreadCircleDimension + appearance.unreadCircleMarginRight
		let textBoxMaxX = floor((width - appearance.cellPadding.right) - (cellData.showAvatar ? appearance.avatarSize.width + appearance.avatarMarginLeft : 0.0))
		let textBoxWidth = floor(textBoxMaxX - textBoxOriginX)
		let textBoxRect = NSRect(x: textBoxOriginX, y: appearance.cellPadding.top, width: textBoxWidth, height: 1000000)

		return textBoxRect
	}

	static func rectForTitle(_ textBoxRect: NSRect, _ cellData: TimelineCellData) -> NSRect {

		var r = textBoxRect
		let height = MultilineTextFieldSizer.size(for: cellData.attributedTitle, numberOfLines: 2, width: Int(textBoxRect.width))
		r.size.height = CGFloat(height)

		return r
	}

	static func rectForDate(_ textBoxRect: NSRect, _ titleRect: NSRect, _ appearance: TimelineCellAppearance, _ cellData: TimelineCellData) -> NSRect {

		return rectOfLineBelow(textBoxRect, titleRect, appearance.titleBottomMargin, cellData.dateString, appearance.dateFont)
	}

	static func rectForFeedName(_ textBoxRect: NSRect, _ dateRect: NSRect, _ appearance: TimelineCellAppearance, _ cellData: TimelineCellData) -> NSRect {

		if !cellData.showFeedName {
			return NSZeroRect
		}

		return rectOfLineBelow(textBoxRect, dateRect, appearance.titleBottomMargin, cellData.feedName, appearance.feedNameFont)
	}

	static func rectOfLineBelow(_ textBoxRect: NSRect, _ rectAbove: NSRect, _ topMargin: CGFloat, _ value: String, _ font: NSFont) -> NSRect {

		let textFieldSize = SingleLineTextFieldSizer.size(for: value, font: font)
		var r = NSZeroRect
		r.size = textFieldSize
		r.origin.y = NSMaxY(rectAbove) + topMargin
		r.origin.x = textBoxRect.origin.x

		var width = textFieldSize.width
		width = min(width, textBoxRect.size.width)
		width = max(width, 0.0)
		r.size.width = width

		return r
	}

	static func rectForUnreadIndicator(_ appearance: TimelineCellAppearance, _ titleRect: NSRect) -> NSRect {

		var r = NSZeroRect
		r.size = NSSize(width: appearance.unreadCircleDimension, height: appearance.unreadCircleDimension)
		r.origin.x = appearance.cellPadding.left
		r.origin.y = titleRect.minY + 6
//		r = RSRectCenteredVerticallyInRect(r, titleRect)
//		r.origin.y += 1

		return r
	}

	static func rectForStar(_ appearance: TimelineCellAppearance, _ unreadIndicatorRect: NSRect) -> NSRect {

		var r = NSRect.zero
		r.size.width = appearance.starDimension
		r.size.height = appearance.starDimension
		r.origin.x = floor(unreadIndicatorRect.origin.x - ((appearance.starDimension - appearance.unreadCircleDimension) / 2.0))
		r.origin.y = unreadIndicatorRect.origin.y - 4.0
		return r
	}

	static func rectForAvatar(_ cellData: TimelineCellData, _ appearance: TimelineCellAppearance, _ textBoxRect: NSRect, _ width: CGFloat) -> NSRect {

		var r = NSRect.zero
		if !cellData.showAvatar {
			return r
		}
		r.size = appearance.avatarSize
		r.origin.x = (width - appearance.cellPadding.right) - r.size.width
		r = RSRectCenteredVerticallyInRect(r, textBoxRect)

		return r
	}
}

private extension Array where Element == NSRect {

	func maxY() -> CGFloat {

		var y: CGFloat = 0.0
		self.forEach { y = Swift.max(y, $0.maxY) }
		return y
	}
}

