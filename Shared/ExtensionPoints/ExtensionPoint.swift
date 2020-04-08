//
//  ExtensionPoint.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

enum ExtensionPointType {
	case marsEdit
	case microblog
	case twitter

	var title: String {
		switch self {
		case .marsEdit:
			return NSLocalizedString("MarsEdit", comment: "MarsEdit")
		case .microblog:
			return NSLocalizedString("Micro.blog", comment: "Micro.blog")
		case .twitter:
			return NSLocalizedString("Twitter", comment: "Twitter")
		}

	}

	var templateImage: RSImage {
		switch self {
		case .marsEdit:
			return AppAssets.extensionPointMarsEdit
		case .microblog:
			return AppAssets.extensionPointMicroblog
		case .twitter:
			return AppAssets.extensionPointTwitter
		}
	}

}

enum ExtensionPointIdentifer: Hashable {
	case marsEdit
	case microblog
	case twitter(String)

	var title: String {
		switch self {
		case .marsEdit:
			return ExtensionPointType.marsEdit.title
		case .microblog:
			return ExtensionPointType.microblog.title
		case .twitter(let username):
			return "\(ExtensionPointType.microblog.title) (\(username))"
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
		case .twitter(let username):
			return [
				"type": "feed",
				"username": username
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
			guard let username = userInfo["username"] as? String else { return nil }
			self = ExtensionPointIdentifer.twitter(username)
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
		case .twitter(let username):
			hasher.combine("twitter")
			hasher.combine(username)
		}
	}
}

protocol ExtensionPoint {

	var extensionPointType: ExtensionPointType { get }
	var extensionPointID: ExtensionPointIdentifer { get }
	
}

extension ExtensionPoint {
	
	var title: String {
		return extensionPointID.title
	}
	
}
