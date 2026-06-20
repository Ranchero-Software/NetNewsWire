//
//  TimelineModernCellLayout.swift
//  NetNewsWire
//
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore

// Rects for the modern timeline cell. Table-view cells in NetNewsWire use manual
// frame layout (not Auto Layout), so this computes every subview frame.
@MainActor
struct TimelineModernCellLayout {

	let feedIconRect: NSRect
	let metadataRect: NSRect
	let titleRect: NSRect
	let summaryRect: NSRect
	let thumbnailRect: NSRect
	let separatorRect: NSRect
	let height: CGFloat

	private static let horizontalPadding: CGFloat = 16.0
	private static let verticalPadding: CGFloat = 12.0
	private static let thumbnailSize: CGFloat = 72.0
	private static let leftRightGap: CGFloat = 12.0
	private static let iconHeight: CGFloat = 20.0
	private static let iconToTitleGap: CGFloat = 6.0
	private static let titleToSummaryGap: CGFloat = 4.0
	private static let iconToMetadataGap: CGFloat = 8.0

	init(width: CGFloat, cellData: TimelineCellData) {
		let titleFont = NSFont.systemFont(ofSize: 14, weight: .semibold)
		let summaryFont = NSFont.systemFont(ofSize: 12, weight: .regular)

		let hasThumbnail = cellData.thumbnailURL != nil
		let availableWidth = width - Self.horizontalPadding * 2
		let leftWidth = hasThumbnail ? (availableWidth - Self.thumbnailSize - Self.leftRightGap) : availableWidth
		let leftWidthInt = max(1, Int(leftWidth))

		// Coordinates run top-down (the cell view is flipped).
		var y = Self.verticalPadding

		self.feedIconRect = NSRect(x: Self.horizontalPadding, y: y, width: Self.iconHeight, height: Self.iconHeight)

		let metadataX = self.feedIconRect.maxX + Self.iconToMetadataGap
		self.metadataRect = NSRect(x: metadataX, y: y, width: width - metadataX - Self.horizontalPadding, height: Self.iconHeight)

		y = self.feedIconRect.maxY + Self.iconToTitleGap

		// Title (up to 2 lines); its actual line count drives the summary line count.
		let titleInfo = MultilineTextFieldSizer.size(for: cellData.title, font: titleFont, numberOfLines: 2, width: leftWidthInt)
		let titleLines = max(1, titleInfo.numberOfLinesUsed)
		self.titleRect = NSRect(x: Self.horizontalPadding, y: y, width: leftWidth, height: titleInfo.size.height)

		y = self.titleRect.maxY + Self.titleToSummaryGap

		// Summary: 1 line when the title is 2 lines, otherwise 2 lines.
		let summaryLines = titleLines >= 2 ? 1 : 2
		let summaryHeight = MultilineTextFieldSizer.size(for: cellData.text, font: summaryFont, numberOfLines: summaryLines, width: leftWidthInt).size.height
		self.summaryRect = NSRect(x: Self.horizontalPadding, y: y, width: leftWidth, height: summaryHeight)

		y = self.summaryRect.maxY + Self.verticalPadding
		self.height = y

		if hasThumbnail {
			let thumbX = Self.horizontalPadding + leftWidth + Self.leftRightGap
			let thumbY = (self.height - Self.thumbnailSize) / 2.0
			self.thumbnailRect = NSRect(x: thumbX, y: thumbY, width: Self.thumbnailSize, height: Self.thumbnailSize)
		} else {
			self.thumbnailRect = .zero
		}

		self.separatorRect = NSRect(x: 0, y: self.height - 0.5, width: width, height: 0.5)
	}

	static func height(for width: CGFloat, cellData: TimelineCellData) -> CGFloat {
		return TimelineModernCellLayout(width: width, cellData: cellData).height
	}
}
