//
//  Defaults.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/20/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

final class AppDefaults {
	
	
	
}

extension AppDefaultsKey {
	
	static let sidebarFontSizeKVO = "values." + sidebarFontSize
	static let timelineFontSizeKVO = "values." + timelineFontSize
	static let detailFontSizeKVO = "values." + detailFontSize
}

enum FontSize: Int {
	case small = 0
	case medium = 1
	case large = 2
	case veryLarge = 3
}

private let smallestFontSizeRawValue = FontSize.small.rawValue
private let largestFontSizeRawValue = FontSize.veryLarge.rawValue

func registerDefaults() {
	
	let defaults = [AppDefaultsKey.sidebarFontSize: FontSize.medium.rawValue, AppDefaultsKey.timelineFontSize: FontSize.medium.rawValue, AppDefaultsKey.detailFontSize, FontSize.medium.rawValue]
	
	UserDefaults.standard.register(defaults: defaults)
}

func timelineFontSize() -> FontSize {

	return fontSizeForKey(TimelineFontSizeKey)
}

private func fontSizeForKey(_ key: String) -> FontSize {

	var rawFontSize = UserDefaults.standard.integer(forKey: key)
	if rawFontSize < smallestFontSizeRawValue {
		rawFontSize = smallestFontSizeRawValue
	}
	if rawFontSize > largestFontSizeRawValue {
		rawFontSize = largestFontSizeRawValue
	}
	return FontSize(rawValue: rawFontSize)!
}

