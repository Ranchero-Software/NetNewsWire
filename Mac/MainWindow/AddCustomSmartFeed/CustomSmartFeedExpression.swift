//
//  CustomSmartFeedExpression.swift
//  NetNewsWire
//
//  Created by Mateusz on 19/03/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

public struct CustomSmartFeedExpression {
	var field: Field
	var constraint: Constraint
	var value: String
	
	enum Field: String, Hashable {
		case feedID, title, contentHTML, contentText, externalURL
	}
	
	enum Constraint: Hashable {
		case has, hasNot, startsWith, endsWith, exact
		
		var queryFragment: String {
			switch self {
			case .has: return "LIKE '%' || ? || '%'"
			case .hasNot: return "NOT LIKE '%' || ? || '%'"
			case .startsWith: return  "LIKE ? || '%'"
			case .endsWith: return  "LIKE ? || '%'"
			case .exact: return "= ?"
			}
		}
	}
}
