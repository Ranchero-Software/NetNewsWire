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
	public static let AvatarDidBecomeAvailable = Notification.Name("AvatarDidBecomeAvailableNotification") // userInfo key: "url" (the avatarURL)
}

@MainActor public final class AuthorAvatarDownloader {
	public static let shared = AuthorAvatarDownloader()

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
		postAvatarDidBecomeAvailableNotification(avatarURL)
	}
}

@MainActor private extension AuthorAvatarDownloader {

	func postAvatarDidBecomeAvailableNotification(_ avatarURL: String) {
		DispatchQueue.main.async {
			NotificationCenter.default.post(name: .AvatarDidBecomeAvailable, object: self, userInfo: ["url": avatarURL])
		}
	}
}
