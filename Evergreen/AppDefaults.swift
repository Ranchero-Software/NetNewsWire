//
//  AppDefaults.swift
//  Evergreen
//
//  Created by Brent Simmons on 9/22/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

final class AppDefaults {

	static let shared = AppDefaults()

	private struct Key {

		static let firstRunDate = "firstRunDate"

		static let sidebarFontSize = "sidebarFontSize"
		static let timelineFontSize = "timelineFontSize"
		static let detailFontSize = "detailFontSize"

		static let openInBrowserInBackground = "openInBrowserInBackground"
	}

	let isFirstRun: Bool
	
	var firstRunDate: Date? {
		get {
			return date(for: Key.firstRunDate)
		}
		set {
			setDate(for: key.firstRunDate, date)
		}
	}
	var openInBrowserInBackground: Bool {
		get {
			return bool(for: Key.openInBrowserInBackground)
		}
		set {
			setBool(for: Key.openInBrowserInBackground, newValue)
		}
	}

	init() {

		registerDefaults()
		
		if self.firstRunDate == nil {
			self.isFirstRun = true
			self.firstRunDate = Date()
		}
		else {
			self.isFirstRun = false
		}
	}

	func registerDefaults() {



	}
}

private extension AppDefaults {

	func bool(for key: String) -> Bool {
		return UserDefaults.standard.bool(forKey: key)
	}

	func setBool(for key: String, _ flag: Bool) {
		UserDefaults.standard.set(flag, forKey: key)
	}

	func date(for key: String) -> Date? {
		return UserDefaults.standard.object(forKey: key) as? Date
	}

	func setDate(for key: String, _ date: Date) {
		UserDefaults.standard.set(date, forKey: key)
	}
}


