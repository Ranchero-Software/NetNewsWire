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
	private(set) var lastFailureWasNotAnImage = false
	/// True until `.DidLoadFavicon` is posted for the current attempt.
	private(set) var isFinding = true

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

	/// Tries again when there’s no image and the last attempt was a while ago.
	public func downloadFaviconIfNeeded() {
		guard iconImage == nil, !isFinding else {
			return
		}
		if Date().timeIntervalSince(lastDownloadAttemptDate) < Self.retryInterval {
			return
		}
		lastDownloadAttemptDate = Date()
		isFinding = true

		Task { @MainActor in
			await findFavicon()
		}
	}
}

private extension SingleFaviconDownloader {

	func findFavicon() async {
		let kind = ActivityKind.downloadFavicon(faviconURL: faviconURL)
		lastFailureWasTransient = false
		lastFailureWasNotAnImage = false
		if let scaledData = await DownloadedImageCache.shared.derivedImageData(for: faviconURL, suffix: DownloadedImageCache.scaledIconSuffix), let iconImage = await IconImage.decodedIconImage(scaledData) {
			DownloadedImageCache.shared.imageWasUsed(faviconURL, checksForUpdates: true)
			self.iconImage = iconImage
			ImageDatabase.shared.clearFailure(url: faviconURL)
			postDidLoadFaviconNotification()
			return
		}
		do throws(ImageDownloadError) {
			let storedData = try await DownloadedImageCache.shared.imageData(for: faviconURL, usesDownloadQueue: false, checksForUpdates: true, activityOwner: .faviconDownloader, activityKind: kind, activityDetail: homePageURL)
			let scaledData = await Self.scaledImageData(storedData, maxPixelSize: RSImage.maxIconPixelSize)
			// DownloadedImageCache records download failures, but can’t know whether the data decodes as an icon.
			if let iconImage = await IconImage.decodedIconImage(scaledData) {
				// An image that’s already small enough needs no second file.
				if scaledData != storedData {
					await DownloadedImageCache.shared.saveDerivedImageData(scaledData, for: faviconURL, suffix: DownloadedImageCache.scaledIconSuffix)
				}
				self.iconImage = iconImage
				ImageDatabase.shared.clearFailure(url: faviconURL)
			} else {
				ImageDatabase.shared.recordFailure(url: faviconURL)
			}
		} catch {
			// A non-image response is transient, so a captive portal’s login page can’t lead to “no favicon”.
			lastFailureWasTransient = error.isTransient
			lastFailureWasNotAnImage = error.decodingFailed
		}
		postDidLoadFaviconNotification()
	}

	@concurrent static func scaledImageData(_ data: Data, maxPixelSize: Int) async -> Data {
		RSImage.scaledImageData(data, maxPixelSize: maxPixelSize) ?? data
	}

	func postDidLoadFaviconNotification() {
		assert(Thread.isMainThread)
		isFinding = false
		NotificationCenter.default.post(name: .DidLoadFavicon, object: self)
	}
}
