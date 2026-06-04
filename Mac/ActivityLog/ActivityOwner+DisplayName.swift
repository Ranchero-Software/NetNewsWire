//
//  ActivityOwner+DisplayName.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 6/4/26.
//

import Foundation
import Account
import ActivityLog

extension ActivityOwner {

	@MainActor var displayName: String {
		switch self {
		case .app:
			return "NetNewsWire"
		case .account(let accountID):
			return AccountManager.shared.existingAccount(accountID: accountID)?.nameForDisplay ?? accountID
		case .feedFinder:
			return NSLocalizedString("Feed Finder", comment: "Activity owner name")
		case .feedImageDownloader:
			return NSLocalizedString("Feed Images", comment: "Activity owner name")
		case .faviconDownloader:
			return NSLocalizedString("Favicons", comment: "Activity owner name")
		case .avatarDownloader:
			return NSLocalizedString("Avatars", comment: "Activity owner name")
		case .htmlMetadataDownloader:
			return NSLocalizedString("HTML Metadata", comment: "Activity owner name")
		}
	}
}
