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
	case followFeedRedirect
	case refreshArticles
	case fetchArticleIDs
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
	case scanCloudKitStatusRecords
	case scanCloudKitArticleRecords
	case receiveCloudKitNotification

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
		case .followFeedRedirect:
			return NSLocalizedString("Feed redirect", bundle: .module, comment: "Activity kind")
		case .refreshArticles:
			return NSLocalizedString("Refreshing articles", bundle: .module, comment: "Activity kind")
		case .fetchArticleIDs:
			return NSLocalizedString("Fetching article IDs", bundle: .module, comment: "Activity kind")
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
		case .scanCloudKitStatusRecords:
			return NSLocalizedString("Scanning iCloud status records", bundle: .module, comment: "Activity kind")
		case .scanCloudKitArticleRecords:
			return NSLocalizedString("Scanning iCloud article records", bundle: .module, comment: "Activity kind")
		case .receiveCloudKitNotification:
			return NSLocalizedString("Receiving sync notification", bundle: .module, comment: "Activity kind")
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

	/// Full localized display name for the activity. For kinds that show a feed name
	/// or URL, `detail` provides the feed name, falling back to the URL.
	public func displayName(detail: String?) -> String {
		if let simpleDisplayName {
			return simpleDisplayName
		}
		switch self {
		case .refreshFeedContent(let feedURL):
			let format = NSLocalizedString("Refreshing feed: %@", bundle: .module, comment: "Activity kind — refreshing a feed — %@ is the feed name or URL")
			return String(format: format, detail ?? feedURL)
		case .findFeed(let urlString):
			let format = NSLocalizedString("Finding feed %@", bundle: .module, comment: "Activity kind — finding a feed at %@ URL")
			return String(format: format, urlString)
		case .fetchFeedCandidate(let urlString):
			let format = NSLocalizedString("Fetching %@", bundle: .module, comment: "Activity kind — fetching a candidate URL during feed finding")
			return String(format: format, urlString)
		case .downloadFeedImage(let feedURL):
			let format = NSLocalizedString("Downloading image %@", bundle: .module, comment: "Activity kind — downloading a feed image — %@ is the URL")
			return String(format: format, feedURL)
		case .downloadFavicon(let faviconURL):
			let format = NSLocalizedString("Downloading favicon %@", bundle: .module, comment: "Activity kind — downloading a favicon — %@ is the URL")
			return String(format: format, faviconURL)
		case .downloadAvatar(let avatarURL):
			let format = NSLocalizedString("Downloading avatar %@", bundle: .module, comment: "Activity kind — downloading an author avatar — %@ is the URL")
			return String(format: format, avatarURL)
		case .downloadHTMLMetadata(let urlString):
			let format = NSLocalizedString("Downloading metadata %@", bundle: .module, comment: "Activity kind — downloading HTML metadata — %@ is the URL")
			return String(format: format, urlString)
		default:
			return ""
		}
	}
}
