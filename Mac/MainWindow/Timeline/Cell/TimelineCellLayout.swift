//
//  TimelineCellLayout.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore

@MainActor struct TimelineCellLayout {

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
	let iconImageRect: NSRect
	let thumbnailRect: NSRect
	let separatorRect: NSRect
	let paddingBottom: CGFloat

	init(width: CGFloat, height: CGFloat, feedNameRect: NSRect, dateRect: NSRect, titleRect: NSRect, numberOfLinesForTitle: Int, summaryRect: NSRect, textRect: NSRect, unreadIndicatorRect: NSRect, starRect: NSRect, iconImageRect: NSRect, thumbnailRect: NSRect, separatorRect: NSRect, paddingBottom: CGFloat) {

		self.width = width
		self.feedNameRect = feedNameRect
		self.dateRect = dateRect
		self.titleRect = titleRect
		self.numberOfLinesForTitle = numberOfLinesForTitle
		self.summaryRect = summaryRect
		self.textRect = textRect
		self.unreadIndicatorRect = unreadIndicatorRect
		self.starRect = starRect
		self.iconImageRect = iconImageRect
		self.thumbnailRect = thumbnailRect
		self.separatorRect = separatorRect
		self.paddingBottom = paddingBottom

		if height > 0.1 {
			self.height = height
		} else {
			self.height = [feedNameRect, dateRect, titleRect, summaryRect, textRect, unreadIndicatorRect, iconImageRect, thumbnailRect].maxY() + paddingBottom
		}
	}

	init(width: CGFloat, height: CGFloat, cellData: TimelineCellData, appearance: TimelineCellAppearance) {

		// If height == 0.0, then height is calculated.

		let showIcon = cellData.showIcon
		let thumbnailDimension = TimelineCellLayout.thumbnailDimension(cellData, appearance, height)
		var textBoxRect = TimelineCellLayout.rectForTextBox(appearance, cellData, showIcon, thumbnailDimension, width)

		let (titleRect, numberOfLinesForTitle) = TimelineCellLayout.rectForTitle(textBoxRect, appearance, cellData)
		let summaryRect = numberOfLinesForTitle > 0 ? TimelineCellLayout.rectForSummary(textBoxRect, titleRect, numberOfLinesForTitle, appearance, cellData) : NSRect.zero
		let textRect = numberOfLinesForTitle > 0 ? NSRect.zero : TimelineCellLayout.rectForText(textBoxRect, appearance, cellData)

		var lastTextRect = titleRect
		if numberOfLinesForTitle == 0 {
			lastTextRect = textRect
		} else if numberOfLinesForTitle < appearance.titleNumberOfLines {
			if summaryRect.height > 0.1 {
				lastTextRect = summaryRect
			}
		}
		let dateRect = TimelineCellLayout.rectForDate(textBoxRect, lastTextRect, appearance, cellData)
		let feedNameRect = TimelineCellLayout.rectForFeedName(textBoxRect, dateRect, appearance, cellData)

		textBoxRect.size.height = ceil([titleRect, summaryRect, textRect, dateRect, feedNameRect].maxY() - textBoxRect.origin.y)
		let iconImageRect = TimelineCellLayout.rectForIcon(cellData, appearance, showIcon, textBoxRect, width, height)
		let thumbnailRect = appearance.showsLargeThumbnails ? TimelineCellLayout.rectForLargeThumbnail(cellData, appearance, textBoxRect, iconImageRect, width, height) : TimelineCellLayout.rectForThumbnail(appearance, thumbnailDimension, width)
		let unreadIndicatorRect = TimelineCellLayout.rectForUnreadIndicator(appearance, textBoxRect)
		let starRect = TimelineCellLayout.rectForStar(appearance, unreadIndicatorRect)
		let separatorRect = TimelineCellLayout.rectForSeparator(cellData, appearance, showIcon ? iconImageRect : titleRect, width, height)

		let paddingBottom = appearance.cellPadding.bottom

		self.init(width: width, height: height, feedNameRect: feedNameRect, dateRect: dateRect, titleRect: titleRect, numberOfLinesForTitle: numberOfLinesForTitle, summaryRect: summaryRect, textRect: textRect, unreadIndicatorRect: unreadIndicatorRect, starRect: starRect, iconImageRect: iconImageRect, thumbnailRect: thumbnailRect, separatorRect: separatorRect, paddingBottom: paddingBottom)
	}

	static func height(for width: CGFloat, cellData: TimelineCellData, appearance: TimelineCellAppearance) -> CGFloat {

		let layout = TimelineCellLayout(width: width, height: 0.0, cellData: cellData, appearance: appearance)
		return layout.height
	}
}

// MARK: - Calculate Rects

@MainActor private extension TimelineCellLayout {

	/// The small right-side thumbnail’s width and height. Zero when there’s no small thumbnail.
	/// Fits the thumbnail within the row’s padding, since the row height doesn’t grow for it.
	/// A calculated height (zero) never includes a small thumbnail.
	static func thumbnailDimension(_ cellData: TimelineCellData, _ appearance: TimelineCellAppearance, _ height: CGFloat) -> CGFloat {
		guard cellData.showThumbnail, !appearance.showsLargeThumbnails, height > 0.1 else {
			return 0.0
		}
		let availableHeight = floor(height - appearance.cellPadding.top - appearance.cellPadding.bottom)
		return max(0.0, min(appearance.thumbnailMaximumDimension, availableHeight))
	}

	static func rectForTextBox(_ appearance: TimelineCellAppearance, _ cellData: TimelineCellData, _ showIcon: Bool, _ thumbnailDimension: CGFloat, _ width: CGFloat) -> NSRect {

		// Returned height is a placeholder. Not needed when this is calculated.

		let iconSpace = showIcon ? appearance.iconSize.width + appearance.iconMarginRight : 0.0
		let thumbnailSpace = thumbnailDimension > 0.0 ? thumbnailDimension + appearance.thumbnailMarginLeft : 0.0
		let textBoxOriginX = appearance.cellPadding.left + appearance.unreadCircleDimension + appearance.unreadCircleMarginRight + iconSpace
		let textBoxMaxX = floor(width - appearance.cellPadding.right - thumbnailSpace)
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

		let attributedTitle = cellData.attributedTitle.applyingBaseFont(appearance.titleFont)
		let sizeInfo = MultilineTextFieldSizer.size(for: attributedTitle, numberOfLines: appearance.titleNumberOfLines, width: Int(textBoxRect.width))
		r.size.height = sizeInfo.size.height
		if sizeInfo.numberOfLinesUsed < 1 {
			r.size.height = 0
		}
		return (r, sizeInfo.numberOfLinesUsed)
	}

	static func rectForSummary(_ textBoxRect: NSRect, _ titleRect: NSRect, _ titleNumberOfLines: Int, _ appearance: TimelineCellAppearance, _ cellData: TimelineCellData) -> NSRect {
		if titleNumberOfLines >= appearance.titleNumberOfLines || cellData.text.isEmpty {
			return NSRect.zero
		}

		var r = textBoxRect
		r.origin.y = titleRect.maxY
		let summaryNumberOfLines = appearance.titleNumberOfLines - titleNumberOfLines

		let sizeInfo = MultilineTextFieldSizer.size(for: cellData.text, font: appearance.textOnlyFont, numberOfLines: summaryNumberOfLines, width: Int(textBoxRect.width))
		r.size.height = sizeInfo.size.height
		if sizeInfo.numberOfLinesUsed < 1 {
			r.size.height = 0
		}
		return r

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
		let textFieldSize = SingleLineTextFieldSizer.size(for: cellData.dateString, font: appearance.dateFont)

		var r = NSRect.zero
		r.size = textFieldSize
		r.origin.y = rectAbove.maxY + appearance.titleBottomMargin
		r.size.width = textFieldSize.width

		r.origin.x = textBoxRect.maxX - textFieldSize.width

		return r
	}

	static func rectForFeedName(_ textBoxRect: NSRect, _ dateRect: NSRect, _ appearance: TimelineCellAppearance, _ cellData: TimelineCellData) -> NSRect {
		if cellData.showFeedName == .none {
			return NSRect.zero
		}

		let textFieldSize = SingleLineTextFieldSizer.size(for: cellData.feedName, font: appearance.feedNameFont)
		var r = NSRect.zero
		r.size = textFieldSize
		r.origin.y = dateRect.minY
		r.origin.x = textBoxRect.origin.x
		r.size.width = (textBoxRect.maxX - (dateRect.size.width + appearance.dateMarginLeft)) - textBoxRect.origin.x

		return r
	}

	static func rectForUnreadIndicator(_ appearance: TimelineCellAppearance, _ titleRect: NSRect) -> NSRect {

		var r = NSRect.zero
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

	static func rectForIcon(_ cellData: TimelineCellData, _ appearance: TimelineCellAppearance, _ showIcon: Bool, _ textBoxRect: NSRect, _ width: CGFloat, _ height: CGFloat) -> NSRect {

		var r = NSRect.zero
		if !showIcon {
			return r
		}
		r.size = appearance.iconSize
		r.origin.x = appearance.cellPadding.left + appearance.unreadCircleDimension + appearance.unreadCircleMarginRight
		r.origin.y = textBoxRect.origin.y + appearance.iconAdjustmentTop

		return r
	}

	static func rectForThumbnail(_ appearance: TimelineCellAppearance, _ thumbnailDimension: CGFloat, _ width: CGFloat) -> NSRect {
		if thumbnailDimension <= 0.0 {
			return NSRect.zero
		}
		let originX = floor(width - appearance.cellPadding.right - thumbnailDimension)
		return NSRect(x: originX, y: appearance.cellPadding.top, width: thumbnailDimension, height: thumbnailDimension)
	}

	/// Below the text and icon, `largeThumbnailHeight` tall, from the icon’s left edge
	/// (or the text’s, when there’s no icon) to the right padding.
	/// In a cell, it’s bottom-aligned, since rows share one height and titles vary in length,
	/// and it shrinks rather than overlap the text if the row is shorter than expected.
	static func rectForLargeThumbnail(_ cellData: TimelineCellData, _ appearance: TimelineCellAppearance, _ textBoxRect: NSRect, _ iconImageRect: NSRect, _ width: CGFloat, _ height: CGFloat) -> NSRect {
		guard cellData.showThumbnail else {
			return NSRect.zero
		}

		let originX = cellData.showIcon ? iconImageRect.minX : textBoxRect.minX
		let thumbnailWidth = floor(width - appearance.cellPadding.right - originX)
		var thumbnailHeight = appearance.largeThumbnailHeight
		let minimumOriginY = ceil(max(textBoxRect.maxY, iconImageRect.maxY) + appearance.largeThumbnailMarginTop)
		var originY = minimumOriginY

		if height > 0.1 {
			let maximumY = floor(height - appearance.cellPadding.bottom)
			thumbnailHeight = min(thumbnailHeight, maximumY - minimumOriginY)
			originY = maximumY - thumbnailHeight
		}

		guard thumbnailWidth > 0.0, thumbnailHeight > 0.0 else {
			return NSRect.zero
		}
		return NSRect(x: originX, y: originY, width: thumbnailWidth, height: thumbnailHeight)
	}

	static func rectForSeparator(_ cellData: TimelineCellData, _ appearance: TimelineCellAppearance, _ alignmentRect: NSRect, _ width: CGFloat, _ height: CGFloat) -> NSRect {
		return NSRect(x: alignmentRect.minX, y: height - 1, width: width - alignmentRect.minX, height: 1)
	}
}

private extension Array where Element == NSRect {
	func maxY() -> CGFloat {
		var y: CGFloat = 0.0
		for r in self {
			y = Swift.max(y, r.maxY)
		}
		return y
	}
}
