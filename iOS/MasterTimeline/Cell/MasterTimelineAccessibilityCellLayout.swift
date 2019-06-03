//
//  MasterTimelineAccessibilityCellLayout.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore

struct MasterTimelineAccessibilityCellLayout: MasterTimelineCellLayout {
	
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
		self.unreadIndicatorRect = MasterTimelineAccessibilityCellLayout.rectForUnreadIndicator(currentPoint)
		self.starRect = MasterTimelineAccessibilityCellLayout.rectForStar(currentPoint)
		
		// Start the point at the beginning position of the main block
		currentPoint.x += MasterTimelineDefaultCellLayout.unreadCircleDimension + MasterTimelineDefaultCellLayout.unreadCircleMarginRight
		
		// Separator Insets
		self.separatorInsets = UIEdgeInsets(top: 0, left: currentPoint.x, bottom: 0, right: 0)
		
		// Avatar
		if cellData.showAvatar {
			self.avatarImageRect = MasterTimelineAccessibilityCellLayout.rectForAvatar(currentPoint)
			currentPoint.y = self.avatarImageRect.maxY
		} else {
			self.avatarImageRect = CGRect.zero
		}
		
		let textAreaWidth = width - (currentPoint.x + MasterTimelineDefaultCellLayout.chevronWidth + MasterTimelineDefaultCellLayout.cellPadding.right + insets.right)
		
		// Title Text Block
		let (titleRect, numberOfLinesForTitle) = MasterTimelineAccessibilityCellLayout.rectForTitle(cellData, currentPoint, textAreaWidth)
		self.titleRect = titleRect
		
		// Summary Text Block
		if self.titleRect != CGRect.zero {
			currentPoint.y = self.titleRect.maxY + MasterTimelineDefaultCellLayout.titleBottomMargin
		}
		self.summaryRect = MasterTimelineAccessibilityCellLayout.rectForSummary(cellData, currentPoint, textAreaWidth, numberOfLinesForTitle)
		
		currentPoint.y = [self.titleRect, self.summaryRect].maxY()
		
		if cellData.showFeedName {
			self.feedNameRect = MasterTimelineAccessibilityCellLayout.rectForFeedName(cellData, currentPoint, textAreaWidth)
			currentPoint.y = self.feedNameRect.maxY
		} else {
			self.feedNameRect = CGRect.zero
		}
		
		// Feed Name and Pub Date
		self.dateRect = MasterTimelineAccessibilityCellLayout.rectForDate(cellData, currentPoint, textAreaWidth)
		
		self.height = self.dateRect.maxY + MasterTimelineDefaultCellLayout.cellPadding.bottom
		
	}
	
}

// MARK: - Calculate Rects

private extension MasterTimelineAccessibilityCellLayout {
	
	static func rectForDate(_ cellData: MasterTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat) -> CGRect {
		
		var r = CGRect.zero
		
		let size = SingleLineUILabelSizer.size(for: cellData.dateString, font: MasterTimelineDefaultCellLayout.dateFont)
		r.size = size
		r.origin = point
		
		return r
		
	}
	
}
