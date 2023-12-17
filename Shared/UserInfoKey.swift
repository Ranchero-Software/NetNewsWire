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

	static let feed = "webFeed"
	static let url = "url"
	static let articlePath = "articlePath"
	static let itemIdentifier = "feedIdentifier"
	
	static let windowState = "windowState"

	static let articleWindowScrollY = "articleWindowScrollY"
	
}
