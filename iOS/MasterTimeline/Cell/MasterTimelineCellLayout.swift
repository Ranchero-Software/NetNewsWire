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

	static let maxNumberOfLines = 2
	static let cellPadding = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
	
	static let unreadCircleMarginLeft = CGFloat(integerLiteral: 8)
	static let unreadCircleDimension = CGFloat(integerLiteral: 8)
	static let unreadCircleMarginRight = CGFloat(integerLiteral: 8)

	static let starDimension = CGFloat(integerLiteral: 13)

	static let avatarSize = CGSize(width: 48.0, height: 48.0)
	static let avatarMarginRight = CGFloat(integerLiteral: 8)
	static let avatarCornerRadius = CGFloat(integerLiteral: 4)

	static let titleColor = AppAssets.timelineTextPrimaryColor
	static let titleFont = UIFont.preferredFont(forTextStyle: .headline)
	static let titleBottomMargin = CGFloat(integerLiteral: 1)
	

	static let feedColor = AppAssets.timelineTextSecondaryColor
	static let feedNameFont = UIFont.preferredFont(forTextStyle: .footnote)
	static let feedRightMargin = CGFloat(integerLiteral: 8)
	
	static let dateColor = AppAssets.timelineTextSecondaryColor
	static let dateFont = UIFont.preferredFont(forTextStyle: .footnote)
	static let dateMarginBottom = CGFloat(integerLiteral: 1)

	static let summaryColor = AppAssets.timelineTextPrimaryColor
	static let summaryFont = UIFont.preferredFont(forTextStyle: .body)

	static let chevronWidth = CGFloat(integerLiteral: 28)

	let width: CGFloat
	let insets: UIEdgeInsets
	
	let height: CGFloat
	let unreadIndicatorRect: CGRect
	let starRect: CGRect
	let avatarImageRect: CGRect
	let titleRect: CGRect
	let summaryRect: CGRect
	let feedNameRect: CGRect
	let dateRect: CGRect

	let separatorInsets: UIEdgeInsets

	init(width: CGFloat, insets: UIEdgeInsets, cellData: MasterTimelineCellData, showAvatar: Bool) {

		self.width = width
		self.insets = insets
		
		var currentPoint = CGPoint.zero
		currentPoint.x = MasterTimelineCellLayout.cellPadding.left + insets.left + MasterTimelineCellLayout.unreadCircleMarginLeft
		currentPoint.y = MasterTimelineCellLayout.cellPadding.top
		
		// Unread Indicator and Star
		self.unreadIndicatorRect = MasterTimelineCellLayout.rectForUnreadIndicator(currentPoint)
		self.starRect = MasterTimelineCellLayout.rectForStar(currentPoint)
		
		// Start the point at the beginning position of the main block
		currentPoint.x += MasterTimelineCellLayout.unreadCircleDimension + MasterTimelineCellLayout.unreadCircleMarginRight
		
		// Separator Insets
		self.separatorInsets = UIEdgeInsets(top: 0, left: currentPoint.x, bottom: 0, right: 0)

		// Avatar
		if showAvatar {
			self.avatarImageRect = MasterTimelineCellLayout.rectForAvatar(currentPoint)
			currentPoint.x = self.avatarImageRect.maxX + MasterTimelineCellLayout.avatarMarginRight
		} else {
			self.avatarImageRect = CGRect.zero
		}
		
		let textAreaWidth = width - (currentPoint.x + MasterTimelineCellLayout.chevronWidth + MasterTimelineCellLayout.cellPadding.right + insets.right)
		
		// Title Text Block
		let (titleRect, numberOfLinesForTitle) = MasterTimelineCellLayout.rectForTitle(cellData, currentPoint, textAreaWidth)
		self.titleRect = titleRect
		
		// Summary Text Block
		if self.titleRect != CGRect.zero {
			currentPoint.y = self.titleRect.maxY + MasterTimelineCellLayout.titleBottomMargin
		}
		self.summaryRect = MasterTimelineCellLayout.rectForSummary(cellData, currentPoint, textAreaWidth, numberOfLinesForTitle)
		
		currentPoint.y = [self.titleRect, self.summaryRect].maxY()
		
		// Feed Name and Pub Date
		self.dateRect = MasterTimelineCellLayout.rectForDate(cellData, currentPoint, textAreaWidth)
		
		let feedNameWidth = textAreaWidth - (MasterTimelineCellLayout.feedRightMargin + self.dateRect.size.width)
		self.feedNameRect = MasterTimelineCellLayout.rectForFeedName(cellData, currentPoint, feedNameWidth)
		
		self.height = [self.avatarImageRect, self.feedNameRect].maxY() + MasterTimelineCellLayout.cellPadding.bottom

	}
	
}

// MARK: - Calculate Rects

private extension MasterTimelineCellLayout {

	static func rectForUnreadIndicator(_ point: CGPoint) -> CGRect {
		var r = CGRect.zero
		r.size = CGSize(width: MasterTimelineCellLayout.unreadCircleDimension, height: MasterTimelineCellLayout.unreadCircleDimension)
		r.origin.x = point.x
		r.origin.y = point.y + 9
		return r
	}


	static func rectForStar(_ point: CGPoint) -> CGRect {
		var r = CGRect.zero
		r.size.width = MasterTimelineCellLayout.starDimension
		r.size.height = MasterTimelineCellLayout.starDimension
		r.origin.x = floor(point.x - ((MasterTimelineCellLayout.starDimension - MasterTimelineCellLayout.unreadCircleDimension) / 2.0))
		r.origin.y = point.y + 5
		return r
	}

	static func rectForAvatar(_ point: CGPoint) -> CGRect {
		var r = CGRect.zero
		r.size = MasterTimelineCellLayout.avatarSize
		r.origin = point
		return r
	}
	
	static func rectForTitle(_ cellData: MasterTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat) -> (CGRect, Int) {
		
		var r = CGRect.zero
		if cellData.title.isEmpty {
			return (r, 0)
		}
		
		r.origin = point
		
		let sizeInfo = MultilineUILabelSizer.size(for: cellData.title, font: MasterTimelineCellLayout.titleFont, numberOfLines: MasterTimelineCellLayout.maxNumberOfLines, width: Int(textAreaWidth))
		
		r.size.width = textAreaWidth
		r.size.height = sizeInfo.size.height
		if sizeInfo.numberOfLinesUsed < 1 {
			r.size.height = 0
		}
		
		return (r, sizeInfo.numberOfLinesUsed)
		
	}

	static func rectForSummary(_ cellData: MasterTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat, _ linesUsed: Int) -> CGRect {
		
		let linesLeft = MasterTimelineCellLayout.maxNumberOfLines - linesUsed
		
		var r = CGRect.zero
		if cellData.summary.isEmpty || linesLeft < 1 {
			return r
		}
		
		r.origin = point
		
		let sizeInfo = MultilineUILabelSizer.size(for: cellData.summary, font: MasterTimelineCellLayout.summaryFont, numberOfLines: linesLeft, width: Int(textAreaWidth))
		
		r.size.width = textAreaWidth
		r.size.height = sizeInfo.size.height
		if sizeInfo.numberOfLinesUsed < 1 {
			r.size.height = 0
		}
		
		return r
		
	}
	
	static func rectForDate(_ cellData: MasterTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat) -> CGRect {
		
		var r = CGRect.zero
		
		let size = SingleLineUILabelSizer.size(for: cellData.dateString, font: MasterTimelineCellLayout.dateFont)
		r.size = size
		r.origin.x = (point.x + textAreaWidth) - size.width
		r.origin.y = point.y

		return r
		
	}
	
	static func rectForFeedName(_ cellData: MasterTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat) -> CGRect {

		var r = CGRect.zero
		r.origin = point
	
		let size = SingleLineUILabelSizer.size(for: cellData.feedName, font: MasterTimelineCellLayout.feedNameFont)
		r.size = size
		
		if r.size.width > textAreaWidth {
			r.size.width = textAreaWidth
		}
		
		return r
		
	}
	
}
