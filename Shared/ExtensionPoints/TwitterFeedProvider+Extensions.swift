//
//  TwitterFeedProvider+Extensions.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import FeedProvider
import RSCore

extension TwitterFeedProvider: ExtensionPoint {
	
	var title: String {
		return NSLocalizedString("Twitter", comment: "Twitter")
	}

	var templateImage: RSImage {
		return AppAssets.extensionPointTwitter
	}

}
