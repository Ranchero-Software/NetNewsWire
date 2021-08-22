//
//  Browser.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 23/08/2021.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation



/// The `Browser` enum contains browsers supported by NetNewsWire.
///
/// To support a new browser, create a case, configure it, add its URL scheme
/// to `LSApplicationQueriesSchemes` in `Info.plist`, and add an
/// appropriate image to the Asset catalog. The browserID should be used as the
/// image filename.
public enum Browser: CaseIterable {
	
	case inApp
	case safari
	case brave
	case chrome
	case edge
	case firefox
	case opera
	case onePassword
	
	var urlScheme: String {
		switch self {
		case .inApp:
			return "" // not required, will open in SFSafariViewController
		case .safari:
			return "" // not required, will use openURL
		case .brave:
			return "brave://open-url?url="
		case .chrome:
			return "googlechrome://"
		case .edge:
			return "microsoft-edge-https://"
		case .firefox:
			return "firefox://open-url?url="
		case .opera:
			return "touch-http://"
		case .onePassword:
			return "ophttps://"
		}
	}
	
	var canOpenURL: Bool {
		switch self {
		case .inApp:
			return true
		case .safari:
			return UIApplication.shared.canOpenURL(URL(string: "https://apple.com")!)
		case .brave:
			return UIApplication.shared.canOpenURL(URL(string: Browser.brave.urlScheme)!)
		case .chrome:
			return UIApplication.shared.canOpenURL(URL(string: Browser.chrome.urlScheme)!)
		case .edge:
			return UIApplication.shared.canOpenURL(URL(string: Browser.edge.urlScheme)!)
		case .firefox:
			return UIApplication.shared.canOpenURL(URL(string: Browser.firefox.urlScheme)!)
		case .opera:
			return UIApplication.shared.canOpenURL(URL(string: Browser.opera.urlScheme)!)
		case .onePassword:
			return UIApplication.shared.canOpenURL(URL(string: Browser.onePassword.urlScheme)!)
		}
	}
	
	var browserID: String {
		switch self {
		case .inApp:
			return "browser.inapp"
		case .safari:
			return "browser.safari"
		case .brave:
			return "browser.brave"
		case .chrome:
			return "browser.chrome"
		case .edge:
			return "browser.edge"
		case .firefox:
			return "browser.firefox"
		case .opera:
			return "browser.opera"
		case .onePassword:
			return "browser.onepassword"
		}
	}
	
	var displayName: String {
		switch self {
		case .inApp:
			return NSLocalizedString("NetNewsWire", comment: "In-app")
		case .safari:
			return NSLocalizedString("Default Browser", comment: "Default")
		case .brave:
			return NSLocalizedString("Brave", comment: "Brave")
		case .chrome:
			return NSLocalizedString("Chrome", comment: "Chrome")
		case .edge:
			return NSLocalizedString("Edge", comment: "Edge")
		case .firefox:
			return NSLocalizedString("Firefox", comment: "Firefox")
		case .opera:
			return NSLocalizedString("Opera", comment: "Opera")
		case .onePassword:
			return NSLocalizedString("1Password", comment: "1Password")
		}
	}
}
