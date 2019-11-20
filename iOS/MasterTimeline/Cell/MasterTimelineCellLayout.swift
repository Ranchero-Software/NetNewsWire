//
//  MasterTimelineCellLayout.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

protocol MasterTimelineCellLayout {
	
	var height: CGFloat {get}
	var unreadIndicatorRect: CGRect {get}
	var starRect: CGRect {get}
	var iconImageRect: CGRect {get}
	var titleRect: CGRect {get}
	var summaryRect: CGRect {get}
	var feedNameRect: CGRect {get}
	var dateRect: CGRect {get}
	var separatorInsets: UIEdgeInsets {get}
	
}

extension MasterTimelineCellLayout {
	
	static func rectForUnreadIndicator(_ point: CGPoint) -> CGRect {
		var r = CGRect.zero
		r.size = CGSize(width: MasterTimelineDefaultCellLayout.unreadCircleDimension, height: MasterTimelineDefaultCellLayout.unreadCircleDimension)
		r.origin.x = point.x
		r.origin.y = point.y + 5
		return r
	}
	
	
	static func rectForStar(_ point: CGPoint) -> CGRect {
		var r = CGRect.zero
		r.size.width = MasterTimelineDefaultCellLayout.starDimension
		r.size.height = MasterTimelineDefaultCellLayout.starDimension
		r.origin.x = floor(point.x - ((MasterTimelineDefaultCellLayout.starDimension - MasterTimelineDefaultCellLayout.unreadCircleDimension) / 2.0))
		r.origin.y = point.y + 3
		return r
	}
	
	static func rectForIconView(_ point: CGPoint, iconSize: IconSize) -> CGRect {
		var r = CGRect.zero
		r.size = iconSize.size
		r.origin.x = point.x
		r.origin.y = point.y + 4
		return r
	}
	
	static func rectForTitle(_ cellData: MasterTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat) -> (CGRect, Int) {
		
		var r = CGRect.zero
		if cellData.title.isEmpty {
			return (r, 0)
		}
		
		r.origin = point
		
		let sizeInfo = MultilineUILabelSizer.size(for: cellData.title, font: MasterTimelineDefaultCellLayout.titleFont, numberOfLines: cellData.numberOfLines, width: Int(textAreaWidth))
		
		r.size.width = textAreaWidth
		r.size.height = sizeInfo.size.height
		if sizeInfo.numberOfLinesUsed < 1 {
			r.size.height = 0
		}
		
		return (r, sizeInfo.numberOfLinesUsed)
		
	}
	
	static func rectForSummary(_ cellData: MasterTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat, _ linesUsed: Int) -> CGRect {
		
		let linesLeft = cellData.numberOfLines - linesUsed
		
		var r = CGRect.zero
		if cellData.summary.isEmpty || linesLeft < 1 {
			return r
		}
		
		r.origin = point
		
		let sizeInfo = MultilineUILabelSizer.size(for: cellData.summary, font: MasterTimelineDefaultCellLayout.summaryFont, numberOfLines: linesLeft, width: Int(textAreaWidth))
		
		r.size.width = textAreaWidth
		r.size.height = sizeInfo.size.height
		if sizeInfo.numberOfLinesUsed < 1 {
			r.size.height = 0
		}
		
		return r
		
	}

	static func rectForFeedName(_ cellData: MasterTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat) -> CGRect {
		
		var r = CGRect.zero
		r.origin = point
		
		let size = SingleLineUILabelSizer.size(for: cellData.feedName, font: MasterTimelineDefaultCellLayout.feedNameFont)
		r.size = size
		
		if r.size.width > textAreaWidth {
			r.size.width = textAreaWidth
		}
		
		return r
		
	}
	
}
