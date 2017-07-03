//
//  Feed+OPMLRepresentable.swift
//  DataModel
//
//  Created by Brent Simmons on 7/2/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

extension Feed: OPMLRepresentable {
	
	public func OPMLString(indentLevel: Int) -> String {
		
		let escapedName = nameForDisplay.rs_stringByEscapingSpecialXMLCharacters()
		var escapedHomePageURL = ""
		if let homePageURL = homePageURL {
			escapedHomePageURL = homePageURL.rs_stringByEscapingSpecialXMLCharacters()
		}
		let escapedFeedURL = url.rs_stringByEscapingSpecialXMLCharacters()
		
		var s = "<outline text=\"\(escapedName)\" title=\"\(escapedName)\" description=\"\" type=\"rss\" version=\"RSS\" htmlUrl=\"\(escapedHomePageURL)\" xmlUrl=\"\(escapedFeedURL)\"/>\n"
		s = s.rs_string(byPrependingNumberOfTabs: indentLevel)
		
		return s
	}
}
