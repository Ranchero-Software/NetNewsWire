//
//  Browser.swift
//  Evergren
//
//  Created by Brent Simmons on 2/23/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CoreServices
import RSWeb

struct Browser {

	static func open(_ urlString: String) {
		// Opens according to prefs.
		open(urlString, inBackground: AppDefaults.openInBrowserInBackground)
	}

	static func open(_ urlString: String, inBackground: Bool) {
		if let url = URL(string: urlString) {
			MacWebBrowser.openURL(url, inBackground: inBackground)
		}
	}
}

