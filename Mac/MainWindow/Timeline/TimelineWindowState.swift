//
//  TimelineWindowState.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 12/16/23.
//  Copyright © 2023 Ranchero Software. All rights reserved.
//

import Foundation

class TimelineWindowState: NSObject, NSSecureCoding {
	
	static var supportsSecureCoding = true
	
	let readArticlesFilterStateKeys: [[String: String]]
	let readArticlesFilterStateValues: [Bool]
	let selectedAccountID: String?
	let selectedArticleID: String?
	
	init(readArticlesFilterStateKeys: [[String : String]], readArticlesFilterStateValues: [Bool], selectedAccountID: String? = nil, selectedArticleID: String? = nil) {
		self.readArticlesFilterStateKeys = readArticlesFilterStateKeys
		self.readArticlesFilterStateValues = readArticlesFilterStateValues
		self.selectedAccountID = selectedAccountID
		self.selectedArticleID = selectedArticleID
	}
	
	required init?(coder: NSCoder) {
		readArticlesFilterStateKeys = coder.decodeObject(of: [NSArray.self, NSDictionary.self, NSString.self], forKey: "readArticlesFilterStateKeys") as? [[String: String]] ?? []
		readArticlesFilterStateValues = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "readArticlesFilterStateValues") as? [Bool] ?? []
		selectedAccountID = coder.decodeObject(of: NSString.self, forKey: "selectedAccountID") as? String
		selectedArticleID = coder.decodeObject(of: NSString.self, forKey: "selectedArticleID") as? String
	}
	
	func encode(with coder: NSCoder) {
		coder.encode(readArticlesFilterStateKeys, forKey: "readArticlesFilterStateKeys")
		coder.encode(readArticlesFilterStateValues, forKey: "readArticlesFilterStateValues")
		coder.encode(selectedAccountID, forKey: "selectedAccountID")
		coder.encode(selectedArticleID, forKey: "selectedArticleID")
	}
	
}
