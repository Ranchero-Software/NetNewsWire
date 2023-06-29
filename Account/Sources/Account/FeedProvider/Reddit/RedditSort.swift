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
            return String(localized: "displayname-best", bundle: .module, comment: "Best")
		case .rising:
            return String(localized:"displayname-rising", bundle: .module, comment: "Rising")
		case .hot:
            return String(localized:"displayname-hot", bundle: .module, comment: "Hot")
		case .new:
            return String(localized:"displayname-new", bundle: .module, comment: "New")
		case .top:
            return String(localized:"displayname-top", bundle: .module, comment: "Top")
		}
	}
}
