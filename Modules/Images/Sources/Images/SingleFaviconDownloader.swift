//
//  SingleFaviconDownloader.swift
//  Images
//
//  Created by Brent Simmons on 11/23/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import ActivityLog
import RSCore

extension Notification.Name {
	public static let DidLoadFavicon = Notification.Name("DidLoadFaviconNotification")
}

/// Gets the favicon from `DownloadedImageCache`. Posts `.DidLoadFavicon` on both
/// success and persistent failure.
@MainActor public final class SingleFaviconDownloader {

	public let faviconURL: String
	public let homePageURL: String?

	public var iconImage: IconImage?
	private(set) var lastFailureWasTransient = false

	private static let retryInterval: TimeInterval = 30 * 60 // 30 minutes

	private var lastDownloadAttemptDate: Date

	public init(faviconURL: String, homePageURL: String?) {
		self.faviconURL = faviconURL
		self.homePageURL = homePageURL
		self.lastDownloadAttemptDate = Date()

		Task { @MainActor in
			await findFavicon()
		}
	}

	public func downloadFaviconIfNeeded() -> Bool {
		// If we don’t have an image, and lastDownloadAttemptDate is a while ago, try again.
		guard iconImage == nil else {
			return false
		}

		if Date().timeIntervalSince(lastDownloadAttemptDate) < Self.retryInterval {
			return false
		}
		lastDownloadAttemptDate = Date()

		Task { @MainActor in
			await findFavicon()
		}

		return true
	}
}

private extension SingleFaviconDownloader {

	func findFavicon() async {
		let kind = ActivityKind.downloadFavicon(faviconURL: faviconURL)
		lastFailureWasTransient = false
		if let scaledData = await DownloadedImageCache.shared.derivedImageData(for: faviconURL, suffix: DownloadedImageCache.scaledIconSuffix), let image = await Self.image(scaledData) {
			DownloadedImageCache.shared.imageWasUsed(faviconURL, checksForUpdates: true)
			iconImage = IconImage(image)
			ImageDatabase.shared.clearFailure(url: faviconURL)
			postDidLoadFaviconNotification()
			return
		}
		do throws(ImageDownloadError) {
			let storedData = try await DownloadedImageCache.shared.imageData(for: faviconURL, usesDownloadQueue: false, checksForUpdates: true, activityOwner: .faviconDownloader, activityKind: kind, activityDetail: homePageURL)
			let scaledData = await Self.scaledImageData(storedData, maxPixelSize: RSImage.maxIconPixelSize)
			// DownloadedImageCache records download failures, but can’t know whether the data decodes as an icon.
			if let image = await Self.image(scaledData) {
				// An image that’s already small enough needs no second file.
				if scaledData != storedData {
					await DownloadedImageCache.shared.saveDerivedImageData(scaledData, for: faviconURL, suffix: DownloadedImageCache.scaledIconSuffix)
				}
				iconImage = IconImage(image)
				ImageDatabase.shared.clearFailure(url: faviconURL)
			} else {
				ImageDatabase.shared.recordFailure(url: faviconURL, statusCode: nil)
			}
		} catch {
			// A non-image response usually means the site has no favicon at this URL.
			lastFailureWasTransient = error.isTransient && !error.decodingFailed
		}
		postDidLoadFaviconNotification()
	}

	@concurrent static func scaledImageData(_ data: Data, maxPixelSize: Int) async -> Data {
		RSImage.scaledImageData(data, maxPixelSize: maxPixelSize) ?? data
	}

	@concurrent static func image(_ data: Data) async -> RSImage? {
		RSImage(data: data)
	}

	func postDidLoadFaviconNotification() {
		assert(Thread.isMainThread)
		NotificationCenter.default.post(name: .DidLoadFavicon, object: self)
	}
}
