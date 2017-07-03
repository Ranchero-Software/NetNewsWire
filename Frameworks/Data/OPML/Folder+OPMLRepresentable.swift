//
//  Folder+OPMLRepresentable.swift
//  DataModel
//
//  Created by Brent Simmons on 7/2/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

extension Folder: OPMLRepresentable {
	
	public func OPMLString(indentLevel: Int) -> String {
		
		let escapedTitle = nameForDisplay.rs_stringByEscapingSpecialXMLCharacters()
		var s = "<outline text=\"\(escapedTitle)\" title=\"\(escapedTitle)\">\n"
		s = s.rs_string(byPrependingNumberOfTabs: indentLevel)
		
		var hasAtLeastOneChild = false
		
		let _ = visitChildren { (oneChild) -> Bool in
			
			if let oneOPMLObject = oneChild as? OPMLRepresentable {
				s += oneOPMLObject.OPMLString(indentLevel: indentLevel + 1)
				hasAtLeastOneChild = true
			}
			return false
		}
		
		if !hasAtLeastOneChild {
			s = "<outline text=\"\(escapedTitle)\" title=\"\(escapedTitle)\"/>\n"
			s = s.rs_string(byPrependingNumberOfTabs: indentLevel)
			return s
		}
		
		s = s + NSString.rs_string(withNumberOfTabs: indentLevel) + "</outline>\n"
		
		return s
	}
}
