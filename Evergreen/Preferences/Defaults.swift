//
//  Defaults.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/20/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

let SidebarFontSizeKey = "sidebarFontSize"
let TimelineFontSizeKey = "timelineFontSize"
let ArticleFontSizeKey = "articleFontSize"

let SidebarFontSizeKVOKey = "values." + SidebarFontSizeKey
let TimelineFontSizeKVOKey = "values." + TimelineFontSizeKey
let ArticleFontSizeKVOKey = "values." + ArticleFontSizeKey

let OpenInBrowserInBackgroundKey = "openInBrowserInBackground"

enum FontSize: Int {
	case small = 0
	case medium = 1
	case large = 2
	case veryLarge = 3
}

private let smallestFontSizeRawValue = FontSize.small.rawValue
private let largestFontSizeRawValue = FontSize.veryLarge.rawValue

func registerDefaults() {
	
	let defaults = [SidebarFontSizeKey: FontSize.medium.rawValue, TimelineFontSizeKey: FontSize.medium.rawValue, ArticleFontSizeKey: FontSize.medium.rawValue]
	
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

