//
//  AppDefaults.swift
//  Evergreen
//
//  Created by Brent Simmons on 9/22/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit

enum FontSize: Int {

	case small = 0
	case medium = 1
	case large = 2
	case veryLarge = 3
}

final class AppDefaults {

	static let shared = AppDefaults()

	struct Key {
		static let firstRunDate = "firstRunDate"
		static let sidebarFontSize = "sidebarFontSize"
		static let timelineFontSize = "timelineFontSize"
		static let timelineSortDirection = "timelineSortDirection"
		static let detailFontSize = "detailFontSize"
		static let openInBrowserInBackground = "openInBrowserInBackground"
		static let mainWindowWidths = "mainWindowWidths"

		// Hidden prefs
		static let showTitleOnMainWindow = "KafasisTitleMode"
	}

	private let smallestFontSizeRawValue = FontSize.small.rawValue
	private let largestFontSizeRawValue = FontSize.veryLarge.rawValue

	let isFirstRun: Bool
	
	var openInBrowserInBackground: Bool {
		get {
			return bool(for: Key.openInBrowserInBackground)
		}
		set {
			setBool(for: Key.openInBrowserInBackground, newValue)
		}
	}

	var sidebarFontSize: FontSize {
		get {
			return fontSize(for: Key.sidebarFontSize)
		}
		set {
			setFontSize(for: Key.sidebarFontSize, newValue)
		}
	}

	var timelineFontSize: FontSize {
		get {
			return fontSize(for: Key.timelineFontSize)
		}
		set {
			setFontSize(for: Key.timelineFontSize, newValue)
		}
	}

	var detailFontSize: FontSize {
		get {
			return fontSize(for: Key.detailFontSize)
		}
		set {
			setFontSize(for: Key.detailFontSize, newValue)
		}
	}

	var showTitleOnMainWindow: Bool {
		return bool(for: Key.showTitleOnMainWindow)
	}

	var timelineSortDirection: ComparisonResult {
		get {
			return sortDirection(for: Key.timelineSortDirection)
		}
		set {
			setSortDirection(for: Key.timelineSortDirection, newValue)
		}
	}

	var mainWindowWidths: [Int]? {
		get {
			return UserDefaults.standard.object(forKey: Key.mainWindowWidths) as? [Int]
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.mainWindowWidths)
		}
	}
	
	private init() {

		AppDefaults.registerDefaults()

		let firstRunDate = UserDefaults.standard.object(forKey: Key.firstRunDate) as? Date
		if firstRunDate == nil {
			self.isFirstRun = true
			self.firstRunDate = Date()
		}
		else {
			self.isFirstRun = false
		}
	}

	static func actualFontSize(for fontSize: FontSize) -> CGFloat {

		switch fontSize {
		case .small:
			return NSFont.systemFontSize
		case .medium:
			return actualFontSize(for: .small) + 1.0
		case .large:
			return actualFontSize(for: .medium) + 4.0
		case .veryLarge:
			return actualFontSize(for: .large) + 8.0
		}
	}
}

private extension AppDefaults {

	var firstRunDate: Date? {
		get {
			return date(for: Key.firstRunDate)
		}
		set {
			setDate(for: Key.firstRunDate, newValue)
		}
	}

	static func registerDefaults() {
		
		let defaults: [String : Any] = [Key.sidebarFontSize: FontSize.medium.rawValue, Key.timelineFontSize: FontSize.medium.rawValue, Key.detailFontSize: FontSize.medium.rawValue, Key.timelineSortDirection: ComparisonResult.orderedDescending.rawValue, "NSScrollViewShouldScrollUnderTitlebar": false]
		
		UserDefaults.standard.register(defaults: defaults)
	}

	func fontSize(for key: String) -> FontSize {

		// Punted till after 1.0.
		return .medium

//		var rawFontSize = int(for: key)
//		if rawFontSize < smallestFontSizeRawValue {
//			rawFontSize = smallestFontSizeRawValue
//		}
//		if rawFontSize > largestFontSizeRawValue {
//			rawFontSize = largestFontSizeRawValue
//		}
//		return FontSize(rawValue: rawFontSize)!
	}
	
	func setFontSize(for key: String, _ fontSize: FontSize) {
		setInt(for: key, fontSize.rawValue)
	}
	
	func bool(for key: String) -> Bool {
		return UserDefaults.standard.bool(forKey: key)
	}

	func setBool(for key: String, _ flag: Bool) {
		UserDefaults.standard.set(flag, forKey: key)
	}

	func int(for key: String) -> Int {
		return UserDefaults.standard.integer(forKey: key)
	}
	
	func setInt(for key: String, _ x: Int) {
		UserDefaults.standard.set(x, forKey: key)
	}
	
	func date(for key: String) -> Date? {
		return UserDefaults.standard.object(forKey: key) as? Date
	}

	func setDate(for key: String, _ date: Date?) {
		UserDefaults.standard.set(date, forKey: key)
	}

	func sortDirection(for key:String) -> ComparisonResult {

		let rawInt = int(for: key)
		if rawInt == ComparisonResult.orderedAscending.rawValue {
			return .orderedAscending
		}
		return .orderedDescending
	}

	func setSortDirection(for key: String, _ value: ComparisonResult) {

		if value == .orderedAscending {
			setInt(for: key, ComparisonResult.orderedAscending.rawValue)
		}
		else {
			setInt(for: key, ComparisonResult.orderedDescending.rawValue)
		}
	}
}


