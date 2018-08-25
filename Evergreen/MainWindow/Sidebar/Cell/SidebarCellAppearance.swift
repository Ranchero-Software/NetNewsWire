//
//  SidebarCellAppearance.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/24/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import DB5

struct SidebarCellAppearance: Equatable {

	let imageSize: CGSize
	let imageMarginRight: CGFloat
	let unreadCountMarginLeft: CGFloat
	let textFieldFontSize: CGFloat
	let textFieldFont: NSFont

	init(theme: VSTheme, fontSize: FontSize) {

		self.textFieldFontSize = AppDefaults.actualFontSize(for: fontSize)
		self.textFieldFont = NSFont.systemFont(ofSize: textFieldFontSize)

		self.imageSize = theme.size(forKey: "MainWindow.SourceList.favicon.image")
		self.imageMarginRight = theme.float(forKey: "MainWindow.SourceList.favicon.marginRight")
		self.unreadCountMarginLeft = theme.float(forKey: "MainWindow.SourceList.unreadCount.marginLeft")
	}
}

