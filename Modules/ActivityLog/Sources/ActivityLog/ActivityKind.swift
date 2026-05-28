//
//  ActivityKind.swift
//  ActivityLog
//
//  Created by Brent Simmons on 4/4/26.
//

/// The kind of work an activity represents. Cases that have a URL
/// are unique. The rest are one per owner.
public enum ActivityKind: Sendable, Hashable {

	// Account-related

	case sendArticleStatuses
	case refreshArticleStatuses
	case refreshFeedList
	case refreshFeedContent(feedURL: String) // per-feed
	case refreshMissingArticles
	case importOPML

	// App-level

	case refreshAll

	// Non-account

	case findFeed(urlString: String)
	case downloadFeedImage(feedURL: String)
	case downloadHTMLMetadata(urlString: String)
}
