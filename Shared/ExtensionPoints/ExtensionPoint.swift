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

enum ExtensionPointIdentifer {
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
