//
//  AuthorAvatarDownloader.swift
//  Images
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import RSCore
import ActivityLog

extension Notification.Name {
	/// userInfo key: `AuthorAvatarDownloader.avatarURLKey`.
	public static let avatarDidChange = Notification.Name("AvatarDidChange")
}

@MainActor public final class AuthorAvatarDownloader {
	public static let shared = AuthorAvatarDownloader()
	public static let avatarURLKey = "avatarURL"

	private var avatarURLs = Set<String>() // Every avatar URL looked up, so a changed image is posted too

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleIconImageDidBecomeAvailable(_:)), name: .iconImageDidBecomeAvailable, object: IconImageDownloader.shared)
	}

	public func avatar(for author: Author) -> IconLookup {
		guard let avatarURL = author.avatarURL else {
			return .unavailable
		}
		avatarURLs.insert(avatarURL)
		return IconImageDownloader.shared.iconImage(for: avatarURL, activityOwner: .avatarDownloader, activityKind: .downloadAvatar(avatarURL: avatarURL), activityDetail: author.name)
	}

	@objc func handleIconImageDidBecomeAvailable(_ notification: Notification) {
		guard let avatarURL = notification.userInfo?[IconImageDownloader.urlKey] as? String, avatarURLs.contains(avatarURL) else {
			return
		}
		NotificationCenter.default.post(name: .avatarDidChange, object: self, userInfo: [Self.avatarURLKey: avatarURL])
	}
}
