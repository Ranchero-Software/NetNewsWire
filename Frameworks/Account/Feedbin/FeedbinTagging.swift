//
//  FeedbinTagging.swift
//  Account
//
//  Created by Brent Simmons on 10/14/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedbinTagging: Hashable {

	// https://github.com/feedbin/feedbin-api/blob/master/content/taggings.md
	//
	// [
	// 	{
	// 		"id": 4,
	// 		"feed_id": 1,
	// 		"name": "Tech"
	// 	},
	// 	{
	// 		"id": 5,
	// 		"feed_id": 2,
	// 		"name": "News"
	// 	}
	// ]

	let taggingID: Int
	let feedID: Int
	let name: String

	private struct Key {
		static let taggingID = "id"
		static let feedID = "feed_id"
		static let name = "name"
	}

	init?(jsonDictionary: [String: Any]) {
		guard let taggingID = jsonDictionary[Key.taggingID] as? Int else {
			return nil
		}
		guard let feedID = jsonDictionary[Key.feedID] as? Int else {
			return nil
		}
		guard let name = jsonDictionary[Key.name] as? String else {
			return nil
		}
		self.taggingID = taggingID
		self.feedID = feedID
		self.name = name
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(taggingID)
	}

	// MARK: - Equatable

	public static func ==(lhs: FeedbinTagging, rhs: FeedbinTagging) -> Bool {
		return lhs.taggingID == rhs.taggingID && lhs.feedID == rhs.feedID && lhs.name == rhs.name
	}

	static func taggings(with jsonArray: [Any]) -> Set<FeedbinTagging> {

		let taggingsArray = jsonArray.compactMap { (item) -> FeedbinTagging? in
			if let oneDictionary = item as? [String: Any] {
				return FeedbinTagging(jsonDictionary: oneDictionary)
			}
			return nil
		}
		return Set(taggingsArray)
	}
}
