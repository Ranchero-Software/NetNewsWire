//
//  SyncStatus.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import RSDatabase

nonisolated public struct SyncStatus: Hashable, Equatable {
	public enum Key: String {
		case read
		case starred
		case deleted
		case new

		public init(_ articleStatusKey: ArticleStatus.Key) {
			switch articleStatusKey {
			case .read:
				self = Self.read
			case .starred:
				self = Self.starred
			}
		}
	}

	public let articleID: String
	public let key: SyncStatus.Key
	public let flag: Bool
	public let selected: Bool

	public init(articleID: String, key: SyncStatus.Key, flag: Bool, selected: Bool = false) {
		self.articleID = articleID
		self.key = key
		self.flag = flag
		self.selected = selected
	}

	public func databaseDictionary() -> DatabaseDictionary {
		[DatabaseKey.articleID: articleID, DatabaseKey.key: key.rawValue, DatabaseKey.flag: flag, DatabaseKey.selected: selected]
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(articleID)
		hasher.combine(key)
	}
}
