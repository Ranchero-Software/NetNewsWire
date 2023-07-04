//
//  UserInfoKey.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 11/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

// Used for state restoration — don’t change the values.
struct UserInfoKey {

	static let webFeed = "webFeed"
	static let url = "url"
	static let articlePath = "articlePath"
	static let itemIdentifier = "feedIdentifier"
	
	static let windowState = "windowState"
	static let windowFullScreenState = "windowFullScreenState"
	static let containerExpandedWindowState = "containerExpandedWindowState"
	static let readFeedsFilterState = "readFeedsFilterState"
	static let readArticlesFilterState = "readArticlesFilterState"
	static let readArticlesFilterStateKeys = "readArticlesFilterStateKey"
	static let readArticlesFilterStateValues = "readArticlesFilterStateValue"
	static let selectedFeedsState = "selectedFeedsState"
	static let isShowingExtractedArticle = "isShowingExtractedArticle"
	static let articleWindowScrollY = "articleWindowScrollY"
	static let isSidebarHidden = "isSidebarHidden"
	
}
