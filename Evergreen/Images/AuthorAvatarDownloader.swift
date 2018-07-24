//
//  AuthorAvatarDownloader.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import Articles

extension Notification.Name {

	static let AvatarDidBecomeAvailable = Notification.Name("AvatarDidBecomeAvailableNotification") // UserInfoKey.imageURL (which is an avatarURL)
}

final class AuthorAvatarDownloader {

	private let imageDownloader: ImageDownloader
	private var cache = [String: NSImage]() // avatarURL: NSImage
	private var waitingForAvatarURLs = Set<String>()

	init(imageDownloader: ImageDownloader) {

		self.imageDownloader = imageDownloader
		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .ImageDidBecomeAvailable, object: imageDownloader)
	}

	func image(for author: Author) -> NSImage? {

		guard let avatarURL = author.avatarURL else {
			return nil
		}
		if let cachedImage = cache[avatarURL] {
			return cachedImage
		}
		if let image = imageDownloader.image(for: avatarURL) {
			handleImageDidBecomeAvailable(avatarURL, image)
			return image
		}
		else {
			waitingForAvatarURLs.insert(avatarURL)
		}

		return nil
	}

	@objc func imageDidBecomeAvailable(_ note: Notification) {

		guard let avatarURL = note.userInfo?[UserInfoKey.url] as? String else {
			return
		}
		guard waitingForAvatarURLs.contains(avatarURL) else {
			return
		}
		guard let image = imageDownloader.image(for: avatarURL) else {
			return
		}

		handleImageDidBecomeAvailable(avatarURL, image)
	}
}

private extension AuthorAvatarDownloader {

	func handleImageDidBecomeAvailable(_ avatarURL: String, _ image: NSImage) {

		if cache[avatarURL] == nil {
			cache[avatarURL] = image
		}
		if waitingForAvatarURLs.contains(avatarURL) {
			waitingForAvatarURLs.remove(avatarURL)
			postAvatarDidBecomeAvailableNotification(avatarURL)
		}
	}

	func postAvatarDidBecomeAvailableNotification(_ avatarURL: String) {

		DispatchQueue.main.async {
 			NotificationCenter.default.post(name: .AvatarDidBecomeAvailable, object: self, userInfo: [UserInfoKey.url: avatarURL])
		}
	}
}
