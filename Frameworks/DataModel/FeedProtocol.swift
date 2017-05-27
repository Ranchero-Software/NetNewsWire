//
//  FeedProtocol.swift
//  Evergreen
//
//  Created by Brent Simmons on 4/23/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

public protocol Feed: class, UnreadCountProvider, DisplayNameProvider {

	var account: Account {get}
	var url: String {get}
	var feedID: String {get}
	var homePageURL: String? {get}
	var name: String? {get}
	var editedName: String? {get}
	var nameForDisplay: String {get}
//	var articles: NSSet {get}

	init(account: Account, url: String, feedID: String)
	
	// Exporting OPML.
	func opmlString(indentLevel: Int) -> String
}

public extension Feed {

	func opmlString(indentLevel: Int) -> String {
		
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
