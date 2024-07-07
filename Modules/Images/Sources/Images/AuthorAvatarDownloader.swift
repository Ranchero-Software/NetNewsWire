//
//  AuthorAvatarDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import Core

public extension Notification.Name {

	static let AvatarDidBecomeAvailable = Notification.Name("AvatarDidBecomeAvailableNotification") // UserInfoKey.imageURL (which is an avatarURL)
}

@MainActor public final class AuthorAvatarDownloader {

	public static let shared = AuthorAvatarDownloader()
	private let imageDownloader = ImageDownloader.shared
	private var cache = [String: IconImage]() // avatarURL: RSImage
	private var waitingForAvatarURLs = Set<String>()

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .ImageDidBecomeAvailable, object: imageDownloader)
	}

	public func resetCache() {
		cache = [String: IconImage]()
	}
	
	public func image(for author: Author) -> IconImage? {

		guard let avatarURL = author.avatarURL else {
			return nil
		}
		
		if let cachedImage = cache[avatarURL] {
			return cachedImage
		}
		
		if let imageData = imageDownloader.image(for: avatarURL) {
			scaleAndCacheImageData(imageData, avatarURL)
		}
		else {
			waitingForAvatarURLs.insert(avatarURL)
		}

		return nil
	}

	@objc func imageDidBecomeAvailable(_ note: Notification) {

		assert(Thread.isMainThread)
		
		guard let avatarURL = note.userInfo?[ImageDownloader.imageURLKey] as? String else {
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

private extension AuthorAvatarDownloader {

	func scaleAndCacheImageData(_ imageData: Data, _ avatarURL: String) {

		Task { @MainActor in
			if let image = await RSImage.scaledForIcon(imageData) {
				self.handleImageDidBecomeAvailable(avatarURL, image)
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
			NotificationCenter.default.post(name: .AvatarDidBecomeAvailable, object: self, userInfo: [ImageDownloader.imageURLKey: avatarURL])
		}
	}
}
