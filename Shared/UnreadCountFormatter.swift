//
//  UnreadCountFormatter.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/26/24.
//  Copyright © 2024 Ranchero Software. All rights reserved.
//

import Foundation

@MainActor struct UnreadCountFormatter {

	private static let formatter: NumberFormatter = {
		let nf = NumberFormatter()
		nf.locale = Locale.current
		nf.numberStyle = .decimal
		return nf
	}()

	static func string(from unreadCount: Int) -> String {
		if unreadCount < 1 {
			return ""
		}

		return formatter.string(from: NSNumber(value: unreadCount))!
	}
}
