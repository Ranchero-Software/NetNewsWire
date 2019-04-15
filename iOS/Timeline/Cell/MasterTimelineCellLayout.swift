//
//  MasterTimelineCellLayout.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import UIKit
import RSCore

struct MasterTimelineCellLayout {

	static let cellPadding = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

	static let feedColor = AppAssets.timelineTextSecondaryColor
	static let feedNameFont = UIFont.systemFont(ofSize: UIFont.systemFontSize)

	static let dateColor = AppAssets.timelineTextSecondaryColor
	static let dateFont = UIFont.systemFont(ofSize: UIFont.systemFontSize, weight: UIFont.Weight.bold)
	static let dateMarginBottom = CGFloat(integerLiteral: 1)

	static let titleColor = AppAssets.timelineTextPrimaryColor
	static let titleFont = UIFont.systemFont(ofSize: UIFont.systemFontSize, weight: .semibold)
	static let titleBottomMargin = CGFloat(integerLiteral: 1)
	static let titleNumberOfLines = 2
	
	static let textColor = AppAssets.timelineTextPrimaryColor
	static let textFont = UIFont.systemFont(ofSize: UIFont.systemFontSize)

	static let textOnlyFont = UIFont.systemFont(ofSize: UIFont.systemFontSize)
	
	static let unreadCircleDimension = CGFloat(integerLiteral: 8)
	static let unreadCircleMarginRight = CGFloat(integerLiteral: 8)

	static let starDimension = CGFloat(integerLiteral: 13)

	static let avatarSize = CGSize(width: 48.0, height: 48.0)
	static let avatarMarginLeft = CGFloat(integerLiteral: 8)
	static let avatarCornerRadius = CGFloat(integerLiteral: 4)
	
	let width: CGFloat
	let height: CGFloat
	let feedNameRect: CGRect
	let dateRect: CGRect
	let titleRect: CGRect
	let numberOfLinesForTitle: Int
	let summaryRect: CGRect
	let textRect: CGRect
	let unreadIndicatorRect: CGRect
	let starRect: CGRect
	let avatarImageRect: CGRect
	let paddingBottom: CGFloat
	
	init(width: CGFloat, height: CGFloat, feedNameRect: CGRect, dateRect: CGRect, titleRect: CGRect, numberOfLinesForTitle: Int, summaryRect: CGRect, textRect: CGRect, unreadIndicatorRect: CGRect, starRect: CGRect, avatarImageRect: CGRect, paddingBottom: CGFloat) {
		
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
		} else {
			self.height = [feedNameRect, dateRect, titleRect, summaryRect, textRect, unreadIndicatorRect, avatarImageRect].maxY() + paddingBottom
		}
		
	}

	init(width: CGFloat, height: CGFloat, cellData: MasterTimelineCellData, hasAvatar: Bool) {

		// If height == 0.0, then height is calculated.

		let showAvatar = hasAvatar && cellData.showAvatar
		var textBoxRect = MasterTimelineCellLayout.rectForTextBox(cellData, showAvatar, width)

		let (titleRect, numberOfLinesForTitle) = MasterTimelineCellLayout.rectForTitle(textBoxRect, cellData)
		let summaryRect = numberOfLinesForTitle > 0 ? MasterTimelineCellLayout.rectForSummary(textBoxRect, titleRect, numberOfLinesForTitle, cellData) : CGRect.zero
		let textRect = numberOfLinesForTitle > 0 ? CGRect.zero : MasterTimelineCellLayout.rectForText(textBoxRect, cellData)

		var lastTextRect = titleRect
		if numberOfLinesForTitle == 0 {
			lastTextRect = textRect
		} else if numberOfLinesForTitle == 1 {
			if summaryRect.height > 0.1 {
				lastTextRect = summaryRect
			}
		}
		
		let dateRect = MasterTimelineCellLayout.rectForDate(textBoxRect, lastTextRect, cellData)
		let feedNameRect = MasterTimelineCellLayout.rectForFeedName(textBoxRect, dateRect, cellData)

		textBoxRect.size.height = ceil([titleRect, summaryRect, textRect, dateRect, feedNameRect].maxY() - textBoxRect.origin.y)
		let avatarImageRect = MasterTimelineCellLayout.rectForAvatar(cellData, showAvatar, textBoxRect, width, height)
		let unreadIndicatorRect = MasterTimelineCellLayout.rectForUnreadIndicator(textBoxRect)
		let starRect = MasterTimelineCellLayout.rectForStar(unreadIndicatorRect)

		let paddingBottom = MasterTimelineCellLayout.cellPadding.bottom

		self.init(width: width, height: height, feedNameRect: feedNameRect, dateRect: dateRect, titleRect: titleRect, numberOfLinesForTitle: numberOfLinesForTitle, summaryRect: summaryRect, textRect: textRect, unreadIndicatorRect: unreadIndicatorRect, starRect: starRect, avatarImageRect: avatarImageRect, paddingBottom: paddingBottom)
		
	}

	static func height(for width: CGFloat, cellData: MasterTimelineCellData) -> CGFloat {
		let layout = MasterTimelineCellLayout(width: width, height: 0.0, cellData: cellData, hasAvatar: true)
		return layout.height
	}
	
}

// MARK: - Calculate Rects

private extension MasterTimelineCellLayout {

	static func rectForTextBox(_ cellData: MasterTimelineCellData, _ showAvatar: Bool, _ width: CGFloat) -> CGRect {

		// Returned height is a placeholder. Not needed when this is calculated.

		let textBoxOriginX = MasterTimelineCellLayout.cellPadding.left + MasterTimelineCellLayout.unreadCircleDimension + MasterTimelineCellLayout.unreadCircleMarginRight
		let textBoxMaxX = floor((width - MasterTimelineCellLayout.cellPadding.right) - (showAvatar ? MasterTimelineCellLayout.avatarSize.width + MasterTimelineCellLayout.avatarMarginLeft : 0.0))
		let textBoxWidth = floor(textBoxMaxX - textBoxOriginX)
		let textBoxRect = CGRect(x: textBoxOriginX, y: MasterTimelineCellLayout.cellPadding.top, width: textBoxWidth, height: 1000000)

		return textBoxRect
		
	}

	static func rectForTitle(_ textBoxRect: CGRect, _ cellData: MasterTimelineCellData) -> (CGRect, Int) {

		var r = textBoxRect

		if cellData.title.isEmpty {
			r.size.height = 0
			return (r, 0)
		}
		
		let sizeInfo = MultilineUILabelSizer.size(for: cellData.title, font: MasterTimelineCellLayout.titleFont, numberOfLines: MasterTimelineCellLayout.titleNumberOfLines, width: Int(textBoxRect.width))
		r.size.height = sizeInfo.size.height
		if sizeInfo.numberOfLinesUsed < 1 {
			r.size.height = 0
		}
		return (r, sizeInfo.numberOfLinesUsed)
	}

	static func rectForSummary(_ textBoxRect: CGRect, _ titleRect: CGRect, _ titleNumberOfLines: Int, _ cellData: MasterTimelineCellData) -> CGRect {

		if titleNumberOfLines >= MasterTimelineCellLayout.titleNumberOfLines || cellData.text.isEmpty {
			return CGRect.zero
		}

		return rectOfLineBelow(titleRect, titleRect, 0, cellData.text, MasterTimelineCellLayout.textFont)
	}

	static func rectForText(_ textBoxRect: CGRect, _ cellData: MasterTimelineCellData) -> CGRect {

		var r = textBoxRect

		if cellData.text.isEmpty {
			r.size.height = 0
			return r
		}

		let sizeInfo = MultilineUILabelSizer.size(for: cellData.text, font: MasterTimelineCellLayout.textOnlyFont, numberOfLines: MasterTimelineCellLayout.titleNumberOfLines, width: Int(textBoxRect.width))
		r.size.height = sizeInfo.size.height
		if sizeInfo.numberOfLinesUsed < 1 {
			r.size.height = 0
		}
		return r
	}

	static func rectForDate(_ textBoxRect: CGRect, _ rectAbove: CGRect, _ cellData: MasterTimelineCellData) -> CGRect {

		return rectOfLineBelow(textBoxRect, rectAbove, MasterTimelineCellLayout.titleBottomMargin, cellData.dateString, MasterTimelineCellLayout.dateFont)
	}

	static func rectForFeedName(_ textBoxRect: CGRect, _ dateRect: CGRect, _ cellData: MasterTimelineCellData) -> CGRect {

		if !cellData.showFeedName {
			return CGRect.zero
		}

		return rectOfLineBelow(textBoxRect, dateRect, MasterTimelineCellLayout.dateMarginBottom, cellData.feedName, MasterTimelineCellLayout.feedNameFont)
	}

	static func rectOfLineBelow(_ textBoxRect: CGRect, _ rectAbove: CGRect, _ topMargin: CGFloat, _ value: String, _ font: UIFont) -> CGRect {

		let textFieldSize = SingleLineUILabelSizer.size(for: value, font: font)
		var r = CGRect.zero
		r.size = textFieldSize
		r.origin.y = rectAbove.maxY + topMargin
		r.origin.x = textBoxRect.origin.x

		var width = textFieldSize.width
		width = min(width, textBoxRect.size.width)
		width = max(width, 0.0)
		r.size.width = width

		return r
	}

	static func rectForUnreadIndicator(_ titleRect: CGRect) -> CGRect {

		var r = CGRect.zero
		r.size = CGSize(width: MasterTimelineCellLayout.unreadCircleDimension, height: MasterTimelineCellLayout.unreadCircleDimension)
		r.origin.x = MasterTimelineCellLayout.cellPadding.left
		r.origin.y = titleRect.minY + 6
		return r
		
	}

	static func rectForStar(_ unreadIndicatorRect: CGRect) -> CGRect {

		var r = CGRect.zero
		r.size.width = MasterTimelineCellLayout.starDimension
		r.size.height = MasterTimelineCellLayout.starDimension
		r.origin.x = floor(unreadIndicatorRect.origin.x - ((MasterTimelineCellLayout.starDimension - MasterTimelineCellLayout.unreadCircleDimension) / 2.0))
		r.origin.y = unreadIndicatorRect.origin.y - 4.0
		return r
	}

	static func rectForAvatar(_ cellData: MasterTimelineCellData, _ showAvatar: Bool, _ textBoxRect: CGRect, _ width: CGFloat, _ height: CGFloat) -> CGRect {

		var r = CGRect.zero
		if !showAvatar {
			return r
		}
		
		r.size = MasterTimelineCellLayout.avatarSize
		r.origin.x = (width - MasterTimelineCellLayout.cellPadding.right) - r.size.width
		r.origin.y = textBoxRect.origin.y + 4.0

		return r
	}
}

private extension Array where Element == CGRect {

	func maxY() -> CGFloat {

		var y: CGFloat = 0.0
		self.forEach { y = Swift.max(y, $0.maxY) }
		return y
	}
}

