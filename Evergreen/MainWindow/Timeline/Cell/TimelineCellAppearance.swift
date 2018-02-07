//
//  TimelineCellAppearance.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import DB5

struct TimelineCellAppearance: Equatable {

	let cellPadding: NSEdgeInsets
	
	let feedNameColor: NSColor
	let feedNameFont: NSFont

	let dateColor: NSColor
	let dateMarginLeft: CGFloat
	let dateFont: NSFont
	
	let titleColor: NSColor
	let titleFont: NSFont
	let titleBottomMargin: CGFloat
	
	let textColor: NSColor
	let textFont: NSFont
	
	let unreadCircleColor: NSColor
	let unreadCircleDimension: CGFloat
	let unreadCircleMarginRight: CGFloat
	
	let gridColor: NSColor

	let avatarSize: NSSize
	let avatarMarginRight: CGFloat
	let avatarAdjustmentTop: CGFloat
	let avatarCornerRadius: CGFloat
	let showAvatar: Bool

	let boxLeftMargin: CGFloat

	init(theme: VSTheme, showAvatar: Bool, fontSize: FontSize) {

		let actualFontSize = AppDefaults.actualFontSize(for: fontSize)
		
		self.cellPadding = theme.edgeInsets(forKey: "MainWindow.Timeline.cell.padding")
		
		self.feedNameColor = theme.color(forKey: "MainWindow.Timeline.cell.feedNameColor")
		self.feedNameFont = NSFont.systemFont(ofSize: actualFontSize)

		self.dateColor = theme.color(forKey: "MainWindow.Timeline.cell.dateColor")
		let actualDateFontSize = AppDefaults.actualFontSize(for: fontSize)
		self.dateFont = NSFont.systemFont(ofSize: actualDateFontSize)
		self.dateMarginLeft = theme.float(forKey: "MainWindow.Timeline.cell.dateMarginLeft")
		
		self.titleColor = theme.color(forKey: "MainWindow.Timeline.cell.titleColor")
		self.titleFont = NSFont.systemFont(ofSize: actualFontSize, weight: NSFont.Weight.bold)
		self.titleBottomMargin = theme.float(forKey: "MainWindow.Timeline.cell.titleMarginBottom")
		
		self.textColor = theme.color(forKey: "MainWindow.Timeline.cell.textColor")
		self.textFont = NSFont.systemFont(ofSize: actualFontSize)
		
		self.unreadCircleColor = theme.color(forKey: "MainWindow.Timeline.cell.unreadCircleColor")
		self.unreadCircleDimension = theme.float(forKey: "MainWindow.Timeline.cell.unreadCircleDimension")
		self.unreadCircleMarginRight = theme.float(forKey: "MainWindow.Timeline.cell.unreadCircleMarginRight")
		
		self.gridColor = theme.colorWithAlpha(forKey: "MainWindow.Timeline.gridColor")

		self.avatarSize = theme.size(forKey: "MainWindow.Timeline.cell.avatar")
		self.avatarMarginRight = theme.float(forKey: "MainWindow.Timeline.cell.avatarMarginRight")
		self.avatarAdjustmentTop = theme.float(forKey: "MainWindow.Timeline.cell.avatarAdjustmentTop")
		self.avatarCornerRadius = theme.float(forKey: "MainWindow.Timeline.cell.avatarCornerRadius")
		self.showAvatar = showAvatar

		var margin = self.cellPadding.left + self.unreadCircleDimension + self.unreadCircleMarginRight
		if showAvatar {
			margin += (self.avatarSize.width + self.avatarMarginRight)
		}
		self.boxLeftMargin = margin
	}

	static func ==(lhs: TimelineCellAppearance, rhs: TimelineCellAppearance) -> Bool {

		return lhs.boxLeftMargin == rhs.boxLeftMargin && lhs.showAvatar == rhs.showAvatar && lhs.cellPadding == rhs.cellPadding && lhs.feedNameColor == rhs.feedNameColor && lhs.feedNameFont == rhs.feedNameFont && lhs.dateColor == rhs.dateColor && lhs.dateMarginLeft == rhs.dateMarginLeft && lhs.dateFont == rhs.dateFont && lhs.titleColor == rhs.titleColor && lhs.titleFont == rhs.titleFont && lhs.titleBottomMargin == rhs.titleBottomMargin && lhs.textColor == rhs.textColor && lhs.textFont == rhs.textFont && lhs.unreadCircleColor == rhs.unreadCircleColor && lhs.unreadCircleDimension == rhs.unreadCircleDimension && lhs.unreadCircleMarginRight == rhs.unreadCircleMarginRight && lhs.gridColor == rhs.gridColor && lhs.avatarSize == rhs.avatarSize && lhs.avatarMarginRight == rhs.avatarMarginRight && lhs.avatarAdjustmentTop == rhs.avatarAdjustmentTop && lhs.avatarCornerRadius == rhs.avatarCornerRadius
	}
}

extension NSEdgeInsets: Equatable {

	public static func ==(lhs: NSEdgeInsets, rhs: NSEdgeInsets) -> Bool {

		return lhs.left == rhs.left && lhs.top == rhs.top && lhs.right == rhs.right && lhs.bottom == rhs.bottom
	}
}
