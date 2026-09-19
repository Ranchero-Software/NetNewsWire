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
	// Nil when the state was saved before sorting became per-window.
	let sortParameters: ArticleSortParameters?

	init(readArticlesFilterStateKeys: [[String: String]], readArticlesFilterStateValues: [Bool], selectedAccountID: String? = nil, selectedArticleID: String? = nil, sortParameters: ArticleSortParameters? = nil) {
		self.readArticlesFilterStateKeys = readArticlesFilterStateKeys
		self.readArticlesFilterStateValues = readArticlesFilterStateValues
		self.selectedAccountID = selectedAccountID
		self.selectedArticleID = selectedArticleID
		self.sortParameters = sortParameters
	}

	private struct Key {
		static let readArticlesFilterStateKeys = "readArticlesFilterStateKeys"
		static let readArticlesFilterStateValues = "readArticlesFilterStateValues"
		static let selectedAccountID = "selectedAccountID"
		static let selectedArticleID = "selectedArticleID"
		static let sortKey = "sortKey"
		static let sortDirection = "sortDirection"
		static let groupByFeed = "groupByFeed"
	}

	required init?(coder: NSCoder) {
		readArticlesFilterStateKeys = coder.decodeObject(of: [NSArray.self, NSDictionary.self, NSString.self], forKey: Key.readArticlesFilterStateKeys) as? [[String: String]] ?? []
		readArticlesFilterStateValues = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: Key.readArticlesFilterStateValues) as? [Bool] ?? []
		selectedAccountID = coder.decodeObject(of: NSString.self, forKey: Key.selectedAccountID) as? String
		selectedArticleID = coder.decodeObject(of: NSString.self, forKey: Key.selectedArticleID) as? String

		if let rawSortKey = coder.decodeObject(of: NSString.self, forKey: Key.sortKey) as? String, let sortKey = ArticleSortKey(rawValue: rawSortKey) {
			let direction = ComparisonResult(rawValue: coder.decodeInteger(forKey: Key.sortDirection)) ?? .orderedDescending
			sortParameters = ArticleSortParameters(key: sortKey, direction: direction, groupByFeed: coder.decodeBool(forKey: Key.groupByFeed))
		} else {
			sortParameters = nil
		}
	}

	func encode(with coder: NSCoder) {
		coder.encode(readArticlesFilterStateKeys, forKey: Key.readArticlesFilterStateKeys)
		coder.encode(readArticlesFilterStateValues, forKey: Key.readArticlesFilterStateValues)
		coder.encode(selectedAccountID, forKey: Key.selectedAccountID)
		coder.encode(selectedArticleID, forKey: Key.selectedArticleID)
		if let sortParameters {
			coder.encode(sortParameters.key.rawValue, forKey: Key.sortKey)
			coder.encode(sortParameters.direction.rawValue, forKey: Key.sortDirection)
			coder.encode(sortParameters.groupByFeed, forKey: Key.groupByFeed)
		}
	}

	override var description: String {
		let sort: String
		if let sortParameters {
			sort = "\(sortParameters.key.rawValue) \(sortParameters.direction.rawValue) group=\(sortParameters.groupByFeed)"
		} else {
			sort = "nil"
		}
		return "TimelineWindowState: filterKeys=\(readArticlesFilterStateKeys.count), filterValues=\(readArticlesFilterStateValues.count), accountID=\(selectedAccountID ?? "nil"), articleID=\(selectedArticleID ?? "nil"), sort=\(sort)"
	}
}
