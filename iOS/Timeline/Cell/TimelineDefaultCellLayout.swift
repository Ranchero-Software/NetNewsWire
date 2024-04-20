//
//  TimelineDefaultCellLayout.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import UIKit

struct TimelineDefaultCellLayout: TimelineCellLayout {

	static let cellPadding = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 20)
	
	static let unreadCircleMarginLeft = CGFloat(integerLiteral: 0)
	static let unreadCircleDimension = CGFloat(integerLiteral: 12)
	static let unreadCircleSize = CGSize(width: TimelineDefaultCellLayout.unreadCircleDimension, height: TimelineDefaultCellLayout.unreadCircleDimension)
	static let unreadCircleMarginRight = CGFloat(integerLiteral: 8)

	static let starDimension = CGFloat(integerLiteral: 16)
	static let starSize = CGSize(width: TimelineDefaultCellLayout.starDimension, height: TimelineDefaultCellLayout.starDimension)

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

	@MainActor init(width: CGFloat, insets: UIEdgeInsets, cellData: TimelineCellData) {

		var currentPoint = CGPoint.zero
		currentPoint.x = TimelineDefaultCellLayout.cellPadding.left + insets.left + TimelineDefaultCellLayout.unreadCircleMarginLeft
		currentPoint.y = TimelineDefaultCellLayout.cellPadding.top
		
		// Unread Indicator and Star
		self.unreadIndicatorRect = TimelineDefaultCellLayout.rectForUnreadIndicator(currentPoint)
		self.starRect = TimelineDefaultCellLayout.rectForStar(currentPoint)
		
		// Start the point at the beginning position of the main block
		currentPoint.x += TimelineDefaultCellLayout.unreadCircleDimension + TimelineDefaultCellLayout.unreadCircleMarginRight
		
		// Icon Image
		if cellData.showIcon {
			self.iconImageRect = TimelineDefaultCellLayout.rectForIconView(currentPoint, iconSize: cellData.iconSize)
			currentPoint.x = self.iconImageRect.maxX + TimelineDefaultCellLayout.iconMarginRight
		} else {
			self.iconImageRect = CGRect.zero
		}
		
		let textAreaWidth = width - (currentPoint.x + TimelineDefaultCellLayout.cellPadding.right + insets.right)
		
		// Title Text Block
		let (titleRect, numberOfLinesForTitle) = TimelineDefaultCellLayout.rectForTitle(cellData, currentPoint, textAreaWidth)
		self.titleRect = titleRect
		
		// Summary Text Block
		if self.titleRect != CGRect.zero {
			currentPoint.y = self.titleRect.maxY + TimelineDefaultCellLayout.titleBottomMargin
		}
		self.summaryRect = TimelineDefaultCellLayout.rectForSummary(cellData, currentPoint, textAreaWidth, numberOfLinesForTitle)
		
		var y = [self.titleRect, self.summaryRect].maxY()
		if y == 0 {
			y = iconImageRect.origin.y + iconImageRect.height
			// Necessary calculation of either feed name or date since we are working with dynamic font-sizes
			let tmp = TimelineDefaultCellLayout.rectForDate(cellData, currentPoint, textAreaWidth)
			y -= tmp.height
		}
		currentPoint.y = y
		
		// Feed Name and Pub Date
		self.dateRect = TimelineDefaultCellLayout.rectForDate(cellData, currentPoint, textAreaWidth)
		
		let feedNameWidth = textAreaWidth - (TimelineDefaultCellLayout.feedRightMargin + self.dateRect.size.width)
		self.feedNameRect = TimelineDefaultCellLayout.rectForFeedName(cellData, currentPoint, feedNameWidth)
		
		self.height = [self.iconImageRect, self.feedNameRect].maxY() + TimelineDefaultCellLayout.cellPadding.bottom

	}
	
}

// MARK: - Calculate Rects

extension TimelineDefaultCellLayout {

	static func rectForDate(_ cellData: TimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat) -> CGRect {
		
		var r = CGRect.zero
		
		let size = SingleLineUILabelSizer.size(for: cellData.dateString, font: TimelineDefaultCellLayout.dateFont)
		r.size = size
		r.origin.x = (point.x + textAreaWidth) - size.width
		r.origin.y = point.y

		return r
		
	}
	
}
