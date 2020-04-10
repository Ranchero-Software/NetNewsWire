//
//  FeedWranglerConfig.swift
//  NetNewsWire
//
//  Created by Jonathan Bennett on 9/27/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Secrets

enum FeedWranglerConfig {
	static let pageSize = 100
	static let clientKey = Secrets.feedWranglerKey // Add FEED_WRANGLER_KEY = XYZ to SharedXcodeSettings/DeveloperSettings.xcconfig
	static let clientPath = "https://feedwrangler.net/api/v2/"
	static let clientURL = {
		URL(string: FeedWranglerConfig.clientPath)!
	}()
}
