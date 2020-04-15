//
//  ExtensionPointIdentifer.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import FeedProvider
import RSCore

enum ExtensionPointIdentifer: Hashable {
	case marsEdit
	case microblog
	case twitter(String, String)
	
	var extensionPointType: ExtensionPoint.Type {
		switch self {
		case .marsEdit:
			return SendToMarsEditCommand.self
		case .microblog:
			return SendToMicroBlogCommand.self
		case .twitter:
			return TwitterFeedProvider.self
		}
	}
	
	public var userInfo: [AnyHashable: AnyHashable] {
		switch self {
		case .marsEdit:
			return [
				"type": "marsEdit"
			]
		case .microblog:
			return [
				"type": "microblog"
			]
		case .twitter(let userID, let screenName):
			return [
				"type": "twitter",
				"userID": userID,
				"screenName": screenName
			]
		}
	}
	
	public init?(userInfo: [AnyHashable: AnyHashable]) {
		guard let type = userInfo["type"] as? String else { return nil }
		
		switch type {
		case "marsEdit":
			self = ExtensionPointIdentifer.marsEdit
		case "microblog":
			self = ExtensionPointIdentifer.microblog
		case "twitter":
			guard let userID = userInfo["userID"] as? String, let screenName = userInfo["screenName"] as? String else { return nil }
			self = ExtensionPointIdentifer.twitter(userID, screenName)
		default:
			return nil
		}
	}
	
	public func hash(into hasher: inout Hasher) {
		switch self {
		case .marsEdit:
			hasher.combine("marsEdit")
		case .microblog:
			hasher.combine("microblog")
		case .twitter(let userID, let screenName):
			hasher.combine("twitter")
			hasher.combine(userID)
			hasher.combine(screenName)
		}
	}
	
}
