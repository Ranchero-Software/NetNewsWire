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
	
	var extensionPointType: ExtensionPointType {
		return ExtensionPointType.twitter
	}
	
	var extensionPointID: ExtensionPointIdentifer {
		return ExtensionPointIdentifer.twitter(username)
	}

}
