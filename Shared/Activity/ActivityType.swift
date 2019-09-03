//
//  ActivityType.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 8/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

enum ActivityType: String {
	case selectToday = "com.ranchero.NetNewsWire.SelectToday"
	case selectAllUnread = "com.ranchero.NetNewsWire.SelectAllUnread"
	case selectStarred = "com.ranchero.NetNewsWire.SelectStarred"
	case selectFolder = "com.ranchero.NetNewsWire.SelectFolder"
	case selectFeed = "com.ranchero.NetNewsWire.SelectFeed"
	case nextUnread = "com.ranchero.NetNewsWire.NextUnread"
	case readArticle = "com.ranchero.NetNewsWire.ReadArticle"
}
