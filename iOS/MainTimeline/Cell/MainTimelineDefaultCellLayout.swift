//
//  MainTimelineDefaultCellLayout.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import UIKit
import RSCore

struct MainTimelineDefaultCellLayout: MainTimelineCellLayout {

	static let cellPadding = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 20)
	
	static let unreadCircleMarginLeft = CGFloat(integerLiteral: 0)
	static let unreadCircleDimension = CGFloat(integerLiteral: 12)
	static let unreadCircleSize = CGSize(width: MainTimelineDefaultCellLayout.unreadCircleDimension, height: MainTimelineDefaultCellLayout.unreadCircleDimension)
	static let unreadCircleMarginRight = CGFloat(integerLiteral: 8)

	static let starDimension = CGFloat(integerLiteral: 16)
	static let starSize = CGSize(width: MainTimelineDefaultCellLayout.starDimension, height: MainTimelineDefaultCellLayout.starDimension)

	static let iconMarginRight = CGFloat(integerLiteral: 8)
	static let iconCornerRadius = CGFloat(integerLiteral: 4)

	static var titleFont: UIFont {
		return UIFont.preferredFont(forTextStyle: .headline)
	}
	static let titleBottomMargin = CGFloat(integerLiteral: 1)

	static var feedNameFont: UIFont {
		return UIFont.preferredFont(forTextStyle: .footnote)
	}
	static let feedRightMargin = CGFloat(integerLiteral: 8)
	
	static var dateFont: UIFont {
		return UIFont.preferredFont(forTextStyle: .footnote)
	}
	static let dateMarginBottom = CGFloat(integerLiteral: 1)

	static var summaryFont: UIFont {
		return UIFont.preferredFont(forTextStyle: .body)
	}

	let height: CGFloat
	let unreadIndicatorRect: CGRect
	let starRect: CGRect
	let iconImageRect: CGRect
	let titleRect: CGRect
	let summaryRect: CGRect
	let feedNameRect: CGRect
	let dateRect: CGRect

	init(width: CGFloat, insets: UIEdgeInsets, cellData: MainTimelineCellData) {

		var currentPoint = CGPoint.zero
		currentPoint.x = MainTimelineDefaultCellLayout.cellPadding.left + insets.left + MainTimelineDefaultCellLayout.unreadCircleMarginLeft
		currentPoint.y = MainTimelineDefaultCellLayout.cellPadding.top

		// Unread Indicator and Star
		self.unreadIndicatorRect = MainTimelineDefaultCellLayout.rectForUnreadIndicator(currentPoint)
		self.starRect = MainTimelineDefaultCellLayout.rectForStar(currentPoint)

		// Start the point at the beginning position of the main block
		currentPoint.x += MainTimelineDefaultCellLayout.unreadCircleDimension + MainTimelineDefaultCellLayout.unreadCircleMarginRight

		// Icon Image
		if cellData.showIcon {
			self.iconImageRect = MainTimelineDefaultCellLayout.rectForIconView(currentPoint, iconSize: cellData.iconSize)
			currentPoint.x = self.iconImageRect.maxX + MainTimelineDefaultCellLayout.iconMarginRight
		} else {
			self.iconImageRect = CGRect.zero
		}
		
		let textAreaWidth = width - (currentPoint.x + MainTimelineDefaultCellLayout.cellPadding.right + insets.right)

		// Title Text Block
		let (titleRect, numberOfLinesForTitle) = MainTimelineDefaultCellLayout.rectForTitle(cellData, currentPoint, textAreaWidth)
		self.titleRect = titleRect
		
		// Summary Text Block
		if self.titleRect != CGRect.zero {
			currentPoint.y = self.titleRect.maxY + MainTimelineDefaultCellLayout.titleBottomMargin
		}
		self.summaryRect = MainTimelineDefaultCellLayout.rectForSummary(cellData, currentPoint, textAreaWidth, numberOfLinesForTitle)

		var y = [self.titleRect, self.summaryRect].maxY()
		if y == 0 {
			y = iconImageRect.origin.y + iconImageRect.height
			// Necessary calculation of either feed name or date since we are working with dynamic font-sizes
			let tmp = MainTimelineDefaultCellLayout.rectForDate(cellData, currentPoint, textAreaWidth)
			y -= tmp.height
		}
		currentPoint.y = y
		
		// Feed Name and Pub Date
		self.dateRect = MainTimelineDefaultCellLayout.rectForDate(cellData, currentPoint, textAreaWidth)

		let feedNameWidth = textAreaWidth - (MainTimelineDefaultCellLayout.feedRightMargin + self.dateRect.size.width)
		self.feedNameRect = MainTimelineDefaultCellLayout.rectForFeedName(cellData, currentPoint, feedNameWidth)

		self.height = [self.iconImageRect, self.feedNameRect].maxY() + MainTimelineDefaultCellLayout.cellPadding.bottom

	}
	
}

// MARK: - Calculate Rects

extension MainTimelineDefaultCellLayout {

	static func rectForDate(_ cellData: MainTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat) -> CGRect {

		var r = CGRect.zero
		
		let size = SingleLineUILabelSizer.size(for: cellData.dateString, font: MainTimelineDefaultCellLayout.dateFont)
		r.size = size
		r.origin.x = (point.x + textAreaWidth) - size.width
		r.origin.y = point.y

		return r
		
	}
	
}
