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
	
	init(theme: VSTheme, fontSize: FontSize) {

		let actualFontSize = AppDefaults.actualFontSize(for: fontSize)
		
		cellPadding = theme.edgeInsets(forKey: "MainWindow.Timeline.cell.padding")
		
		feedNameColor = theme.color(forKey: "MainWindow.Timeline.cell.feedNameColor")
		feedNameFont = NSFont.systemFont(ofSize: actualFontSize)
		faviconFeedNameSpacing = theme.float(forKey: "MainWindow.Timeline.cell.faviconFeedNameSpacing")

		dateColor = theme.color(forKey: "MainWindow.Timeline.cell.dateColor")
		let actualDateFontSize = AppDefaults.actualFontSize(for: fontSize)
		dateFont = NSFont.systemFont(ofSize: actualDateFontSize)
		dateMarginLeft = theme.float(forKey: "MainWindow.Timeline.cell.dateMarginLeft")
		
		titleColor = theme.color(forKey: "MainWindow.Timeline.cell.titleColor")
		titleFont = NSFont.systemFont(ofSize: actualFontSize, weight: NSFont.Weight.bold)
		titleBottomMargin = theme.float(forKey: "MainWindow.Timeline.cell.titleMarginBottom")
		
		textColor = theme.color(forKey: "MainWindow.Timeline.cell.textColor")
		textFont = NSFont.systemFont(ofSize: actualFontSize)
		
		unreadCircleColor = theme.color(forKey: "MainWindow.Timeline.cell.unreadCircleColor")
		unreadCircleDimension = theme.float(forKey: "MainWindow.Timeline.cell.unreadCircleDimension")
		unreadCircleMarginRight = theme.float(forKey: "MainWindow.Timeline.cell.unreadCircleMarginRight")
		
		boxLeftMargin = cellPadding.left + unreadCircleDimension + unreadCircleMarginRight
		
		gridColor = theme.colorWithAlpha(forKey: "MainWindow.Timeline.gridColor")
	}
}

