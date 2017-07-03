//
//  Account+OPMLRepresentable.swift
//  DataModel
//
//  Created by Brent Simmons on 7/2/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

extension Account: OPMLRepresentable {
	
	public func OPMLString(indentLevel: Int) -> String {
		
		var s = ""
		for oneObject in topLevelObjects {
			if let oneOPMLObject = oneObject as? OPMLRepresentable {
				s += oneOPMLObject.OPMLString(indentLevel: indentLevel + 1)
			}
		}
		return s
	}
}
