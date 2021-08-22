//
//  BrowserManager.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 22/8/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit

extension Notification.Name {
	static let browserPreferenceDidChange = Notification.Name("browserPreferenceDidChange")
}

public final class BrowserManager {
	
	/// The available browsers supported by the application. If `enableExtendedBrowserPreferences`
	/// is `false`, this will only contain in-app and system browser options.
	public private(set) var availableBrowsers = [Browser]()
	
	/// The currently selected `BrowserID`. The default is `Browser.inApp`.
	public var currentBrowserPreference: String {
		get {
			return AppDefaults.shared.browserPreference
		}
		set {
			AppDefaults.shared.browserPreference = newValue
			NotificationCenter.default.post(name: .browserPreferenceDidChange, object: nil)
		}
	}
	
	/// When `true`, the user can select a specific browser instead of the system default browser.
	private var enableExtendedBrowserPreferences = false
	
	public static let shared = BrowserManager()
	
	private init() {
		configureAvailableBrowsers()
	}
	
	/// Refreshes the available browsers. This is called when BrowserManager is inited,
	/// and when the application returns to the foreground.
	func configureAvailableBrowsers() {
		if !enableExtendedBrowserPreferences {
			availableBrowsers = [.inApp, .safari]
		} else {
			availableBrowsers = Browser.allCases.filter({ $0.canOpenURL == true })
		}
		resetBrowserPreferenceIfRequired()
	}
	
	/// Opens the URL in the specified browser.
	/// - Parameter urlString: the url to open.
	func openURL(urlString: String) {
		guard let url = URL(string: urlString) else {
			return
		}
		if currentBrowser() == .safari {
			UIApplication.shared.open(url, options: [:], completionHandler: nil)
			return
		}
		
		switch currentBrowser() {
		case .edge, .chrome, .opera, .onePassword:
			var string = urlString
			string = string.replacingOccurrences(of: "https://", with: "")
			string = string.replacingOccurrences(of: "http://", with: "")
			guard let browserURL = URL(string: currentBrowser().urlScheme + string) else {
				return
			}
			UIApplication.shared.open(browserURL, options: [:], completionHandler: nil)
		default:
			guard let browserURL = URL(string: currentBrowser().urlScheme + urlString) else {
				return
			}
			UIApplication.shared.open(browserURL, options: [:], completionHandler: nil)
		}
	}
	
	/// If the user has uninstalled a browser this will reset the browser back to the in-app default.
	private func resetBrowserPreferenceIfRequired() {
		if availableBrowsers.filter({ $0.browserID == currentBrowserPreference }).count == 0 {
			currentBrowserPreference = Browser.inApp.browserID
		}
	}
	
	/// The currently selected browser.
	/// - Returns: `Browser`
	func currentBrowser() -> Browser {
		guard let browser = Browser.allCases.filter({ $0.browserID == currentBrowserPreference }).first else {
			resetBrowserPreferenceIfRequired()
			return currentBrowser()
		}
		return browser
	}
}
