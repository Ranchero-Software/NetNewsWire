//
//  ImageDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/25/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import RSWeb

extension Notification.Name {

	static let ImageDidBecomeAvailable = Notification.Name("ImageDidBecomeAvailableNotification") // UserInfoKey.url
}

final class ImageDownloader {

	private let folder: String
	private var diskCache: BinaryDiskCache
	private let queue: DispatchQueue
	private var imageCache = [String: Data]() // url: image
	private var urlsInProgress = Set<String>()
	private var badURLs = Set<String>() // That return a 404 or whatever. Just skip them in the future.

	init(folder: String) {

		self.folder = folder
		self.diskCache = BinaryDiskCache(folder: folder)
		self.queue = DispatchQueue(label: "ImageDownloader serial queue - \(folder)")
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

	func readFromDisk(_ url: String, _ callback: @escaping (Data?) -> Void) {

		queue.async {

			if let data = self.diskCache[self.diskKey(url)], !data.isEmpty {
				DispatchQueue.main.async {
					callback(data)
				}
				return
			}

			DispatchQueue.main.async {
				callback(nil)
			}
		}
	}

	func downloadImage(_ url: String, _ callback: @escaping (Data?) -> Void) {

		guard let imageURL = URL(string: url) else {
			callback(nil)
			return
		}

		downloadUsingCache(imageURL) { (data, response, error) in

			if let data = data, !data.isEmpty, let response = response, response.statusIsOK, error == nil {
				self.saveToDisk(url, data)
				callback(data)
				return
			}

			if let response = response as? HTTPURLResponse, response.statusCode >= HTTPResponseCode.badRequest && response.statusCode <= HTTPResponseCode.notAcceptable {
				self.badURLs.insert(url)
			}
			if let error = error {
				appDelegate.logMessage("Error downloading image at \(url): \(error)", type: .warning)
			}

			callback(nil)
		}
	}

	func saveToDisk(_ url: String, _ data: Data) {

		queue.async {
			self.diskCache[self.diskKey(url)] = data
		}
	}

	func diskKey(_ url: String) -> String {

		return (url as NSString).rs_md5Hash()
	}

	func postImageDidBecomeAvailableNotification(_ url: String) {

		DispatchQueue.main.async {
			NotificationCenter.default.post(name: .ImageDidBecomeAvailable, object: self, userInfo: [UserInfoKey.url: url])
		}
	}
}
