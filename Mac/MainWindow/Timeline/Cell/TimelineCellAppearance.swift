//
//  TimelineCellAppearance.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit

struct TimelineCellAppearance: Equatable {

	let showIcon: Bool

	let cellPadding = NSEdgeInsets(top: 8.0, left: 18.0, bottom: 10.0, right: 18.0)
	
	let feedNameFont: NSFont

	let dateFont: NSFont
	let dateMarginLeft: CGFloat = 8.0

	let titleFont: NSFont
	let titleBottomMargin: CGFloat = 1.0
	let titleNumberOfLines = 3
	
	let textFont: NSFont

	let textOnlyFont: NSFont

	let unreadCircleDimension: CGFloat = 8.0
	let unreadCircleMarginRight: CGFloat = 8.0

	let starDimension: CGFloat = 13.0

	let drawsGrid = false

	let iconSize = NSSize(width: 48, height: 48)
	let iconMarginLeft: CGFloat = 8.0
	let iconMarginRight: CGFloat = 8.0
	let iconAdjustmentTop: CGFloat = 4.0
	let iconCornerRadius: CGFloat = 4.0

	let boxLeftMargin: CGFloat

	init(showIcon: Bool, fontSize: FontSize) {

		let actualFontSize = AppDefaults.actualFontSize(for: fontSize)
		let smallItemFontSize = floor(actualFontSize * 0.90)
		let largeItemFontSize = actualFontSize

		self.feedNameFont = NSFont.systemFont(ofSize: smallItemFontSize)
		self.dateFont = NSFont.systemFont(ofSize: smallItemFontSize)
		self.titleFont = NSFont.systemFont(ofSize: largeItemFontSize, weight: NSFont.Weight.semibold)
		self.textFont = NSFont.systemFont(ofSize: largeItemFontSize, weight: NSFont.Weight.light)
		self.textOnlyFont = NSFont.systemFont(ofSize: largeItemFontSize)

		self.showIcon = showIcon

		let margin = self.cellPadding.left + self.unreadCircleDimension + self.unreadCircleMarginRight
		self.boxLeftMargin = margin
	}
}

extension NSEdgeInsets: Equatable {

	public static func ==(lhs: NSEdgeInsets, rhs: NSEdgeInsets) -> Bool {
		return lhs.left == rhs.left && lhs.top == rhs.top && lhs.right == rhs.right && lhs.bottom == rhs.bottom
	}
}
