//
//  Browser.swift
//  Evergren
//
//  Created by Brent Simmons on 2/23/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

struct Browser {

	/// The user-specified default browser for opening web pages.
	///
	/// The user-assigned default browser, or `nil` if none was assigned
	/// (i.e., the system default should be used).
	static var defaultBrowser: MacWebBrowser? {
		if let bundleID = AppDefaults.shared.defaultBrowserID, let browser = MacWebBrowser(bundleIdentifier: bundleID) {
			return browser
		}

		return nil
	}


	/// Opens a URL in the default browser.
	///
	/// - Parameters:
	///   - urlString: The URL to open.
	///   - invert: Whether to invert the "open in background in browser" preference
	static func open(_ urlString: String, invertPreference invert: Bool = false) {
		// Opens according to prefs.
		open(urlString, inBackground: invert ? !AppDefaults.shared.openInBrowserInBackground : AppDefaults.shared.openInBrowserInBackground)
	}


	/// Opens a URL in the default browser.
	///
	/// - Parameters:
	///   - urlString: The URL to open.
	///   - inBackground: Whether to open the URL in the background or not.
	/// - Note: Some browsers (specifically Chromium-derived ones) will ignore the request
	///   to open in the background.
	static func open(_ urlString: String, inBackground: Bool) {
		if let url = URL(string: urlString) {
			if let defaultBrowser = defaultBrowser {
				defaultBrowser.openURL(url, inBackground: inBackground)
			} else {
				MacWebBrowser.openURL(url, inBackground: inBackground)
			}
		}
	}
}

extension Browser {

	static var titleForOpenInBrowserInverted: String {
		let openInBackgroundPref = AppDefaults.shared.openInBrowserInBackground

		return openInBackgroundPref ?
			NSLocalizedString("Open in Browser in Foreground", comment: "Open in Browser in Foreground menu item title") :
			NSLocalizedString("Open in Browser in Background", comment: "Open in Browser in Background menu item title")
	}
}
