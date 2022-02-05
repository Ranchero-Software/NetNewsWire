//
//  RefreshInterval.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

enum RefreshInterval: Int, CaseIterable, Identifiable {
	case manually = 1
	case every10Minutes = 2
	case every30Minutes = 3
	case everyHour = 4
	case every2Hours = 5
	case every4Hours = 6
	case every8Hours = 7
	
	func inSeconds() -> TimeInterval {
		switch self {
		case .manually:
			return 0
		case .every10Minutes:
			return 10 * 60
		case .every30Minutes:
			return 30 * 60
		case .everyHour:
			return 60 * 60
		case .every2Hours:
			return 2 * 60 * 60
		case .every4Hours:
			return 4 * 60 * 60
		case .every8Hours:
			return 8 * 60 * 60
		}
	}
	
	var id: String { description() }
	
	func description() -> String {
		switch self {
		case .manually:
			return NSLocalizedString("REFRESH_MANUALLY", comment: "Manually")
		case .every10Minutes:
			return NSLocalizedString("REFRESH_10_MINUTES", comment: "Every 10 Minutes")
		case .every30Minutes:
			return NSLocalizedString("REFRESH_30_MINUTES", comment: "Every 30 Minutes")
		case .everyHour:
			return NSLocalizedString("REFRESH_HOURLY", comment: "Every Hour")
		case .every2Hours:
			return NSLocalizedString("REFRESH_2_HOURS", comment: "Every 2 Hours")
		case .every4Hours:
			return NSLocalizedString("REFRESH_4_HOURS", comment: "Every 4 Hours")
		case .every8Hours:
			return NSLocalizedString("REFRESH_8_HOURS", comment: "Every 8 Hours")
		}
	}
	
}
