//
//  TimelineCellLayout.swift
//  NetNewsWire
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
	let numberOfLinesForTitle: Int
	let summaryRect: NSRect
	let textRect: NSRect
	let unreadIndicatorRect: NSRect
	let starRect: NSRect
	let avatarImageRect: NSRect
	let paddingBottom: CGFloat
	
	init(width: CGFloat, height: CGFloat, feedNameRect: NSRect, dateRect: NSRect, titleRect: NSRect, numberOfLinesForTitle: Int, summaryRect: NSRect, textRect: NSRect, unreadIndicatorRect: NSRect, starRect: NSRect, avatarImageRect: NSRect, paddingBottom: CGFloat) {
		
		self.width = width
		self.feedNameRect = feedNameRect
		self.dateRect = dateRect
		self.titleRect = titleRect
		self.numberOfLinesForTitle = numberOfLinesForTitle
		self.summaryRect = summaryRect
		self.textRect = textRect
		self.unreadIndicatorRect = unreadIndicatorRect
		self.starRect = starRect
		self.avatarImageRect = avatarImageRect
		self.paddingBottom = paddingBottom

		if height > 0.1 {
			self.height = height
		}
		else {
			self.height = [feedNameRect, dateRect, titleRect, summaryRect, textRect, unreadIndicatorRect, avatarImageRect].maxY() + paddingBottom
		}
	}

	init(width: CGFloat, height: CGFloat, cellData: TimelineCellData, appearance: TimelineCellAppearance, hasAvatar: Bool) {

		// If height == 0.0, then height is calculated.

		let showAvatar = hasAvatar && cellData.showAvatar
		var textBoxRect = TimelineCellLayout.rectForTextBox(appearance, cellData, showAvatar, width)

		let (titleRect, numberOfLinesForTitle) = TimelineCellLayout.rectForTitle(textBoxRect, appearance, cellData)
		let summaryRect = numberOfLinesForTitle > 0 ? TimelineCellLayout.rectForSummary(textBoxRect, titleRect, numberOfLinesForTitle, appearance, cellData) : NSRect.zero
		let textRect = numberOfLinesForTitle > 0 ? NSRect.zero : TimelineCellLayout.rectForText(textBoxRect, appearance, cellData)

		var lastTextRect = titleRect
		if numberOfLinesForTitle == 0 {
			lastTextRect = textRect
		}
		else if numberOfLinesForTitle == 1 {
			if summaryRect.height > 0.1 {
				lastTextRect = summaryRect
			}
		}
		let dateRect = TimelineCellLayout.rectForDate(textBoxRect, lastTextRect, appearance, cellData)
		let feedNameRect = TimelineCellLayout.rectForFeedName(textBoxRect, dateRect, appearance, cellData)

		textBoxRect.size.height = ceil([titleRect, summaryRect, textRect, dateRect, feedNameRect].maxY() - textBoxRect.origin.y)
		let avatarImageRect = TimelineCellLayout.rectForAvatar(cellData, appearance, showAvatar, textBoxRect, width, height)
		let unreadIndicatorRect = TimelineCellLayout.rectForUnreadIndicator(appearance, textBoxRect)
		let starRect = TimelineCellLayout.rectForStar(appearance, unreadIndicatorRect)

		let paddingBottom = appearance.cellPadding.bottom

		self.init(width: width, height: height, feedNameRect: feedNameRect, dateRect: dateRect, titleRect: titleRect, numberOfLinesForTitle: numberOfLinesForTitle, summaryRect: summaryRect, textRect: textRect, unreadIndicatorRect: unreadIndicatorRect, starRect: starRect, avatarImageRect: avatarImageRect, paddingBottom: paddingBottom)
	}

	static func height(for width: CGFloat, cellData: TimelineCellData, appearance: TimelineCellAppearance) -> CGFloat {

		let layout = TimelineCellLayout(width: width, height: 0.0, cellData: cellData, appearance: appearance, hasAvatar: true)
		return layout.height
	}
}

// MARK: - Calculate Rects

private extension TimelineCellLayout {

	static func rectForTextBox(_ appearance: TimelineCellAppearance, _ cellData: TimelineCellData, _ showAvatar: Bool, _ width: CGFloat) -> NSRect {

		// Returned height is a placeholder. Not needed when this is calculated.

		let textBoxOriginX = appearance.cellPadding.left + appearance.unreadCircleDimension + appearance.unreadCircleMarginRight
		let textBoxMaxX = floor((width - appearance.cellPadding.right) - (showAvatar ? appearance.avatarSize.width + appearance.avatarMarginLeft : 0.0))
		let textBoxWidth = floor(textBoxMaxX - textBoxOriginX)
		let textBoxRect = NSRect(x: textBoxOriginX, y: appearance.cellPadding.top, width: textBoxWidth, height: 1000000)

		return textBoxRect
	}

	static func rectForTitle(_ textBoxRect: NSRect, _ appearance: TimelineCellAppearance, _ cellData: TimelineCellData) -> (NSRect, Int) {

		var r = textBoxRect

		if cellData.title.isEmpty {
			r.size.height = 0
			return (r, 0)
		}
		
		let sizeInfo = MultilineTextFieldSizer.size(for: cellData.title, font: appearance.titleFont, numberOfLines: appearance.titleNumberOfLines, width: Int(textBoxRect.width))
		r.size.height = sizeInfo.size.height
		if sizeInfo.numberOfLinesUsed < 1 {
			r.size.height = 0
		}
		return (r, sizeInfo.numberOfLinesUsed)
	}

	static func rectForSummary(_ textBoxRect: NSRect, _ titleRect: NSRect, _ titleNumberOfLines: Int,  _ appearance: TimelineCellAppearance, _ cellData: TimelineCellData) -> NSRect {

		if titleNumberOfLines >= appearance.titleNumberOfLines || cellData.text.isEmpty {
			return NSRect.zero
		}

		return rectOfLineBelow(titleRect, titleRect, 0, cellData.text, appearance.textFont)
	}

	static func rectForText(_ textBoxRect: NSRect, _ appearance: TimelineCellAppearance, _ cellData: TimelineCellData) -> NSRect {

		var r = textBoxRect

		if cellData.text.isEmpty {
			r.size.height = 0
			return r
		}

		let sizeInfo = MultilineTextFieldSizer.size(for: cellData.text, font: appearance.textOnlyFont, numberOfLines: appearance.titleNumberOfLines, width: Int(textBoxRect.width))
		r.size.height = sizeInfo.size.height
		if sizeInfo.numberOfLinesUsed < 1 {
			r.size.height = 0
		}
		return r
	}

	static func rectForDate(_ textBoxRect: NSRect, _ rectAbove: NSRect, _ appearance: TimelineCellAppearance, _ cellData: TimelineCellData) -> NSRect {

		return rectOfLineBelow(textBoxRect, rectAbove, appearance.titleBottomMargin, cellData.dateString, appearance.dateFont)
	}

	static func rectForFeedName(_ textBoxRect: NSRect, _ dateRect: NSRect, _ appearance: TimelineCellAppearance, _ cellData: TimelineCellData) -> NSRect {

		if !cellData.showFeedName {
			return NSZeroRect
		}

		return rectOfLineBelow(textBoxRect, dateRect, appearance.dateMarginBottom, cellData.feedName, appearance.feedNameFont)
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

	static func rectForAvatar(_ cellData: TimelineCellData, _ appearance: TimelineCellAppearance, _ showAvatar: Bool, _ textBoxRect: NSRect, _ width: CGFloat, _ height: CGFloat) -> NSRect {

		var r = NSRect.zero
		if !showAvatar {
			return r
		}
		r.size = appearance.avatarSize
		r.origin.x = (width - appearance.cellPadding.right) - r.size.width
		r.origin.y = textBoxRect.origin.y + 4.0
//		r = RSRectCenteredVerticallyInRect(r, textBoxRect)
//		if height > 0.1 {
//			let bounds = NSRect(x: 0.0, y: 0.0, width: width, height: height)
//			r = RSRectCenteredVerticallyInRect(r, bounds)
//		}
//		else {
//			r = RSRectCenteredVerticallyInRect(r, textBoxRect)
//		}

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

