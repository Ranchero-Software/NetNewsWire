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

	// CloudKit user-action edits

	case subscribeFeed
	case renameFeed
	case removeFeed
	case moveFeed
	case addFeed
	case createFolder
	case renameFolder
	case removeFolder
	case restoreFolder

	// CloudKit background work

	case markArticles
	case cleanUpCloudKitRecords
	case uploadNewArticles
	case subscribeToCloudKitZone
	case fetchCloudKitStats

	// Maintenance and lifecycle

	case vacuumDatabase
	case validateCredentials
	case exportOPML

	// App-level

	case refreshAll

	// Non-account

	case findFeed(urlString: String)
	case downloadFeedImage(feedURL: String)
	case downloadFavicon(faviconURL: String)
	case downloadAvatar(avatarURL: String)
	case downloadHTMLMetadata(urlString: String)
}
