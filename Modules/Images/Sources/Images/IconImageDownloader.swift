//
//  IconImageDownloader.swift
//  Images
//
//  Created by Brent Simmons on 11/25/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import os
import RSCore
import RSWeb
import ActivityLog

extension Notification.Name {
	/// userInfo key: `IconImageDownloader.urlKey`.
	public static let iconImageDidBecomeAvailable = Notification.Name("IconImageDidBecomeAvailable")
	/// userInfo keys: `IconImageDownloader.urlKey` and `IconImageDownloader.errorKey` (`ImageDownloadError`).
	public static let iconImageDownloadDidFail = Notification.Name("IconImageDownloadDidFail")
}

/// What one icon source has: an icon, an icon still loading, or none.
public enum IconLookup {
	case found(IconImage)
	/// The next source isn’t tried yet.
	case loading
	/// The next source is tried.
	case unavailable

	public var iconImage: IconImage? {
		if case .found(let iconImage) = self {
			return iconImage
		}
		return nil
	}
}

/// Makes feed icons, favicons, and avatars from `DownloadedImageCache`’s copy, and caches them in memory by URL.
/// Callers that share an icon URL share one load and one bitmap.
@MainActor public final class IconImageDownloader {

	public static let shared = IconImageDownloader()
	public static let urlKey = "url"
	public static let errorKey = "error"

	nonisolated static private let logger = Logger(subsystem: Logger.nnwSubsystem, category: "IconImageDownloader")

	private let iconImageCache = NSCache<NSString, IconImage>() // url: icon image
	private var urlsInProgress = Set<String>()
	private var requestsToRetry = [String: Request]() // url: request that failed transiently

	private init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleDownloadedImageDidChange(_:)), name: .downloadedImageDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleNetworkStatusDidChange(_:)), name: .networkStatusDidChange, object: nil)
	}

	/// Starts loading when the icon isn’t in memory. Posts `.iconImageDidBecomeAvailable` or `.iconImageDownloadDidFail` when done.
	/// Unavailable when the URL isn’t http(s), recently failed, or is waiting to retry after a transient failure.
	/// Activity log fires only when the request reaches the network.
	public func iconImage(for url: String, activityOwner: ActivityOwner, activityKind: ActivityKind, activityDetail: String?) -> IconLookup {
		guard url.hasPrefix("http://") || url.hasPrefix("https://") else {
			Self.logger.debug("Skipping non-http(s) URL: \(url)")
			return .unavailable
		}
		if let iconImage = iconImageCache.object(forKey: url as NSString) {
			DownloadedImageCache.shared.imageWasUsed(url, checksForUpdates: true)
			return .found(iconImage)
		}
		if urlsInProgress.contains(url) {
			return .loading
		}
		if ImageDatabase.shared.recentlyFailed(url: url) {
			return .unavailable
		}
		let request = Request(url: url, activityOwner: activityOwner, activityKind: activityKind, activityDetail: activityDetail)
		if DownloadedImageCache.shared.isWaitingToRetry(url) {
			requestsToRetry[url] = request
			return .unavailable
		}

		findIconImage(request)
		return .loading
	}

	// MARK: - Notifications

	@objc func handleAppDidGoToBackground(_ notification: Notification) {
		iconImageCache.removeAllObjects()
	}

	@objc func handleLowMemory(_ notification: Notification) {
		iconImageCache.removeAllObjects()
	}

	/// Made again even when not in memory, since icons made from the old copy may be cached elsewhere.
	/// The old icon stays in memory until the new one replaces it.
	@objc func handleDownloadedImageDidChange(_ notification: Notification) {
		guard let url = notification.userInfo?[DownloadedImageCache.urlKey] as? String else {
			return
		}
		findIconImage(Request(url: url, activityOwner: nil, activityKind: nil, activityDetail: nil))
	}

	/// Waits for transient failures may have just ended, so those icons are requested again.
	/// Runs after `DownloadedImageCache` ends those waits, which it does on this notification too.
	@objc func handleNetworkStatusDidChange(_ notification: Notification) {
		guard NetworkMonitor.shared.isConnected else {
			return
		}
		Task { @MainActor in
			for request in requestsToRetry.values where !DownloadedImageCache.shared.isWaitingToRetry(request.url) {
				findIconImage(request)
			}
		}
	}
}

private extension IconImageDownloader {

	struct Request {
		let url: String
		let activityOwner: ActivityOwner?
		let activityKind: ActivityKind?
		let activityDetail: String?
	}

	func findIconImage(_ request: Request) {
		let url = request.url
		guard !urlsInProgress.contains(url) else {
			return
		}
		urlsInProgress.insert(url)
		requestsToRetry[url] = nil

		Task { @MainActor in
			defer {
				urlsInProgress.remove(url)
			}
			if let iconImage = await iconImageFromScaledCopy(url) {
				cacheIconImage(iconImage, url: url)
				return
			}

			do throws(ImageDownloadError) {
				let storedData = try await DownloadedImageCache.shared.imageData(for: url, usesDownloadQueue: false, checksForUpdates: true, activityOwner: request.activityOwner, activityKind: request.activityKind, activityDetail: request.activityDetail)
				let scaledData = await DownloadedImageCache.scaledIcon(from: storedData)
				// DownloadedImageCache records download failures, but can’t know whether the data decodes as an icon.
				guard let iconImage = await IconImage.decodedIconImage(scaledData) else {
					ImageDatabase.shared.recordFailure(url: url)
					postIconImageDownloadDidFail(url, error: ImageDownloadError(statusCode: nil, decodingFailed: true, isTransient: false))
					return
				}
				// An image that’s already small enough needs no second file.
				if scaledData != storedData {
					await DownloadedImageCache.shared.saveScaledIconData(scaledData, for: url)
				}
				cacheIconImage(iconImage, url: url)
			} catch {
				if error.isTransient {
					requestsToRetry[url] = request
				}
				postIconImageDownloadDidFail(url, error: error)
			}
		}
	}

	func iconImageFromScaledCopy(_ url: String) async -> IconImage? {
		guard let scaledData = await DownloadedImageCache.shared.scaledIconData(for: url), let iconImage = await IconImage.decodedIconImage(scaledData) else {
			return nil
		}
		DownloadedImageCache.shared.imageWasUsed(url, checksForUpdates: true)
		return iconImage
	}

	func cacheIconImage(_ iconImage: IconImage, url: String) {
		iconImageCache.setObject(iconImage, forKey: url as NSString)
		NotificationCenter.default.post(name: .iconImageDidBecomeAvailable, object: self, userInfo: [Self.urlKey: url])
	}

	func postIconImageDownloadDidFail(_ url: String, error: ImageDownloadError) {
		NotificationCenter.default.post(name: .iconImageDownloadDidFail, object: self, userInfo: [Self.urlKey: url, Self.errorKey: error])
	}
}
