//
//  ArticlePathInfo.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/18/24.
//  Copyright © 2024 Ranchero Software. All rights reserved.
//

import Foundation

struct ArticlePathInfo {

	let accountID: String
	let articleID: String

	init?(userInfo: [AnyHashable: Any]) {

		guard let articlePathUserInfo = userInfo[UserInfoKey.articlePath] as? [String: String] else {
			return nil
		}
		guard let accountID = articlePathUserInfo[ArticlePathKey.accountID] else {
			return nil
		}
		guard let articleID = articlePathUserInfo[ArticlePathKey.articleID] else {
			return nil
		}

		self.accountID = accountID
		self.articleID = articleID
	}
}
