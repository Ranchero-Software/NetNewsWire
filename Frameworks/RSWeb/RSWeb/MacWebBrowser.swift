//
//  MacWebBrowser.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit

public class MacWebBrowser {
	
	@discardableResult public class func openURL(_ url: URL, inBackground: Bool) -> Bool {
		
		guard let preparedURL = url.preparedForOpeningInBrowser() else {
			return false
		}
		
		if (inBackground) {
			do {
				try NSWorkspace.shared.open(preparedURL, options: [.withoutActivation], configuration: [:])
				return true
			}
			catch {
				return false
			}
		}
		
		return NSWorkspace.shared.open(preparedURL)
	}
}

private extension URL {
	
	func preparedForOpeningInBrowser() -> URL? {
		
		var urlString = absoluteString.replacingOccurrences(of: " ", with: "%20")
		urlString = urlString.replacingOccurrences(of: "^", with: "%5E")
		urlString = urlString.replacingOccurrences(of: "&amp;", with: "&")
		urlString = urlString.replacingOccurrences(of: "&#38;", with: "&")
		
		return URL(string: urlString)
	}	
}
