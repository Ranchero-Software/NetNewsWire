//
//  DeepLinkProvider.swift
//  Account
//
//  Created by Maurice Parker on 10/3/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public enum DeepLinkKey: String {
	case accountID = "accountID"
	case accountName = "accountName"
	case feedID = "feedID"
	case articleID = "articleID"
	case folderName = "folderName"
}

public protocol DeepLinkProvider {
	var deepLinkUserInfo: [AnyHashable : Any] { get }
}
