//
//  FeedbinSavedSearch.swift
//  Account
//
//  Created by Brent Simmons on 10/14/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedbinSavedSearch: Hashable {

	// https://github.com/feedbin/feedbin-api/blob/master/content/saved-searches.md
	//
	// [
	// 	{
	// 		"id": 1,
	// 		"name": "JavaScript",
	// 		"query": "javascript is:unread"
	// 	}
	// ]

	let uniqueID: Int
	let name: String
	let query: String

	private struct Key {
		static let uniqueID = "id"
		static let name = "name"
		static let query = "query"
	}

	init?(jsonDictionary: [String: Any]) {
		guard let uniqueID = jsonDictionary[Key.uniqueID] as? Int else {
			return nil
		}
		guard let name = jsonDictionary[Key.name] as? String else {
			return nil
		}
		guard let query = jsonDictionary[Key.query] as? String else {
			return nil
		}
		self.uniqueID = uniqueID
		self.name = name
		self.query = query
	}

	static func savedSearches(with jsonArray: [Any]) -> Set<FeedbinSavedSearch> {
		let searches = jsonArray.compactMap { (oneSearch) -> FeedbinSavedSearch? in
			if let oneSearch = oneSearch as? [String: Any] {
				return FeedbinSavedSearch(jsonDictionary: oneSearch)
			}
			return nil
		}
		return Set(searches)
	}
}
