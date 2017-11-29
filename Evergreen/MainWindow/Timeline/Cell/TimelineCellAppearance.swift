//
//  TimelineCellAppearance.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa
import DB5

struct TimelineCellAppearance {

	let cellPadding: NSEdgeInsets
	
	let feedNameColor: NSColor
	let feedNameFont: NSFont
	let faviconFeedNameSpacing: CGFloat
	let faviconSize = NSSize(width: 16, height: 16)
	
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
	
	let boxLeftMargin: CGFloat

	let gridColor: NSColor

	let avatarSize: NSSize
	let avatarMarginRight: CGFloat
	let avatarAdjustmentTop: CGFloat

	init(theme: VSTheme, fontSize: FontSize) {

		let actualFontSize = AppDefaults.actualFontSize(for: fontSize)
		
		self.cellPadding = theme.edgeInsets(forKey: "MainWindow.Timeline.cell.padding")
		
		self.feedNameColor = theme.color(forKey: "MainWindow.Timeline.cell.feedNameColor")
		self.feedNameFont = NSFont.systemFont(ofSize: actualFontSize)
		self.faviconFeedNameSpacing = theme.float(forKey: "MainWindow.Timeline.cell.faviconFeedNameSpacing")

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
		
		self.boxLeftMargin = self.cellPadding.left + self.unreadCircleDimension + self.unreadCircleMarginRight //+ self.avatarSize.width + self.avatarMarginRight
	}
}

