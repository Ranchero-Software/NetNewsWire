//
//  FeedlyMarkArticlesService.swift
//  Account
//
//  Created by Kiel Gillard on 21/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public enum FeedlyMarkAction: String, Sendable {

	case read
	case unread
	case saved
	case unsaved

	/// These values are paired with the "action" key in POST requests to the markers API.
	/// See for example: https://developer.feedly.com/v3/markers/#mark-one-or-multiple-articles-as-read
	public var actionValue: String {
		switch self {
		case .read:
			return "markAsRead"
		case .unread:
			return "keepUnread"
		case .saved:
			return "markAsSaved"
		case .unsaved:
			return "markAsUnsaved"
		}
	}
}

public protocol FeedlyMarkArticlesService: AnyObject {

	func mark(_ articleIDs: Set<String>, as action: FeedlyMarkAction, completion: @escaping @Sendable (Result<Void, Error>) -> ())
}
