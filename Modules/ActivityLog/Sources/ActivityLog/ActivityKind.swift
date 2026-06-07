//
//  ActivityKind.swift
//  ActivityLog
//
//  Created by Brent Simmons on 4/4/26.
//

import Foundation

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
	case restoreFeed
	case createFolder
	case renameFolder
	case removeFolder
	case restoreFolder

	// CloudKit background work

	case cleanUpCloudKitRecords
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
	case fetchFeedCandidate(urlString: String)
	case downloadFeedImage(feedURL: String)
	case downloadFavicon(faviconURL: String)
	case downloadAvatar(avatarURL: String)
	case downloadHTMLMetadata(urlString: String)

	/// Localized description for activity kinds that don't carry a URL to display separately.
	/// Returns nil for the URL-bearing cases — each caller renders its own primary + URL form.
	public var simpleDisplayName: String? {
		switch self {
		case .refreshAll:
			return NSLocalizedString("Refresh all", bundle: .module, comment: "Activity kind")
		case .sendArticleStatuses:
			return NSLocalizedString("Sending statuses", bundle: .module, comment: "Activity kind")
		case .refreshArticleStatuses:
			return NSLocalizedString("Refreshing statuses", bundle: .module, comment: "Activity kind")
		case .refreshFeedList:
			return NSLocalizedString("Refreshing feed list", bundle: .module, comment: "Activity kind")
		case .refreshMissingArticles:
			return NSLocalizedString("Refreshing missing articles", bundle: .module, comment: "Activity kind")
		case .importOPML:
			return NSLocalizedString("Importing OPML", bundle: .module, comment: "Activity kind")
		case .subscribeFeed:
			return NSLocalizedString("Subscribing to feed", bundle: .module, comment: "Activity kind")
		case .renameFeed:
			return NSLocalizedString("Renaming feed", bundle: .module, comment: "Activity kind")
		case .removeFeed:
			return NSLocalizedString("Removing feed", bundle: .module, comment: "Activity kind")
		case .moveFeed:
			return NSLocalizedString("Moving feed", bundle: .module, comment: "Activity kind")
		case .addFeed:
			return NSLocalizedString("Adding feed", bundle: .module, comment: "Activity kind")
		case .restoreFeed:
			return NSLocalizedString("Restoring feed", bundle: .module, comment: "Activity kind")
		case .createFolder:
			return NSLocalizedString("Creating folder", bundle: .module, comment: "Activity kind")
		case .renameFolder:
			return NSLocalizedString("Renaming folder", bundle: .module, comment: "Activity kind")
		case .removeFolder:
			return NSLocalizedString("Removing folder", bundle: .module, comment: "Activity kind")
		case .restoreFolder:
			return NSLocalizedString("Restoring folder", bundle: .module, comment: "Activity kind")
		case .cleanUpCloudKitRecords:
			return NSLocalizedString("Cleaning up iCloud records", bundle: .module, comment: "Activity kind")
		case .fetchCloudKitStats:
			return NSLocalizedString("Fetching iCloud stats", bundle: .module, comment: "Activity kind")
		case .subscribeToCloudKitZone:
			return NSLocalizedString("Subscribing to zone changes", bundle: .module, comment: "Activity kind")
		case .vacuumDatabase:
			return NSLocalizedString("Vacuuming database", bundle: .module, comment: "Activity kind")
		case .validateCredentials:
			return NSLocalizedString("Validating credentials", bundle: .module, comment: "Activity kind")
		case .exportOPML:
			return NSLocalizedString("Exporting OPML", bundle: .module, comment: "Activity kind")
		case .refreshFeedContent, .findFeed, .fetchFeedCandidate, .downloadFeedImage, .downloadFavicon, .downloadAvatar, .downloadHTMLMetadata:
			return nil
		}
	}
}
