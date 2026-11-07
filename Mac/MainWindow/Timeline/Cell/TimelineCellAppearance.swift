//
//  TimelineCellAppearance.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import Images

struct TimelineCellAppearance: Equatable {

	let showIcon: Bool
	let showsLargeThumbnails: Bool

	let cellPadding: NSEdgeInsets

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

	let iconSize: NSSize
	let iconMarginLeft: CGFloat = 8.0
	let iconMarginRight: CGFloat = 8.0
	let iconAdjustmentTop: CGFloat = 4.0
	let iconCornerRadius: CGFloat = 4.0

	let thumbnailMaximumDimension: CGFloat = 76.0 // Smaller when the row is too short
	let thumbnailMarginLeft: CGFloat = 8.0
	let thumbnailCornerRadius: CGFloat = 4.0
	let largeThumbnailMarginTop: CGFloat = 8.0
	let largeThumbnailHeight: CGFloat = 180.0

	let boxLeftMargin: CGFloat

	init(showIcon: Bool, textSize: TimelineTextSize, iconSize: IconSize, showsLargeThumbnails: Bool) {

		let largeItemFontSize = textSize.pointSize
		let smallItemFontSize = floor(largeItemFontSize * 0.90)

		self.feedNameFont = NSFont.systemFont(ofSize: smallItemFontSize, weight: NSFont.Weight.bold)
		self.dateFont = NSFont.systemFont(ofSize: smallItemFontSize, weight: NSFont.Weight.bold)
		self.titleFont = NSFont.systemFont(ofSize: largeItemFontSize, weight: NSFont.Weight.semibold)
		self.textFont = NSFont.systemFont(ofSize: largeItemFontSize)
		self.textOnlyFont = NSFont.systemFont(ofSize: largeItemFontSize)

		self.showIcon = showIcon
		self.iconSize = iconSize.size
		self.showsLargeThumbnails = showsLargeThumbnails

		cellPadding = NSEdgeInsets(top: 8.0, left: 4.0, bottom: 10.0, right: 4.0)

		let margin = self.cellPadding.left + self.unreadCircleDimension + self.unreadCircleMarginRight
		self.boxLeftMargin = margin
	}
}

extension TimelineTextSize {

	private static let smallPointSize: CGFloat = 12
	private static let mediumPointSize: CGFloat = 14
	private static let largePointSize: CGFloat = 16
	private static let extraLargePointSize: CGFloat = 19
	private static let extraExtraLargePointSize: CGFloat = 22

	var pointSize: CGFloat {
		switch self {
		case .small:
			Self.smallPointSize
		case .medium:
			Self.mediumPointSize
		case .large:
			Self.largePointSize
		case .extraLarge:
			Self.extraLargePointSize
		case .extraExtraLarge:
			Self.extraExtraLargePointSize
		}
	}
}

extension NSEdgeInsets: @retroactive Equatable {

	public static func ==(lhs: NSEdgeInsets, rhs: NSEdgeInsets) -> Bool {
		return lhs.left == rhs.left && lhs.top == rhs.top && lhs.right == rhs.right && lhs.bottom == rhs.bottom
	}
}
