//
//  ActivityKind+DisplayName.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 6/4/26.
//

import Foundation
import ActivityLog

extension ActivityKind {

	/// Localized description for activity kinds that don't carry a URL to display separately.
	/// Returns nil for the URL-bearing cases — each caller renders its own primary + URL form.
	var simpleDisplayName: String? {
		switch self {
		case .refreshAll:
			return NSLocalizedString("Refresh all", comment: "Activity kind")
		case .sendArticleStatuses:
			return NSLocalizedString("Sending statuses", comment: "Activity kind")
		case .refreshArticleStatuses:
			return NSLocalizedString("Refreshing statuses", comment: "Activity kind")
		case .refreshFeedList:
			return NSLocalizedString("Refreshing feed list", comment: "Activity kind")
		case .refreshMissingArticles:
			return NSLocalizedString("Refreshing missing articles", comment: "Activity kind")
		case .importOPML:
			return NSLocalizedString("Importing OPML", comment: "Activity kind")
		case .subscribeFeed:
			return NSLocalizedString("Subscribing to feed", comment: "Activity kind")
		case .renameFeed:
			return NSLocalizedString("Renaming feed", comment: "Activity kind")
		case .removeFeed:
			return NSLocalizedString("Removing feed", comment: "Activity kind")
		case .moveFeed:
			return NSLocalizedString("Moving feed", comment: "Activity kind")
		case .addFeed:
			return NSLocalizedString("Adding feed", comment: "Activity kind")
		case .createFolder:
			return NSLocalizedString("Creating folder", comment: "Activity kind")
		case .renameFolder:
			return NSLocalizedString("Renaming folder", comment: "Activity kind")
		case .removeFolder:
			return NSLocalizedString("Removing folder", comment: "Activity kind")
		case .restoreFolder:
			return NSLocalizedString("Restoring folder", comment: "Activity kind")
		case .cleanUpCloudKitRecords:
			return NSLocalizedString("Cleaning up iCloud records", comment: "Activity kind")
		case .fetchCloudKitStats:
			return NSLocalizedString("Fetching iCloud stats", comment: "Activity kind")
		case .subscribeToCloudKitZone:
			return NSLocalizedString("Subscribing to zone changes", comment: "Activity kind")
		case .vacuumDatabase:
			return NSLocalizedString("Vacuuming database", comment: "Activity kind")
		case .validateCredentials:
			return NSLocalizedString("Validating credentials", comment: "Activity kind")
		case .exportOPML:
			return NSLocalizedString("Exporting OPML", comment: "Activity kind")
		case .refreshFeedContent, .findFeed, .fetchFeedCandidate, .downloadFeedImage, .downloadFavicon, .downloadAvatar, .downloadHTMLMetadata:
			return nil
		}
	}
}
