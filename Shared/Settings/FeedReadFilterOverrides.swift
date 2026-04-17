//
//  FeedReadFilterOverrides.swift
//  NetNewsWire
//
//  Created by Paul on 4/3/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import Foundation

/// Stores per-feed overrides for the global hide-read-articles setting.
///
/// Each feed can override the global setting to either hide or show read articles.
/// Feeds without an override follow the global setting.
struct FeedReadFilterOverrides: Codable, Equatable {

	enum Override: String, Codable {
		case hide
		case show
	}

	/// accountID -> feedID -> Override
	private var overrides: [String: [String: Override]]

	init() {
		overrides = [:]
	}

	static func migrating(legacyFeedsHiding: [String: Set<String>]) -> Self {
		var result = [String: [String: Override]]()
		for (accountID, feedIDs) in legacyFeedsHiding {
			var accountOverrides = [String: Override]()
			for feedID in feedIDs {
				accountOverrides[feedID] = .hide
			}
			result[accountID] = accountOverrides
		}
		var migrated = Self()
		migrated.overrides = result
		return migrated
	}

	func override(accountID: String, feedID: String) -> Override? {
		overrides[accountID]?[feedID]
	}

	func hasOverride(accountID: String, feedID: String) -> Bool {
		overrides[accountID]?[feedID] != nil
	}

	mutating func setOverride(accountID: String, feedID: String, _ value: Override) {
		var accountOverrides = overrides[accountID] ?? [:]
		accountOverrides[feedID] = value
		overrides[accountID] = accountOverrides
	}

	mutating func clearOverride(accountID: String, feedID: String) {
		overrides[accountID]?.removeValue(forKey: feedID)
		if overrides[accountID]?.isEmpty == true {
			overrides[accountID] = nil
		}
	}

	mutating func clearAll(accountID: String) {
		overrides[accountID] = nil
	}

	func allFeeds() -> [(accountID: String, feedID: String, override: Override)] {
		var result = [(String, String, Override)]()
		for (accountID, accountOverrides) in overrides {
			for (feedID, value) in accountOverrides {
				result.append((accountID, feedID, value))
			}
		}
		return result
	}
}

// MARK: - UserDefaults serialization

extension FeedReadFilterOverrides {

	init(data: Data?) {
		guard let data, let decoded = try? JSONDecoder().decode(FeedReadFilterOverrides.self, from: data) else {
			self.init()
			return
		}
		self = decoded
	}

	var data: Data? {
		try? JSONEncoder().encode(self)
	}
}
