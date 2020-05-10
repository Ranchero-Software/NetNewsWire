//
//  RedditSort.swift
//  Account
//
//  Created by Maurice Parker on 5/7/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public enum RedditSort: String, CaseIterable {
	case best
	case rising
	case hot
	case new
	case top
	
	var displayName: String {
		switch self {
		case .best:
			return NSLocalizedString("Best", comment: "Best")
		case .rising:
			return NSLocalizedString("Rising", comment: "Rising")
		case .hot:
			return NSLocalizedString("Hot", comment: "Hot")
		case .new:
			return NSLocalizedString("New", comment: "New")
		case .top:
			return NSLocalizedString("Top", comment: "Top")
		}
	}
}
