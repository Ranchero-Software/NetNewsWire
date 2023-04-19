//
//  Browser.swift
//  Evergren
//
//  Created by Brent Simmons on 2/23/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

@MainActor struct Browser {

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
		guard let url = URL(unicodeString: urlString), let preparedURL = url.preparedForOpeningInBrowser() else { return }
		
		let configuration = NSWorkspace.OpenConfiguration()
		configuration.requiresUniversalLinks = true
		configuration.promptsUserIfNeeded = false
		if inBackground {
			configuration.activates = false
		}

		NSWorkspace.shared.open(preparedURL, configuration: configuration) { (runningApplication, error) in
			guard error != nil else { return }
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

extension Browser {

	/// Open multiple pages in the default browser, warning if over a certain number of URLs are passed.
	/// - Parameters:
	///   - urlStrings: The URL strings to open.
	///   - window: The window on which to display the "over limit" alert sheet. If `nil`, will be displayed as a
	///   modal dialog.
	///   - invertPreference: Whether to invert the user's "Open web pages in background in browser" preference.
	static func open(_ urlStrings: [String], fromWindow window: NSWindow?, invertPreference: Bool = false) {
		if urlStrings.count > 500 {
			return
		}

		func doOpenURLs() {
			for urlString in urlStrings {
				Browser.open(urlString, invertPreference: invertPreference)
			}
		}

		if urlStrings.count > 20 {
			let alert = NSAlert()
			let messageFormat = NSLocalizedString("Are you sure you want to open %ld articles in your browser?", comment: "Open in Browser confirmation alert message format")
			alert.messageText = String.localizedStringWithFormat(messageFormat, urlStrings.count)
			let confirmButtonTitleFormat = NSLocalizedString("Open %ld Articles", comment: "Open URLs in Browser confirm button format")
			alert.addButton(withTitle: String.localizedStringWithFormat(confirmButtonTitleFormat, urlStrings.count))
			alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel button"))

			if let window {
				alert.beginSheetModal(for: window) { response in
					if response == .alertFirstButtonReturn {
						doOpenURLs()
					}
				}
			} else {
				if alert.runModal() == .alertFirstButtonReturn {
					doOpenURLs()
				}
			}
		} else {
			doOpenURLs()
		}
	}

}
