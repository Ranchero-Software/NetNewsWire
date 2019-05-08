//
//  AccountCreateFeedResult.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/8/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public enum AccountCreateFeedResult {
	case created(Feed)
	case multipleChoice([AccountCreateFeedChoice])
	case alreadySubscribed
	case notFound
}

public struct AccountCreateFeedChoice {
	let name: String
	let url: String
}
