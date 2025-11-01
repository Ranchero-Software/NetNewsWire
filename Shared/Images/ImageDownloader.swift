//
//  ImageDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/25/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import os.log
import RSCore
import RSWeb
import RSCore

extension Notification.Name {

	static let ImageDidBecomeAvailable = Notification.Name("ImageDidBecomeAvailableNotification") // UserInfoKey.url
}

final class ImageDownloader {

	public static let shared = ImageDownloader()

	static private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ImageDownloader")

	private var diskCache: BinaryDiskCache
	private let queue: DispatchQueue
	private var imageCache = [String: Data]() // url: image
	private var urlsInProgress = Set<String>()
	private var badURLs = Set<String>() // That return a 404 or whatever. Just skip them in the future.

	init() {

		let folder = AppConfig.cacheSubfolder(named: "Images")
		self.diskCache = BinaryDiskCache(folder: folder.path)
		self.queue = DispatchQueue(label: "ImageDownloader serial queue - \(folder.path)")
	}

	@discardableResult
	func image(for url: String) -> Data? {

		if let data = imageCache[url] {
			return data
		}

		findImage(url)
		return nil
	}
}

private extension ImageDownloader {

	func cacheImage(_ url: String, _ image: Data) {

		imageCache[url] = image
		postImageDidBecomeAvailableNotification(url)
	}

	func findImage(_ url: String) {

		guard !urlsInProgress.contains(url) && !badURLs.contains(url) else {
			return
		}
		urlsInProgress.insert(url)

		readFromDisk(url) { (image) in

			if let image = image {
				self.cacheImage(url, image)
				self.urlsInProgress.remove(url)
				return
			}

			self.downloadImage(url) { (image) in

				if let image = image {
					self.cacheImage(url, image)
				}
				self.urlsInProgress.remove(url)
			}
		}
	}

	func readFromDisk(_ url: String, _ completion: @escaping (Data?) -> Void) {

		queue.async {

			if let data = self.diskCache[self.diskKey(url)], !data.isEmpty {
				DispatchQueue.main.async {
					completion(data)
				}
				return
			}

			DispatchQueue.main.async {
				completion(nil)
			}
		}
	}

	func downloadImage(_ url: String, _ completion: @escaping (Data?) -> Void) {

		guard let imageURL = URL(string: url) else {
			completion(nil)
			return
		}

		Task { @MainActor in
			Downloader.shared.download(imageURL) { (data, response, error) in

				if let data = data, !data.isEmpty, let response = response, response.statusIsOK, error == nil {
					self.saveToDisk(url, data)
					completion(data)
					return
				}

				if let response = response as? HTTPURLResponse, response.statusCode >= HTTPResponseCode.badRequest && response.statusCode <= HTTPResponseCode.notAcceptable {
					self.badURLs.insert(url)
				}
				if let error = error {
					Self.logger.error("Error downloading image at \(url) \(error.localizedDescription)")
				}

				completion(nil)
			}
		}
	}

	func saveToDisk(_ url: String, _ data: Data) {

		queue.async {
			self.diskCache[self.diskKey(url)] = data
		}
	}

	func diskKey(_ url: String) -> String {

		return url.md5String
	}

	func postImageDidBecomeAvailableNotification(_ url: String) {

		DispatchQueue.main.async {
			NotificationCenter.default.post(name: .ImageDidBecomeAvailable, object: self, userInfo: [UserInfoKey.url: url])
		}
	}
}
