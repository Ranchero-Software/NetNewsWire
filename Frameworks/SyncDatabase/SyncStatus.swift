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

public struct SyncStatus: Hashable, Equatable {
	
	public let articleID: String
	public let key: ArticleStatus.Key
	public let flag: Bool
	public let selected: Bool
	
	public init(articleID: String, key: ArticleStatus.Key, flag: Bool, selected: Bool = false) {
		self.articleID = articleID
		self.key = key
		self.flag = flag
		self.selected = selected
	}
	
	public func databaseDictionary() -> DatabaseDictionary {
		return [DatabaseKey.articleID: articleID, DatabaseKey.key: key.rawValue, DatabaseKey.flag: flag, DatabaseKey.selected: selected]
	}
	
}
