//
//  FeedlyMarkArticlesService.swift
//  Account
//
//  Created by Kiel Gillard on 21/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

enum FeedlyMarkAction: String {
	 case read
	 case unread
	 case saved
	 case unsaved
	 
	/// These values are paired with the "action" key in POST requests to the markers API.
	/// See for example: https://developer.feedly.com/v3/markers/#mark-one-or-multiple-articles-as-read
	 var actionValue: String {
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

protocol FeedlyMarkArticlesService: AnyObject {
	func mark(_ articleIds: Set<String>, as action: FeedlyMarkAction, completion: @escaping (Result<Void, Error>) -> ())
}
