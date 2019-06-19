//
//  MasterTimelineDefaultCellLayout.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import UIKit
import RSCore

struct MasterTimelineDefaultCellLayout: MasterTimelineCellLayout {

	static let cellPadding = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 16)
	
	static let unreadCircleMarginLeft = CGFloat(integerLiteral: 0)
	static let unreadCircleDimension = CGFloat(integerLiteral: 12)
	static let unreadCircleMarginRight = CGFloat(integerLiteral: 8)

	static let starDimension = CGFloat(integerLiteral: 16)

	static let avatarSize = CGSize(width: 48.0, height: 48.0)
	static let avatarMarginRight = CGFloat(integerLiteral: 8)
	static let avatarCornerRadius = CGFloat(integerLiteral: 4)

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

	static let chevronWidth = CGFloat(integerLiteral: 28)

	let height: CGFloat
	let unreadIndicatorRect: CGRect
	let starRect: CGRect
	let avatarImageRect: CGRect
	let titleRect: CGRect
	let summaryRect: CGRect
	let feedNameRect: CGRect
	let dateRect: CGRect
	let separatorInsets: UIEdgeInsets

	init(width: CGFloat, insets: UIEdgeInsets, cellData: MasterTimelineCellData) {

		var currentPoint = CGPoint.zero
		currentPoint.x = MasterTimelineDefaultCellLayout.cellPadding.left + insets.left + MasterTimelineDefaultCellLayout.unreadCircleMarginLeft
		currentPoint.y = MasterTimelineDefaultCellLayout.cellPadding.top
		
		// Unread Indicator and Star
		self.unreadIndicatorRect = MasterTimelineDefaultCellLayout.rectForUnreadIndicator(currentPoint)
		self.starRect = MasterTimelineDefaultCellLayout.rectForStar(currentPoint)
		
		// Start the point at the beginning position of the main block
		currentPoint.x += MasterTimelineDefaultCellLayout.unreadCircleDimension + MasterTimelineDefaultCellLayout.unreadCircleMarginRight
		
		// Separator Insets
		self.separatorInsets = UIEdgeInsets(top: 0, left: currentPoint.x, bottom: 0, right: 0)

		// Avatar
		if cellData.showAvatar {
			self.avatarImageRect = MasterTimelineDefaultCellLayout.rectForAvatar(currentPoint)
			currentPoint.x = self.avatarImageRect.maxX + MasterTimelineDefaultCellLayout.avatarMarginRight
		} else {
			self.avatarImageRect = CGRect.zero
		}
		
		let textAreaWidth = width - (currentPoint.x + MasterTimelineDefaultCellLayout.chevronWidth + MasterTimelineDefaultCellLayout.cellPadding.right + insets.right)
		
		// Title Text Block
		let (titleRect, numberOfLinesForTitle) = MasterTimelineDefaultCellLayout.rectForTitle(cellData, currentPoint, textAreaWidth)
		self.titleRect = titleRect
		
		// Summary Text Block
		if self.titleRect != CGRect.zero {
			currentPoint.y = self.titleRect.maxY + MasterTimelineDefaultCellLayout.titleBottomMargin
		}
		self.summaryRect = MasterTimelineDefaultCellLayout.rectForSummary(cellData, currentPoint, textAreaWidth, numberOfLinesForTitle)
		
		currentPoint.y = [self.titleRect, self.summaryRect].maxY()
		
		// Feed Name and Pub Date
		self.dateRect = MasterTimelineDefaultCellLayout.rectForDate(cellData, currentPoint, textAreaWidth)
		
		let feedNameWidth = textAreaWidth - (MasterTimelineDefaultCellLayout.feedRightMargin + self.dateRect.size.width)
		self.feedNameRect = MasterTimelineDefaultCellLayout.rectForFeedName(cellData, currentPoint, feedNameWidth)
		
		self.height = [self.avatarImageRect, self.feedNameRect].maxY() + MasterTimelineDefaultCellLayout.cellPadding.bottom

	}
	
}

// MARK: - Calculate Rects

extension MasterTimelineDefaultCellLayout {

	static func rectForDate(_ cellData: MasterTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat) -> CGRect {
		
		var r = CGRect.zero
		
		let size = SingleLineUILabelSizer.size(for: cellData.dateString, font: MasterTimelineDefaultCellLayout.dateFont)
		r.size = size
		r.origin.x = (point.x + textAreaWidth) - size.width
		r.origin.y = point.y

		return r
		
	}
	
}
