//
//  ActivityOwner.swift
//  ActivityLog
//
//  Created by Brent Simmons on 4/4/26.
//

import Foundation

public enum ActivityOwner: Sendable, Hashable {

	case app
	case account(accountID: String, displayName: String)
	case feedFinder
	case feedImageDownloader
	case faviconDownloader
	case avatarDownloader
	case htmlMetadataDownloader

	public var displayName: String {
		switch self {
		case .app:
			return "NetNewsWire"
		case .account(_, let displayName):
			return displayName
		case .feedFinder:
			return NSLocalizedString("Feed Finder", bundle: .module, comment: "Activity owner name")
		case .feedImageDownloader:
			return NSLocalizedString("Feed Images", bundle: .module, comment: "Activity owner name")
		case .faviconDownloader:
			return NSLocalizedString("Favicons", bundle: .module, comment: "Activity owner name")
		case .avatarDownloader:
			return NSLocalizedString("Avatars", bundle: .module, comment: "Activity owner name")
		case .htmlMetadataDownloader:
			return NSLocalizedString("HTML Metadata", bundle: .module, comment: "Activity owner name")
		}
	}

	// Custom Equatable/Hashable: identity for `.account` is the accountID alone, so a
	// rename mid-flight doesn't fragment lookups (`pendingActivities(for: owner)` etc).

	public static func == (lhs: ActivityOwner, rhs: ActivityOwner) -> Bool {
		switch (lhs, rhs) {
		case (.app, .app),
			(.feedFinder, .feedFinder),
			(.feedImageDownloader, .feedImageDownloader),
			(.faviconDownloader, .faviconDownloader),
			(.avatarDownloader, .avatarDownloader),
			(.htmlMetadataDownloader, .htmlMetadataDownloader):
			return true
		case (.account(let lhsID, _), .account(let rhsID, _)):
			return lhsID == rhsID
		default:
			return false
		}
	}

	public func hash(into hasher: inout Hasher) {
		switch self {
		case .app:
			hasher.combine(0)
		case .account(let accountID, _):
			hasher.combine(1)
			hasher.combine(accountID)
		case .feedFinder:
			hasher.combine(2)
		case .feedImageDownloader:
			hasher.combine(3)
		case .faviconDownloader:
			hasher.combine(4)
		case .avatarDownloader:
			hasher.combine(5)
		case .htmlMetadataDownloader:
			hasher.combine(6)
		}
	}
}
