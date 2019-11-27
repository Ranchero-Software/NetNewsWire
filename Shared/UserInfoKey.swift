//
//  UserInfoKey.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 11/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

typealias UserInfoDictionary = [AnyHashable: Any]

struct UserInfoKey {

	static let view = "view"
	static let article = "article"
	static let articles = "articles"
	static let navigationKeyPressed = "navigationKeyPressed"
	static let objects = "objects"
	static let webFeed = "webFeed"
	static let url = "url"
	static let author = "author"
	static let articlePath = "articlePath"
	static let feedIdentifier = "feedIdentifier"
	
	static let windowState = "windowState"
	static let containerExpandedWindowState = "containerExpandedWindowState"
	static let readFeedsFilterState = "readFeedsFilterState"
	static let readArticlesFilterState = "readArticlesFilterState"
}
