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

	/// The persistent failure, if any. Nil after success or for transient failures.
	public private(set) var error: ImageDownloadError?

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
		do throws(ImageDownloadError) {
			let kind = ActivityKind.downloadFavicon(faviconURL: faviconURL)
			let storedData = try await DownloadedImageCache.shared.imageData(for: faviconURL, usesDownloadLimiter: false, checksForUpdates: true, activityOwner: .faviconDownloader, activityKind: kind, activityDetail: homePageURL)
			guard let image = await Self.iconImage(storedData, maxPixelSize: RSImage.maxIconPixelSize) else {
				throw ImageDownloadError(statusCode: nil, decodingFailed: true, isTransient: false)
			}
			iconImage = IconImage(image)
			error = nil
		} catch {
			self.error = error.isTransient ? nil : error
		}
		postDidLoadFaviconNotification()
	}

	@concurrent static func iconImage(_ data: Data, maxPixelSize: Int) async -> RSImage? {
		let scaledData = RSImage.scaledImageData(data, maxPixelSize: maxPixelSize) ?? data
		return RSImage(data: scaledData)
	}

	func postDidLoadFaviconNotification() {
		assert(Thread.isMainThread)
		NotificationCenter.default.post(name: .DidLoadFavicon, object: self)
	}
}
