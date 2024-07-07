//
//  ImageDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/25/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import os.log
import Web
import FoundationExtras
import Core

public extension Notification.Name {

	static let ImageDidBecomeAvailable = Notification.Name("ImageDidBecomeAvailableNotification") // UserInfoKey.url
}

@MainActor public final class ImageDownloader {

	public static let shared = ImageDownloader()

	public static let imageURLKey = "url"

	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "ImageDownloader")

	private let diskCache: BinaryDiskCache
	private var imageCache = [String: Data]() // url: image
	private var urlsInProgress = Set<String>()
	private var badURLs = Set<String>() // That return a 404 or whatever. Just skip them in the future.

	init() {
		let folder = AppConfig.cacheSubfolder(named: "Images")
		self.diskCache = BinaryDiskCache(folder: folder.path)
	}

	@discardableResult
	public func image(for url: String) -> Data? {

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

		Task { @MainActor in

			guard !urlsInProgress.contains(url) && !badURLs.contains(url) else {
				return
			}

			urlsInProgress.insert(url)

			if let imageData = await readFromDisk(url) {
				cacheImage(url, imageData)
			} else if let imageData = await downloadImage(url) {
				cacheImage(url, imageData)
			}

			urlsInProgress.remove(url)
		}
	}

	func readFromDisk(_ url: String) async -> Data? {

		guard let data = await self.diskCache[Self.diskKey(url)], !data.isEmpty else {
			return nil
		}

		return data
	}

	func downloadImage(_ url: String) async -> Data? {

		guard let imageURL = URL(string: url) else {
			return nil
		}

		do {
			let downloadData = try await DownloadWithCacheManager.shared.download(imageURL)

			if let data = downloadData.data, !data.isEmpty, let response = downloadData.response, response.statusIsOK {
				try await saveToDisk(url, data)
				return data
			}

			if let response = downloadData.response as? HTTPURLResponse, response.statusCode >= HTTPResponseCode.badRequest && response.statusCode <= HTTPResponseCode.notAcceptable {
				badURLs.insert(url)
			}

		} catch {
			os_log(.info, log: self.log, "Error downloading image at %@: %@.", url, error.localizedDescription)
		}

		return nil
	}

	func saveToDisk(_ url: String, _ data: Data) async throws {

		let key = Self.diskKey(url)
		try await diskCache.setData(data, forKey: key)
	}

	static func diskKey(_ url: String) -> String {

		url.md5String
	}

	func postImageDidBecomeAvailableNotification(_ url: String) {

		NotificationCenter.default.post(name: .ImageDidBecomeAvailable, object: self, userInfo: [Self.imageURLKey: url])
	}
}
