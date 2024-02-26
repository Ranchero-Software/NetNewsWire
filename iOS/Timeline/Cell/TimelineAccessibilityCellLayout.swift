//
//  TimelineAccessibilityCellLayout.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore

struct TimelineAccessibilityCellLayout: TimelineCellLayout {
	
	let height: CGFloat
	let unreadIndicatorRect: CGRect
	let starRect: CGRect
	let iconImageRect: CGRect
	let titleRect: CGRect
	let summaryRect: CGRect
	let feedNameRect: CGRect
	let dateRect: CGRect
	
	init(width: CGFloat, insets: UIEdgeInsets, cellData: TimelineCellData) {
		
		var currentPoint = CGPoint.zero
		currentPoint.x = TimelineDefaultCellLayout.cellPadding.left + insets.left + TimelineDefaultCellLayout.unreadCircleMarginLeft
		currentPoint.y = TimelineDefaultCellLayout.cellPadding.top
		
		// Unread Indicator and Star
		self.unreadIndicatorRect = TimelineAccessibilityCellLayout.rectForUnreadIndicator(currentPoint)
		self.starRect = TimelineAccessibilityCellLayout.rectForStar(currentPoint)
		
		// Start the point at the beginning position of the main block
		currentPoint.x += TimelineDefaultCellLayout.unreadCircleDimension + TimelineDefaultCellLayout.unreadCircleMarginRight
		
		// Icon Image
		if cellData.showIcon {
			self.iconImageRect = TimelineAccessibilityCellLayout.rectForIconView(currentPoint, iconSize: cellData.iconSize)
			currentPoint.y = self.iconImageRect.maxY
		} else {
			self.iconImageRect = CGRect.zero
		}
		
		let textAreaWidth = width - (currentPoint.x + TimelineDefaultCellLayout.cellPadding.right + insets.right)
		
		// Title Text Block
		let (titleRect, numberOfLinesForTitle) = TimelineAccessibilityCellLayout.rectForTitle(cellData, currentPoint, textAreaWidth)
		self.titleRect = titleRect
		
		// Summary Text Block
		if self.titleRect != CGRect.zero {
			currentPoint.y = self.titleRect.maxY + TimelineDefaultCellLayout.titleBottomMargin
		}
		self.summaryRect = TimelineAccessibilityCellLayout.rectForSummary(cellData, currentPoint, textAreaWidth, numberOfLinesForTitle)
		
		currentPoint.y = [self.titleRect, self.summaryRect].maxY()
		
		if cellData.showFeedName != .none {
			self.feedNameRect = TimelineAccessibilityCellLayout.rectForFeedName(cellData, currentPoint, textAreaWidth)
			currentPoint.y = self.feedNameRect.maxY
		} else {
			self.feedNameRect = CGRect.zero
		}
		
		// Feed Name and Pub Date
		self.dateRect = TimelineAccessibilityCellLayout.rectForDate(cellData, currentPoint, textAreaWidth)
		
		self.height = self.dateRect.maxY + TimelineDefaultCellLayout.cellPadding.bottom
		
	}
	
}

// MARK: - Calculate Rects

private extension TimelineAccessibilityCellLayout {
	
	static func rectForDate(_ cellData: TimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat) -> CGRect {
		
		var r = CGRect.zero
		
		let size = SingleLineUILabelSizer.size(for: cellData.dateString, font: TimelineDefaultCellLayout.dateFont)
		r.size = size
		r.origin = point
		
		return r
		
	}
	
}
