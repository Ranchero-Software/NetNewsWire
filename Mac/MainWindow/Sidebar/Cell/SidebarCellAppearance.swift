//
//  SidebarCellAppearance.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/24/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit

struct SidebarCellAppearance: Equatable {

	let imageSize = CGSize(width: 16, height: 16)
	let imageMarginRight: CGFloat = 4.0
	let unreadCountMarginLeft: CGFloat = 10.0
	let textFieldFontSize: CGFloat
	let textFieldFont: NSFont

	init(fontSize: FontSize) {
		self.textFieldFontSize = AppDefaults.shared.actualFontSize(for: fontSize)
		self.textFieldFont = NSFont.systemFont(ofSize: textFieldFontSize)
	}
}

