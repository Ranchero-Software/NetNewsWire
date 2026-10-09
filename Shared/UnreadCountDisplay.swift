//
//  UnreadCountDisplay.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/6/26.
//

import Foundation

extension Notification.Name {
	static let unreadCountDisplaySettingDidChange = Notification.Name("UnreadCountDisplaySettingDidChangeNotification")
}

/// How unread counts are shown.
enum UnreadCountDisplay: Int, CaseIterable, Codable {
	case count = 0
	case dot = 1
	case hidden = 2

	/// Text to show for an unread count, or nil when nothing should appear.
	func text(for unreadCount: Int) -> String? {
		guard unreadCount > 0 else {
			return nil
		}
		switch self {
		case .count:
			return unreadCount.formatted()
		case .dot:
			return "•"
		case .hidden:
			return nil
		}
	}

	func showsDot(for unreadCount: Int) -> Bool {
		self == .dot && unreadCount > 0
	}

	/// Unread status for VoiceOver to read after a name — “12 unread” or, with a dot, just “unread.” Nil when nothing should be read.
	func accessibilityText(for unreadCount: Int) -> String? {
		guard unreadCount > 0 else {
			return nil
		}
		let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessibility")
		switch self {
		case .count:
			return "\(unreadCount) \(unreadLabel)"
		case .dot:
			return unreadLabel
		case .hidden:
			return nil
		}
	}
}
