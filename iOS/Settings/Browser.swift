//
//  Browser.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 23/08/2021.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation



/// The `Browser` enum contains browsers supported by NetNewsWire.
public enum Browser: CaseIterable {
	
	case inApp
	case defaultBrowser
	
	var browserID: String {
		switch self {
		case .inApp:
			return "browser.inapp"
		case .defaultBrowser:
			return "browser.safari"
		}
	}
	
	var displayName: String {
		switch self {
		case .inApp:
			return NSLocalizedString("NetNewsWire", comment: "In-app")
		case .defaultBrowser:
			return NSLocalizedString("Default Browser", comment: "Default")
		}
	}
}

// MARK: - Browser Notifications
public extension Notification.Name {
	static let browserPreferenceDidChange = Notification.Name("browserPreferenceDidChange")
}
