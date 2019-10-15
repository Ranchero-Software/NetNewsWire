//
//  NNW3Feed.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

class NNW3Feed: NNW3Entry {

	var pageURL: String?
	var feedURL: String?
	
	init(feedURL: String) {
		super.init(title: nil)
		self.feedURL = feedURL
	}
	
	init(title: String?, pageURL: String?, feedURL: String?, parent: NNW3Entry? = nil) {
		super.init(title: title, parent: parent)
		self.pageURL = pageURL
		self.feedURL = feedURL
	}

	convenience init(plist: [String: Any], parent: NNW3Entry? = nil) {
		let title = plist["name"] as? String
		let pageURL = plist["home"] as? String
		let feedURL = plist["rss"] as? String
		self.init(title: title, pageURL: pageURL, feedURL: feedURL, parent: parent)
	}
	
	override func makeXML(indentLevel: Int) -> String {
		
		let t = title?.rs_stringByEscapingSpecialXMLCharacters() ?? ""
		let p = pageURL?.rs_stringByEscapingSpecialXMLCharacters() ?? ""
		let f = feedURL?.rs_stringByEscapingSpecialXMLCharacters() ?? ""
		
		var s = "<outline text=\"\(t)\" title=\"\(t)\" description=\"\" type=\"rss\" version=\"RSS\" htmlUrl=\"\(p)\" xmlUrl=\"\(f)\"/>\n"
		s = s.rs_string(byPrependingNumberOfTabs: indentLevel)
		
		return s
		
	}
	
}
