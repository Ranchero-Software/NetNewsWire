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

	private let imageDownloader = ImageDownloader.shared
	private var cache = [String: IconImage]() // avatarURL: RSImage
	private var waitingForAvatarURLs = Set<String>()

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .imageDidBecomeAvailable, object: imageDownloader)
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
	}

	@objc func handleLowMemory(_ notification: Notification) {
		cache.removeAll()
	}

	@objc func handleAppDidGoToBackground(_ notification: Notification) {
		cache.removeAll()
	}

	public func image(for author: Author) -> IconImage? {

		guard let avatarURL = author.avatarURL else {
			return nil
		}

		if let cachedImage = cache[avatarURL] {
			return cachedImage
		}

		let kind = ActivityKind.downloadAvatar(avatarURL: avatarURL)
		if let imageData = imageDownloader.image(for: avatarURL, activityOwner: .avatarDownloader, activityKind: kind, activityDetail: author.name) {
			scaleAndCacheImageData(imageData, avatarURL)
		} else {
			waitingForAvatarURLs.insert(avatarURL)
		}

		return nil
	}

	public func cachedImage(for author: Author) -> IconImage? {
		guard let avatarURL = author.avatarURL else {
			return nil
		}
		return cache[avatarURL]
	}

	@objc func imageDidBecomeAvailable(_ note: Notification) {
		guard let avatarURL = note.userInfo?["url"] as? String else {
			return
		}
		guard waitingForAvatarURLs.contains(avatarURL) else {
			return
		}
		guard let imageData = imageDownloader.image(for: avatarURL) else {
			return
		}
		scaleAndCacheImageData(imageData, avatarURL)
	}
}

@MainActor private extension AuthorAvatarDownloader {

	func scaleAndCacheImageData(_ imageData: Data, _ avatarURL: String) {
		RSImage.image(with: imageData) { (image) in
			MainActor.assumeIsolated {
				if let image {
					self.handleImageDidBecomeAvailable(avatarURL, image)
				}
			}
		}
	}

	func handleImageDidBecomeAvailable(_ avatarURL: String, _ image: RSImage) {
		if cache[avatarURL] == nil {
			cache[avatarURL] = IconImage(image)
		}
		if waitingForAvatarURLs.contains(avatarURL) {
			waitingForAvatarURLs.remove(avatarURL)
			postAvatarDidBecomeAvailableNotification(avatarURL)
		}
	}

	func postAvatarDidBecomeAvailableNotification(_ avatarURL: String) {
		DispatchQueue.main.async {
 			NotificationCenter.default.post(name: .AvatarDidBecomeAvailable, object: self, userInfo: ["url": avatarURL])
		}
	}
}
