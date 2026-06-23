//
//  MainTimelineCellLayout.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import Images

@MainActor protocol MainTimelineCellLayout {
	var height: CGFloat { get }
	var unreadIndicatorRect: CGRect { get }
	var starRect: CGRect { get }
	var iconImageRect: CGRect { get }
	var titleRect: CGRect { get }
	var summaryRect: CGRect { get }
	var feedNameRect: CGRect { get }
	var dateRect: CGRect { get }
	var separatorRect: CGRect { get }
}

extension MainTimelineCellLayout {

	static func rectForUnreadIndicator(_ point: CGPoint) -> CGRect {
		var r = CGRect.zero
		r.size = CGSize(width: MainTimelineDefaultCellLayout.unreadCircleDimension, height: MainTimelineDefaultCellLayout.unreadCircleDimension)
		r.origin.x = point.x
		r.origin.y = point.y + 5
		return r
	}

	static func rectForStar(_ point: CGPoint) -> CGRect {
		var r = CGRect.zero
		r.size.width = MainTimelineDefaultCellLayout.starDimension
		r.size.height = MainTimelineDefaultCellLayout.starDimension
		r.origin.x = floor(point.x - ((MainTimelineDefaultCellLayout.starDimension - MainTimelineDefaultCellLayout.unreadCircleDimension) / 2.0))
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

	static func rectForTitle(_ cellData: MainTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat) -> (CGRect, Int) {
		var r = CGRect.zero
		if cellData.title.isEmpty {
			return (r, 0)
		}
		r.origin = point
		let sizeInfo = MultilineUILabelSizer.size(for: cellData.title, font: MainTimelineDefaultCellLayout.titleFont, numberOfLines: cellData.numberOfLines, width: Int(textAreaWidth))
		r.size.width = textAreaWidth
		r.size.height = sizeInfo.size.height
		if sizeInfo.numberOfLinesUsed < 1 {
			r.size.height = 0
		}
		return (r, sizeInfo.numberOfLinesUsed)
	}

	static func rectForSummary(_ cellData: MainTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat, _ linesUsed: Int) -> CGRect {
		let linesLeft = cellData.numberOfLines - linesUsed
		var r = CGRect.zero
		if cellData.summary.isEmpty || linesLeft < 1 {
			return r
		}
		r.origin = point
		let sizeInfo = MultilineUILabelSizer.size(for: cellData.summary, font: MainTimelineDefaultCellLayout.summaryFont, numberOfLines: linesLeft, width: Int(textAreaWidth))
		r.size.width = textAreaWidth
		r.size.height = sizeInfo.size.height
		if sizeInfo.numberOfLinesUsed < 1 {
			r.size.height = 0
		}
		return r
	}

	static func rectForFeedName(_ cellData: MainTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat) -> CGRect {
		var r = CGRect.zero
		r.origin = point
		let feedName = cellData.showFeedName == .feed ? cellData.feedName : cellData.byline
		let size = SingleLineUILabelSizer.size(for: feedName, font: MainTimelineDefaultCellLayout.feedNameFont)
		r.size = size
		if r.size.width > textAreaWidth {
			r.size.width = textAreaWidth
		}
		return r
	}
}

// MARK: - Default

struct MainTimelineDefaultCellLayout: MainTimelineCellLayout {

	static let cellPadding = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 20)

	static let unreadCircleMarginLeft = CGFloat(0)
	static let unreadCircleDimension = CGFloat(12)
	static let unreadCircleMarginRight = CGFloat(8)

	static let starDimension = CGFloat(16)

	static let iconMarginRight = CGFloat(8)
	static let iconCornerRadius = CGFloat(4)

	static var titleFont: UIFont { UIFont.preferredFont(forTextStyle: .headline) }
	static let titleBottomMargin = CGFloat(1)

	static var feedNameFont: UIFont { UIFont.preferredFont(forTextStyle: .footnote) }
	static let feedRightMargin = CGFloat(8)

	static var dateFont: UIFont { UIFont.preferredFont(forTextStyle: .footnote) }
	static let dateMarginBottom = CGFloat(1)

	static var summaryFont: UIFont { UIFont.preferredFont(forTextStyle: .body) }

	let height: CGFloat
	let unreadIndicatorRect: CGRect
	let starRect: CGRect
	let iconImageRect: CGRect
	let titleRect: CGRect
	let summaryRect: CGRect
	let feedNameRect: CGRect
	let dateRect: CGRect
	let separatorRect: CGRect

	init(width: CGFloat, insets: UIEdgeInsets, cellData: MainTimelineCellData) {

		var currentPoint = CGPoint.zero
		currentPoint.x = Self.cellPadding.left + insets.left + Self.unreadCircleMarginLeft
		currentPoint.y = Self.cellPadding.top

		self.unreadIndicatorRect = Self.rectForUnreadIndicator(currentPoint)
		self.starRect = Self.rectForStar(currentPoint)

		currentPoint.x += Self.unreadCircleDimension + Self.unreadCircleMarginRight

		if cellData.showIcon {
			self.iconImageRect = Self.rectForIconView(currentPoint, iconSize: cellData.iconSize)
			currentPoint.x = self.iconImageRect.maxX + Self.iconMarginRight
		} else {
			self.iconImageRect = CGRect.zero
		}

		let textAreaWidth = width - (currentPoint.x + Self.cellPadding.right + insets.right)
		self.separatorRect = CGRect(x: currentPoint.x, y: 0, width: textAreaWidth, height: 0)

		let (titleRect, numberOfLinesForTitle) = Self.rectForTitle(cellData, currentPoint, textAreaWidth)
		self.titleRect = titleRect

		if self.titleRect != CGRect.zero {
			currentPoint.y = self.titleRect.maxY + Self.titleBottomMargin
		}
		self.summaryRect = Self.rectForSummary(cellData, currentPoint, textAreaWidth, numberOfLinesForTitle)

		var y = [self.titleRect, self.summaryRect].maxY()
		if y == 0 {
			y = iconImageRect.origin.y + iconImageRect.height
			let tmp = Self.rectForDate(cellData, currentPoint, textAreaWidth)
			y -= tmp.height
		}
		currentPoint.y = y

		self.dateRect = Self.rectForDate(cellData, currentPoint, textAreaWidth)

		let feedNameWidth = textAreaWidth - (Self.feedRightMargin + self.dateRect.size.width)
		self.feedNameRect = Self.rectForFeedName(cellData, currentPoint, feedNameWidth)

		self.height = [self.iconImageRect, self.feedNameRect].maxY() + Self.cellPadding.bottom
	}

	static func rectForDate(_ cellData: MainTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat) -> CGRect {
		var r = CGRect.zero
		let size = SingleLineUILabelSizer.size(for: cellData.dateString, font: Self.dateFont)
		r.size = size
		r.origin.x = (point.x + textAreaWidth) - size.width
		r.origin.y = point.y
		return r
	}
}

// MARK: - Accessibility

struct MainTimelineAccessibilityCellLayout: MainTimelineCellLayout {

	let height: CGFloat
	let unreadIndicatorRect: CGRect
	let starRect: CGRect
	let iconImageRect: CGRect
	let titleRect: CGRect
	let summaryRect: CGRect
	let feedNameRect: CGRect
	let dateRect: CGRect
	let separatorRect: CGRect

	init(width: CGFloat, insets: UIEdgeInsets, cellData: MainTimelineCellData) {

		var currentPoint = CGPoint.zero
		currentPoint.x = MainTimelineDefaultCellLayout.cellPadding.left + insets.left + MainTimelineDefaultCellLayout.unreadCircleMarginLeft
		currentPoint.y = MainTimelineDefaultCellLayout.cellPadding.top

		self.unreadIndicatorRect = Self.rectForUnreadIndicator(currentPoint)
		self.starRect = Self.rectForStar(currentPoint)

		currentPoint.x += MainTimelineDefaultCellLayout.unreadCircleDimension + MainTimelineDefaultCellLayout.unreadCircleMarginRight

		if cellData.showIcon {
			self.iconImageRect = Self.rectForIconView(currentPoint, iconSize: cellData.iconSize)
			currentPoint.y = self.iconImageRect.maxY
		} else {
			self.iconImageRect = CGRect.zero
		}

		let textAreaWidth = width - (currentPoint.x + MainTimelineDefaultCellLayout.cellPadding.right + insets.right)
		self.separatorRect = CGRect(x: currentPoint.x, y: 0, width: textAreaWidth, height: 0)

		let (titleRect, numberOfLinesForTitle) = Self.rectForTitle(cellData, currentPoint, textAreaWidth)
		self.titleRect = titleRect

		if self.titleRect != CGRect.zero {
			currentPoint.y = self.titleRect.maxY + MainTimelineDefaultCellLayout.titleBottomMargin
		}
		self.summaryRect = Self.rectForSummary(cellData, currentPoint, textAreaWidth, numberOfLinesForTitle)

		currentPoint.y = [self.titleRect, self.summaryRect].maxY()

		if cellData.showFeedName != .none {
			self.feedNameRect = Self.rectForFeedName(cellData, currentPoint, textAreaWidth)
			currentPoint.y = self.feedNameRect.maxY
		} else {
			self.feedNameRect = CGRect.zero
		}

		self.dateRect = Self.rectForDate(cellData, currentPoint, textAreaWidth)

		self.height = self.dateRect.maxY + MainTimelineDefaultCellLayout.cellPadding.bottom
	}

	static func rectForDate(_ cellData: MainTimelineCellData, _ point: CGPoint, _ textAreaWidth: CGFloat) -> CGRect {
		var r = CGRect.zero
		let size = SingleLineUILabelSizer.size(for: cellData.dateString, font: MainTimelineDefaultCellLayout.dateFont)
		r.size = size
		r.origin = point
		return r
	}
}
