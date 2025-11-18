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

extension Notification.Name {
	static let imageDidBecomeAvailable = Notification.Name("ImageDidBecomeAvailableNotification") // UserInfoKey.url
}

@MainActor final class ImageDownloader {
	public static let shared = ImageDownloader()

	nonisolated static private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ImageDownloader")

	nonisolated private let diskCache: BinaryDiskCache
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
		assert(Thread.isMainThread)
		if let data = imageCache[url] {
			return data
		}

		Task { @MainActor in
			await findImage(url)
		}

		return nil
	}
}

private extension ImageDownloader {

	func cacheImage(_ url: String, _ image: Data) {
		assert(Thread.isMainThread)
		imageCache[url] = image
		postImageDidBecomeAvailableNotification(url)
	}

	func findImage(_ url: String) async {
		guard !urlsInProgress.contains(url) && !badURLs.contains(url) else {
			return
		}
		urlsInProgress.insert(url)

		if let image = await readFromDisk(url: url) {
			cacheImage(url, image)
			urlsInProgress.remove(url)
			return
		}

		if let image = await downloadImage(url) {
			cacheImage(url, image)
			urlsInProgress.remove(url)
		}
	}

	func readFromDisk(url: String) async -> Data? {
		await withCheckedContinuation { continuation in
			readFromDisk(url) { data in
				continuation.resume(returning: data)
			}
		}
	}

	func readFromDisk(_ url: String, _ completion: @escaping @MainActor (Data?) -> Void) {
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

	func downloadImage(_ url: String) async -> Data? {
		guard let imageURL = URL(string: url) else {
			return nil
		}

		do {
			let (data, response) = try await Downloader.shared.download(imageURL)

			if let data, !data.isEmpty, let response, response.statusIsOK {
				saveToDisk(url, data)
				return data
			}

			if let response = response as? HTTPURLResponse, response.statusCode >= HTTPResponseCode.badRequest && response.statusCode <= HTTPResponseCode.notAcceptable {
				badURLs.insert(url)
			}

			return nil
		} catch {
			Self.logger.error("Error downloading image at \(url) \(error.localizedDescription)")
			return nil
		}
	}

	func saveToDisk(_ url: String, _ data: Data) {
		queue.async {
			self.diskCache[self.diskKey(url)] = data
		}
	}

	nonisolated func diskKey(_ url: String) -> String {
		url.md5String
	}

	func postImageDidBecomeAvailableNotification(_ url: String) {
		assert(Thread.isMainThread)
		NotificationCenter.default.post(name: .imageDidBecomeAvailable, object: self, userInfo: [UserInfoKey.url: url])
	}
}
