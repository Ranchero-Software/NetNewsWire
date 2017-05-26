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


func openInBrowser(_ urlString: String) {
	
	// Opens according to prefs.
	let openInBackground = UserDefaults.standard.bool(forKey: OpenInBrowserInBackgroundKey)
	openInBrowser(urlString, inBackground: openInBackground)
}

func openInBrowser(_ urlString: String, inBackground: Bool) {
	
	if let url = URL(string: urlString) {
		let _ = MacWebBrowser.openURL(url, inBackground: inBackground)
	}
}

