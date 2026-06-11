//
//  ActivityLogViewModel.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 6/11/26.
//

import Foundation
import ActivityLog

/// Platform-neutral formatting for the Activity Log. Builds the styled segments and plain
/// text for one completed activity. Each platform maps the semantic colors and weights to
/// its own color and font types.

enum ActivityLogTextColor {
	case primary
	case secondary
	case success
	case failure
	case account(accountID: String?) // resolves to the account's logColor, or secondary
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
		result.append(ActivityLogTextSegment(text: plainDescription(for: activity), color: ownerColor, weight: .medium))

		if let detail = secondaryDetail(for: activity) {
			result.append(ActivityLogTextSegment(text: " \(detail)", color: .secondary, weight: .regular))
		}

		if activity.durationIsSignificant, let startDate = activity.startDate, let endDate = activity.endDate {
			let duration = endDate.timeIntervalSince(startDate)
			result.append(ActivityLogTextSegment(text: " (\(formattedDuration(duration)))", color: .secondary, weight: .regular))
		}

		// e.g. skip reason
		if let message = activity.completionMessage {
			result.append(ActivityLogTextSegment(text: " — \(message)", color: .secondary, weight: .regular))
		}

		if isFailed, let error = activity.error {
			result.append(ActivityLogTextSegment(text: " — \(error.localizedDescription)", color: .failure, weight: .regular))
		}

		return result
	}

	static func plainText(for activity: Activity) -> String {
		segments(for: activity).map { $0.text }.joined()
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
		default:
			return activity.detail
		}
	}

	static func formattedDuration(_ duration: TimeInterval) -> String {
		let posix = Locale(identifier: "en_US_POSIX")
		if duration < 10.0 {
			return String(format: "%.2fs", locale: posix, duration)
		} else if duration < 60.0 {
			return String(format: "%.1fs", locale: posix, duration)
		} else {
			let minutes = Int(duration) / 60
			let seconds = Int(duration) % 60
			return "\(minutes)m \(seconds)s"
		}
	}

	static func plainDescription(for activity: Activity) -> String {
		if let simple = activity.kind.simpleDisplayName {
			return simple
		}
		switch activity.kind {
		case .refreshFeedContent(let feedURL):
			let format = NSLocalizedString("Refreshing feed: %@", comment: "Activity kind — refreshing a feed; %@ is the feed name or URL")
			return String(format: format, activity.detail ?? feedURL)
		case .findFeed(let urlString):
			let format = NSLocalizedString("Finding feed %@", comment: "Activity kind — finding a feed at %@ URL")
			return String(format: format, urlString)
		case .fetchFeedCandidate(let urlString):
			let format = NSLocalizedString("Fetching %@", comment: "Activity kind — fetching a candidate URL during feed finding")
			return String(format: format, urlString)
		case .downloadFeedImage(let feedURL):
			let format = NSLocalizedString("Downloading image %@", comment: "Activity kind — downloading a feed image; %@ is the URL")
			return String(format: format, feedURL)
		case .downloadFavicon(let faviconURL):
			let format = NSLocalizedString("Downloading favicon %@", comment: "Activity kind — downloading a favicon; %@ is the URL")
			return String(format: format, faviconURL)
		case .downloadAvatar(let avatarURL):
			let format = NSLocalizedString("Downloading avatar %@", comment: "Activity kind — downloading an author avatar; %@ is the URL")
			return String(format: format, avatarURL)
		case .downloadHTMLMetadata(let urlString):
			let format = NSLocalizedString("Downloading metadata %@", comment: "Activity kind — downloading HTML metadata; %@ is the URL")
			return String(format: format, urlString)
		default:
			return ""
		}
	}
}
