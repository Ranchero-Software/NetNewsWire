//
//  Feed.swift
//  Account
//
//  Created by Maurice Parker on 11/15/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

public enum ReadFilterType {
	case read
	case none
	case alwaysRead
}

public protocol Feed: FeedIdentifiable, ArticleFetcher, DisplayNameProvider, UnreadCountProvider {

	var defaultReadFilterType: ReadFilterType { get }
	
}

public extension Feed {
	
	func readFiltered(readFilterEnabledTable: [FeedIdentifier: Bool]) -> Bool {
		guard defaultReadFilterType != .alwaysRead else {
			return true
		}
		if let feedID = feedID, let readFilterEnabled = readFilterEnabledTable[feedID] {
			return readFilterEnabled
		} else {
			return defaultReadFilterType == .read
		}

	}
	
}
