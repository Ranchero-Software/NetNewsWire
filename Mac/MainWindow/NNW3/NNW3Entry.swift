//
//  NNW3Entry.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

class NNW3Entry {
	
	var title: String?
	var entries = [NNW3Entry]()

	weak var parent: NNW3Entry?
	
	var isFolder: Bool {
		return type(of: self) == NNW3Entry.self
	}
	
	init(title: String?, parent: NNW3Entry? = nil) {
		self.title = title
		self.parent = parent
	}
	
	convenience init(plist: [String: Any], parent: NNW3Entry? = nil) {
		let title = plist["name"] as? String
		self.init(title: title, parent: parent)
		
		guard let childrenArray =  plist["childrenArray"] as? [[String: AnyObject]] else {
			return
		}
		
		for child in childrenArray {
			if child["isContainer"] as? Bool ?? false {
				entries.append(NNW3Entry(plist: child, parent: self))
			} else {
				entries.append(NNW3Feed(plist: child, parent: self))
			}
		}
		
	}
	
	func makeXML(indentLevel: Int) -> String {
		
		let t = title?.rs_stringByEscapingSpecialXMLCharacters() ?? ""
		var s = "<outline text=\"\(t)\" title=\"\(t)\">\n".rs_string(byPrependingNumberOfTabs: indentLevel)

		for entry in entries {
			s += entry.makeXML(indentLevel: indentLevel + 1)
		}
		
		s += "</outline>\n".rs_string(byPrependingNumberOfTabs: indentLevel)

		return s
		
	}
		
}
