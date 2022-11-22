//
//  AddFeed+Errors.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 22/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import Foundation

enum AddWebFeedError: LocalizedError {
	
	case none, alreadySubscribed, initialDownload, noFeeds
	
	var errorDescription: String? {
		switch self {
		case .alreadySubscribed:
			return NSLocalizedString("Can't add this feed because you've already subscribed to it.", comment: "Feed finder")
		case .initialDownload:
			return NSLocalizedString("Can't add this feed because of a download error.", comment: "Feed finder")
		case .noFeeds:
			return NSLocalizedString("Can't add a feed because no feed was found.", comment: "Feed finder")
		default:
			return nil
		}
	}
	
}
