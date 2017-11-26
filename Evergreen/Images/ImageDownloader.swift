//
//  ImageDownloader.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/25/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore
import RSWeb

extension Notification.Name {

	static let ImageDidBecomeAvailable = Notification.Name("ImageDidBecomeAvailableNotification") // ImageDownloader.UserInfoKey.imageURL
}

final class ImageDownloader {

	private let folder: String
	private var diskCache: BinaryDiskCache
	private let queue: DispatchQueue
	private var imageCache = [String: NSImage]() // url: image
	
	struct UserInfoKey {
		static let imageURL = "imageURL"
	}

	init(folder: String) {

		self.folder = folder
		self.diskCache = BinaryDiskCache(folder: folder)
		self.queue = DispatchQueue(label: "ImageDownloader serial queue - \(folder)")
	}

	func image(for url: String) -> NSImage? {

		if let image = imageCache[url] {
			return image
		}

		findImage(url)
		return nil
	}
}

private extension ImageDownloader {

	func cacheImage(_ url: String, _ image: NSImage) {

		imageCache[url] = image
		postImageDidBecomeAvailableNotification(url)
	}

	func findImage(_ url: String) {

		readFromDisk(url) { (image) in

			if let image = image {
				self.cacheImage(url, image)
				return
			}

			self.downloadImage(url) { (image) in

				if let image = image {
					self.cacheImage(url, image)
				}
			}
		}
	}

	func readFromDisk(_ url: String, _ callback: @escaping (NSImage?) -> Void) {

		queue.async {

			if let data = self.diskCache[self.diskKey(url)], !data.isEmpty {
				NSImage.rs_image(with: data, imageResultBlock: callback)
				return
			}

			DispatchQueue.main.async {
				callback(nil)
			}
		}
	}

	func downloadImage(_ url: String, _ callback: @escaping (NSImage?) -> Void) {

		guard let url = URL(string: url) else {
			callback(nil)
			return
		}

		downloadUsingCache(url) { (data, response, error) in

			if let data = data, !data.isEmpty, let response = response, response.statusIsOK, error == nil {
				self.saveToDisk(url.absoluteString, data)
				NSImage.rs_image(with: data, imageResultBlock: callback)
				return
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

		NotificationCenter.default.post(name: .ImageDidBecomeAvailable, object: self, userInfo: [UserInfoKey.imageURL: url])
	}
}
