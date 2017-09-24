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

		let actualFontSize = actualFontSizeForFontSize(fontSize)
		
		cellPadding = theme.edgeInsets(forKey: "MainWindow.Timeline.cell.padding")
		
		feedNameColor = theme.color(forKey: "MainWindow.Timeline.cell.feedNameColor")
		feedNameFont = NSFont.systemFont(ofSize: actualFontSize)
		faviconFeedNameSpacing = theme.float(forKey: "MainWindow.Timeline.cell.faviconFeedNameSpacing")

		dateColor = theme.color(forKey: "MainWindow.Timeline.cell.dateColor")
		let actualDateFontSize = actualDateFontSizeForFontSize(fontSize)
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

private let smallFontSize = NSFont.systemFontSize
private let mediumFontSize = smallFontSize + 1.0
private let largeFontSize = mediumFontSize + 4.0
private let veryLargeFontSize = largeFontSize + 8.0

private func actualFontSizeForFontSize(_ fontSize: FontSize) -> CGFloat {

	var actualFontSize = smallFontSize

	switch (fontSize) {

	case .small:
		actualFontSize = smallFontSize
	case .medium:
		actualFontSize = mediumFontSize
	case .large:
		actualFontSize = largeFontSize
	case .veryLarge:
		actualFontSize = veryLargeFontSize
	}

	return actualFontSize
}

//private let smallDateFontSize = NSFont.systemFontSize() - 2.0
//private let mediumDateFontSize = smallDateFontSize + 1.0
//private let largeDateFontSize = mediumDateFontSize + 4.0
//private let veryLargeDateFontSize = largeDateFontSize + 8.0


private func actualDateFontSizeForFontSize(_ fontSize: FontSize) -> CGFloat {
	
	return actualFontSizeForFontSize(fontSize)
//	var actualFontSize = smallDateFontSize
//	
//	switch (fontSize) {
//		
//	case .small:
//		actualFontSize = smallDateFontSize
//	case .medium:
//		actualFontSize = mediumDateFontSize
//	case .large:
//		actualFontSize = largeDateFontSize
//	case .veryLarge:
//		actualFontSize = veryLargeDateFontSize
//	}
//	
//	return actualFontSize

}
