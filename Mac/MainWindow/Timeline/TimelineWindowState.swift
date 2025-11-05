//
//  TimelineWindowState.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 12/16/23.
//  Copyright © 2023 Ranchero Software. All rights reserved.
//

import Foundation

final class TimelineWindowState: NSObject, NSSecureCoding {

	static let supportsSecureCoding = true

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

	private struct Key {
		static let readArticlesFilterStateKeys = "readArticlesFilterStateKeys"
		static let readArticlesFilterStateValues = "readArticlesFilterStateValues"
		static let selectedAccountID = "selectedAccountID"
		static let selectedArticleID = "selectedArticleID"
	}

	required init?(coder: NSCoder) {
		readArticlesFilterStateKeys = coder.decodeObject(of: [NSArray.self, NSDictionary.self, NSString.self], forKey: Key.readArticlesFilterStateKeys) as? [[String: String]] ?? []
		readArticlesFilterStateValues = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: Key.readArticlesFilterStateValues) as? [Bool] ?? []
		selectedAccountID = coder.decodeObject(of: NSString.self, forKey: Key.selectedAccountID) as? String
		selectedArticleID = coder.decodeObject(of: NSString.self, forKey: Key.selectedArticleID) as? String
	}

	func encode(with coder: NSCoder) {
		coder.encode(readArticlesFilterStateKeys, forKey: Key.readArticlesFilterStateKeys)
		coder.encode(readArticlesFilterStateValues, forKey: Key.readArticlesFilterStateValues)
		coder.encode(selectedAccountID, forKey: Key.selectedAccountID)
		coder.encode(selectedArticleID, forKey: Key.selectedArticleID)
	}
}
