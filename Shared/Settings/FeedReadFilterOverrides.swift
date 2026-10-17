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
	private var overrides = [String: [String: Override]]()

	static func migrating(legacyFeedsHiding: [String: Set<String>]) -> Self {
		var migrated = Self()
		for (accountID, feedIDs) in legacyFeedsHiding {
			for feedID in feedIDs {
				migrated.setOverride(.hide, accountID: accountID, feedID: feedID)
			}
		}
		return migrated
	}

	func override(accountID: String, feedID: String) -> Override? {
		overrides[accountID]?[feedID]
	}

	mutating func setOverride(_ value: Override, accountID: String, feedID: String) {
		overrides[accountID, default: [:]][feedID] = value
	}

	mutating func clearOverride(accountID: String, feedID: String) {
		overrides[accountID]?[feedID] = nil
		if overrides[accountID]?.isEmpty == true {
			overrides[accountID] = nil
		}
	}

	mutating func clearAll(accountID: String) {
		overrides[accountID] = nil
	}

	/// Used to drop overrides for accounts and feeds that no longer exist.
	mutating func removeAll(where shouldRemove: (_ accountID: String, _ feedID: String) -> Bool) {
		for (accountID, accountOverrides) in overrides {
			let kept = accountOverrides.filter { !shouldRemove(accountID, $0.key) }
			overrides[accountID] = kept.isEmpty ? nil : kept
		}
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
