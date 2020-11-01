//
//  TwitterFeedProvider+Extensions.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account

extension TwitterFeedProvider: ExtensionPoint {
	
	static var isSinglton = false
	static var isDeveloperBuildRestricted = true
	static var title = NSLocalizedString("Twitter", comment: "Twitter")
	static var image = AppAssets.extensionPointTwitter
	static var description: NSAttributedString = {
		return TwitterFeedProvider.makeAttrString("This extension enables you to subscribe to Twitter URLs as if they were RSS feeds. It only works with \(Account.defaultLocalAccountName) or iCloud accounts.")
	}()

	var extensionPointID: ExtensionPointIdentifer {
		return ExtensionPointIdentifer.twitter(screenName)
	}

	var title: String {
		return "@\(screenName)"
	}

}
