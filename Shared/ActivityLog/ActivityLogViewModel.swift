//
//  ActivityLogViewModel.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 6/11/26.
//

import Foundation
import ActivityLog

enum ActivityLogTextColor {
	case primary
	case secondary
	case success
	case failure
	case account(accountID: String?)
}

enum ActivityLogTextWeight {
	case regular
	case medium
	case bold
}

struct ActivityLogTextSegment {
	let text: String
	let color: ActivityLogTextColor
	let weight: ActivityLogTextWeight
}

@MainActor final class ActivityLogViewModel {

	static func segments(for activity: Activity) -> [ActivityLogTextSegment] {
		var result = [ActivityLogTextSegment]()

		let date = activity.endDate ?? Date()
		result.append(ActivityLogTextSegment(text: "[\(DateFormatter.logTimestamp.string(from: date))] ", color: .secondary, weight: .regular))

		let isFailed = activity.state == .failed
		let indicator = isFailed ? "✗ " : "✓ "
		result.append(ActivityLogTextSegment(text: indicator, color: isFailed ? .failure : .success, weight: .bold))

		let ownerColor = ownerColor(for: activity.owner)
		result.append(ActivityLogTextSegment(text: "\(activity.owner.displayName): ", color: ownerColor, weight: .medium))
		result.append(ActivityLogTextSegment(text: activity.kind.displayName(detail: activity.detail), color: ownerColor, weight: .medium))

		if let detail = secondaryDetail(for: activity) {
			result.append(ActivityLogTextSegment(text: " \(detail)", color: .secondary, weight: .regular))
		}

		if let formattedDuration = activity.formattedDuration {
			result.append(ActivityLogTextSegment(text: " (\(formattedDuration))", color: .secondary, weight: .regular))
		}

		// e.g. skip reason
		if let message = activity.completionMessage {
			result.append(ActivityLogTextSegment(text: " — \(message)", color: .secondary, weight: .regular))
		}

		if activity.returnedFromCache {
			let fromCacheText = NSLocalizedString("from cache", comment: "Activity log — appended when a download was served from cache instead of the network")
			result.append(ActivityLogTextSegment(text: " — \(fromCacheText)", color: .secondary, weight: .regular))
		}

		if isFailed, let error = activity.error {
			result.append(ActivityLogTextSegment(text: " — \(error.localizedDescription)", color: .failure, weight: .regular))
		}

		return result
	}
}

// MARK: - Private

private extension ActivityLogViewModel {

	static func ownerColor(for owner: ActivityOwner) -> ActivityLogTextColor {
		switch owner {
		case .account(let accountID, _):
			return .account(accountID: accountID)
		case .app, .feedFinder, .feedImageDownloader, .faviconDownloader, .avatarDownloader, .htmlMetadataDownloader:
			return .secondary
		}
	}

	/// Feed-content activities show the URL as detail when the feed name is the primary text.
	static func secondaryDetail(for activity: Activity) -> String? {
		switch activity.kind {
		case .refreshFeedContent(let feedURL):
			return activity.detail == nil ? nil : feedURL
		case .downloadHTMLMetadata:
			guard let detail = activity.detail else {
				return nil
			}
			let format = NSLocalizedString("(last downloaded %@)", comment: "Activity log — when HTML metadata for a URL was last downloaded — %@ is a date")
			return String(format: format, detail)
		default:
			return activity.detail
		}
	}
}
