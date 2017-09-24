//
//  AppDefaults.swift
//  Evergreen
//
//  Created by Brent Simmons on 9/22/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

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
		static let detailFontSize = "detailFontSize"
		static let openInBrowserInBackground = "openInBrowserInBackground"
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
		
		let defaults = [Key.sidebarFontSize: FontSize.medium.rawValue, Key.timelineFontSize: FontSize.medium.rawValue, Key.detailFontSize: FontSize.medium.rawValue]
		
		UserDefaults.standard.register(defaults: defaults)
	}

	func fontSize(for key: String) -> FontSize {

		var rawFontSize = int(for: key)
		if rawFontSize < smallestFontSizeRawValue {
			rawFontSize = smallestFontSizeRawValue
		}
		if rawFontSize > largestFontSizeRawValue {
			rawFontSize = largestFontSizeRawValue
		}
		return FontSize(rawValue: rawFontSize)!
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
}


