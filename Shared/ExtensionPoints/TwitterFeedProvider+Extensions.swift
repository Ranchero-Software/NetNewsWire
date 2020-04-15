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
import OAuthSwift
import Secrets

extension TwitterFeedProvider: ExtensionPoint {
	
	static var isSinglton = false
	static var title = NSLocalizedString("Twitter", comment: "Twitter")
	static var templateImage = AppAssets.extensionPointTwitter
	static var description: NSAttributedString = {
		let attrString = TwitterFeedProvider.makeAttrString("This extension enables you to subscribe to Twitter URL's as if they were RSS feeds.")
		let range = NSRange(location: 43, length: 7)
		attrString.beginEditing()
		attrString.addAttribute(NSAttributedString.Key.link, value: "https://twitter.com", range: range)
		attrString.addAttribute(NSAttributedString.Key.foregroundColor, value: NSColor.systemBlue, range: range)
		attrString.endEditing()
		return attrString
	}()

	var extensionPointID: ExtensionPointIdentifer {
		return ExtensionPointIdentifer.twitter(userID)
	}

	var title: String {
		return "@\(screenName)"
	}

}

extension TwitterFeedProvider: OAuth1SwiftProvider {
	
	public static var oauth1Swift: OAuth1Swift {
		return OAuth1Swift(
			consumerKey: Secrets.twitterConsumerKey,
			consumerSecret: Secrets.twitterConsumerSecret,
			requestTokenUrl: "https://api.twitter.com/oauth/request_token",
			authorizeUrl:    "https://api.twitter.com/oauth/authorize",
			accessTokenUrl:  "https://api.twitter.com/oauth/access_token"
		)
	}
	
}
