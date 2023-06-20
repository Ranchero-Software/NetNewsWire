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
            return String(localized: "Best", bundle: .module, comment: "Best")
		case .rising:
            return String(localized:"Rising", bundle: .module, comment: "Rising")
		case .hot:
            return String(localized:"Hot", bundle: .module, comment: "Hot")
		case .new:
            return String(localized:"New", bundle: .module, comment: "New")
		case .top:
            return String(localized:"Top", bundle: .module, comment: "Top")
		}
	}
}
