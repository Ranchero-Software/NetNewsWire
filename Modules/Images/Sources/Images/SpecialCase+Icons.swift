//
//  SpecialCase+Icons.swift
//  Images
//
//  Created by Brent Simmons on 11/3/26.
//

import Foundation
import RSWeb

extension SpecialCase {
	/// Matched anywhere in the feed URL or home page URL. A match means neither the feed icon nor the home page icon is used.
	static let hostNamesWithoutFeedOrHomePageIcons = ["macsparky.com", "xkcd.com", SpecialCase.rachelByTheBayHostName, SpecialCase.openRSSOrgHostName]
}
