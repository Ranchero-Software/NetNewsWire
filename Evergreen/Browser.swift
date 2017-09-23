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
	openInBrowser(urlString, inBackground: AppDefaults.shared.openInBrowserInBackground)
}

func openInBrowser(_ urlString: String, inBackground: Bool) {
	
	if let url = URL(string: urlString) {
		MacWebBrowser.openURL(url, inBackground: inBackground)
	}
}

