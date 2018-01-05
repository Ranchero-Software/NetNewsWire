//
//  AuthorAvatarDownloader.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa
import Data

extension Notification.Name {

	static let AvatarDidBecomeAvailable = Notification.Name("AvatarDidBecomeAvailableNotification") // UserInfoKey.author
}

final class AuthorAvatarDownloader {

	private let imageDownloader: ImageDownloader
	private var cache = [String: NSImage]() // avatarURL: NSImage

	init(imageDownloader: ImageDownloader) {

		self.imageDownloader = imageDownloader
	}

	func image(for author: Author) -> NSImage? {

		guard let avatarURL = author.avatarURL else {
			return nil
		}
		if let cachedImage = cache[avatarURL] {
			return cachedImage
		}
		if let image = imageDownloader.image(for: avatarURL) {
			cache[avatarURL] = image
			postAvatarDidBecomeAvailableNotification(author)
			return image
		}
		return nil
	}
}

private extension AuthorAvatarDownloader {

	func postAvatarDidBecomeAvailableNotification(_ author: Author) {

		DispatchQueue.main.async {
			let userInfo: [AnyHashable: Any] = [UserInfoKey.author: author]
			NotificationCenter.default.post(name: .AvatarDidBecomeAvailable, object: self, userInfo: userInfo)
		}
	}
}
