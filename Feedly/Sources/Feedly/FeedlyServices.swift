//
//  FeedlyServices.swift
//  
//
//  Created by Brent Simmons on 4/27/24.
//  Includes text of a bunch of files created by Kiel Gillard 2019
//

import Foundation

public protocol FeedlyGetCollectionsService: AnyObject {

	@MainActor func getCollections() async throws -> [FeedlyCollection]
}

public protocol FeedlyGetEntriesService: AnyObject {

	@MainActor func getEntries(for ids: Set<String>) async throws -> [FeedlyEntry]
}

public protocol FeedlyGetStreamContentsService: AnyObject {

	@MainActor func getStreamContents(for resource: FeedlyResourceID, continuation: String?, newerThan: Date?, unreadOnly: Bool?) async throws -> FeedlyStream
}

public protocol FeedlyGetStreamIDsService: AnyObject {

	@MainActor func getStreamIDs(for resource: FeedlyResourceID, continuation: String?, newerThan: Date?, unreadOnly: Bool?) async throws -> FeedlyStreamIDs
}

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

	@MainActor func mark(_ articleIDs: Set<String>, as action: FeedlyMarkAction) async throws
}
